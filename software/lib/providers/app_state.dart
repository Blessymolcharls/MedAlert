import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/compartment.dart';
import '../services/ble_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  final StorageService storageService;
  final BleService bleService;
  final NotificationService notificationService;

  bool isConnected = false;

  AppState({
    required this.storageService,
    required this.bleService,
    required this.notificationService,
  }) {
    init();
  }

  void init() async {
    notifyListeners();

    // Start BLE connection automatically or let user trigger it
    await _connectToDevice();
  }

  Future<void> _connectToDevice() async {
    await bleService.connectToDevice((data) {
      _handleBleNotification(data);
    });

    bleService.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        isConnected = true;
        // On connection, trigger a read sync
        syncDevice();
      } else {
        isConnected = false;
      }
      notifyListeners();
    });
  }

  Future<void> syncDevice() async {
    if (!isConnected) return;
    try {
      String? jsonStr = await bleService.readSchedule();
      if (jsonStr != null && jsonStr.isNotEmpty) {
        Map<String, dynamic> data = jsonDecode(jsonStr);
        _applyFullScheduleToHive(data);
      }
    } catch (e) {
      print('Error during manual sync: \$e');
    }
  }

  void _applyFullScheduleToHive(Map<String, dynamic> data) {
    List<String> days = ['Monday', 'Tuesday', 'Wednesday'];
    for (String day in days) {
      if (data.containsKey(day)) {
        List<dynamic> daySlots = data[day];
        for (var slotData in daySlots) {
          try {
            int slot = slotData['slot'];
            final targetId = '${day}_$slot';
            final existing = storageService.box.get(targetId);

            if (existing != null) {
              existing.medicineName = slotData['medicine'] ?? '';
              existing.dosage = slotData['dosage'] ?? '';
              existing.time = slotData['time'] ?? '';
              existing.slotName = slotData['slotName'] ?? '';
              // Assuming if it has medicine, it's Upcoming, else Empty unless taken
              if (existing.medicineName.isNotEmpty) {
                existing.status = 'Upcoming';
              } else {
                existing.status = 'Empty';
              }

              existing.save();
              notificationService.scheduleNotification(existing);
            }
          } catch (e) {
            print('Error parsing slot: \$e');
          }
        }
      }
    }
    notifyListeners();
  }

  void _handleBleNotification(Map<String, dynamic> data) {
    if (data.containsKey('status')) {
      if (data['status'] == 'schedule_updated') {
        print("Schedule updated internally on device.");
        // We could fetch the new schedule, but since the app probably triggered it, it's fine.
      } else if (data['status'] == 'reminder_triggered') {
        print("A reminder was triggered on the device.");
      }
    }
  }

  List<Compartment> getCompartmentsForDay(String day) {
    return storageService.getCompartmentsForDay(day);
  }

  Future<void> saveCompartment(Compartment compartment) async {
    await compartment.save(); // hive sync
    await notificationService.scheduleNotification(compartment);

    // Send to BLE as per JSON Spec
    await bleService.sendCommand({
      'day': compartment.day,
      'slot': compartment.slotIndex,
      'slotName': compartment.slotName,
      'medicine': compartment.medicineName,
      'dosage': compartment.dosage,
      'time': compartment.time,
    });

    notifyListeners();
  }
}
