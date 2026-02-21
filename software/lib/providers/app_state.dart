import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
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
  Timer? _scheduleTimer;

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

    // Start periodic schedule check
    _scheduleTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkSchedule();
    });
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    super.dispose();
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
      print('Error during manual sync: $e');
    }
  }

  Future<void> _checkSchedule() async {
    bool hasChanges = false;
    DateTime now = DateTime.now();
    List<String> days = ['Monday', 'Tuesday', 'Wednesday'];

    // 1. Auto-reset at midnight (handled via persistent date check in SharedPreferences)
    String todayString = "${now.year}-${now.month}-${now.day}";
    final prefs = await SharedPreferences.getInstance();
    String? lastReset = prefs.getString('last_reset_date');

    if (lastReset != todayString) {
      await prefs.setString('last_reset_date', todayString);
      for (String d in days) {
        final compartments = storageService.getCompartmentsForDay(d);
        for (var comp in compartments) {
          if (comp.status != 'Empty' && comp.status != 'Upcoming') {
            comp.status = 'Upcoming';
            comp.save();
            hasChanges = true;
          }
        }
      }
    }

    String currentDayStr = '';
    if (now.weekday == DateTime.monday)
      currentDayStr = 'Monday';
    else if (now.weekday == DateTime.tuesday)
      currentDayStr = 'Tuesday';
    else if (now.weekday == DateTime.wednesday)
      currentDayStr = 'Wednesday';

    for (String day in days) {
      final compartments = storageService.getCompartmentsForDay(day);
      for (var comp in compartments) {
        // Skip Empty and Done. Once Done, it stays Done for the remainder of the day.
        if (comp.status == 'Empty' || comp.status == 'Done') continue;

        if (comp.time.isNotEmpty && comp.time.contains(':')) {
          List<String> parts = comp.time.split(':');
          int hour = int.tryParse(parts[0]) ?? 0;
          int minute = int.tryParse(parts[1]) ?? 0;

          if (day == currentDayStr) {
            DateTime slotTime = DateTime(
              now.year,
              now.month,
              now.day,
              hour,
              minute,
            );

            // Strict time comparison:
            if (now.isAfter(slotTime)) {
              // Time has passed and user hasn't confirmed (status is not Done) -> Missed
              if (comp.status != 'Missed') {
                comp.status = 'Missed';
                comp.save();
                hasChanges = true;

                // Optional: trigger ESP if you want the alarm exactly when it becomes missed
                int r = days.indexOf(day);
                int c = comp.slotIndex - 1;
                bleService.sendCommand({'cmd': 'TRIGGER', 'r': r, 'c': c});
              }
            } else {
              // Current time is before the scheduled time -> Upcoming
              if (comp.status != 'Upcoming') {
                comp.status = 'Upcoming';
                comp.save();
                hasChanges = true;
              }
            }
          } else {
            int currentDayIndex = now.weekday; // 1 to 7
            int slotDayIndex = days.indexOf(day) + 1; // 1 to 3

            if (currentDayIndex < slotDayIndex) {
              if (comp.status != 'Upcoming') {
                comp.status = 'Upcoming';
                comp.save();
                hasChanges = true;
              }
            } else if (currentDayIndex > slotDayIndex &&
                currentDayStr.isNotEmpty) {
              if (comp.status != 'Missed') {
                comp.status = 'Missed';
                comp.save();
                hasChanges = true;
              }
            }
          }
        }
      }
    }
    if (hasChanges) notifyListeners();
  }

  Future<void> markAsTaken(Compartment compartment) async {
    compartment.status = 'Done';
    await compartment.save();
    notifyListeners();

    // Send Stop command to BLE
    if (isConnected) {
      await bleService.sendCommand({'cmd': 'STOP'});
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
