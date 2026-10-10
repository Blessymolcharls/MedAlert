import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../models/reminder.dart';
import '../main.dart';

enum BleStatus { disconnected, scanning, connecting, connected }

class BleProvider with ChangeNotifier, WidgetsBindingObserver {
  final BleService _bleService = BleService();

  BleStatus _status = BleStatus.disconnected;
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _connectionSubscription;
  DateTime? _lastSyncTime;
  bool _isAutoReconnecting = false;

  BleStatus get status => _status;
  bool get isConnected => _status == BleStatus.connected;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  DateTime? get lastSyncTime => _lastSyncTime;
  BleService get bleService => _bleService;

  String? get deviceName {
    if (_connectedDevice == null) return null;
    return _connectedDevice!.platformName.isNotEmpty
        ? _connectedDevice!.platformName
        : (_connectedDevice!.advName.isNotEmpty
              ? _connectedDevice!.advName
              : "MedAlert_ESP32");
  }

  String? get deviceId => _connectedDevice?.remoteId.str;

  BleProvider() {
    WidgetsBinding.instance.addObserver(this);
    autoReconnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _status == BleStatus.disconnected &&
        !_isAutoReconnecting) {
      autoReconnect();
    }
  }

  void _setStatus(BleStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
    }
  }

  Future<void> connect() async {
    if (_status == BleStatus.scanning ||
        _status == BleStatus.connecting ||
        _status == BleStatus.connected) {
      return;
    }
    await startScan();
  }

  Future<void> startScan() async {
    _setStatus(BleStatus.scanning);

    try {
      final device = await _bleService.scanAndConnect();
      if (device != null) {
        _connectedDevice = device;
        _setStatus(BleStatus.connecting);
        _listenToConnectionState();
      } else {
        _setStatus(BleStatus.disconnected);
        _showSnackBar("MedAlert device not found", Colors.red);
      }
    } catch (e) {
      _setStatus(BleStatus.disconnected);
      _showSnackBar("Bluetooth error: $e", Colors.red);
    }
  }

  void _listenToConnectionState() {
    _connectionSubscription?.cancel();
    if (_connectedDevice == null) return;

    _connectionSubscription = _connectedDevice!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        _setStatus(BleStatus.connected);
        _lastSyncTime = DateTime.now();
        _showSnackBar("Connected to MedAlert Box", Colors.green);
      } else if (state == BluetoothConnectionState.disconnected) {
        final wasConnected = _status == BleStatus.connected;
        _setStatus(BleStatus.disconnected);
        _connectedDevice = null;
        _connectionSubscription?.cancel();
        if (wasConnected) {
          _showSnackBar("Device disconnected", Colors.red);
        }
      }
    });
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _bleService.disconnectDevice(_connectedDevice!);
    }
    _setStatus(BleStatus.disconnected);
  }

  Future<void> autoReconnect() async {
    if (_isAutoReconnecting || _status == BleStatus.connected) return;
    _isAutoReconnecting = true;

    try {
      final systemDevices = await FlutterBluePlus.systemDevices([]);
      for (var d in systemDevices) {
        if (d.platformName.contains("MedAlert") ||
            d.advName.contains("MedAlert")) {
          _connectedDevice = d;
          _setStatus(BleStatus.connecting);
          final success = await _bleService.connectToDeviceInstance(d);
          if (success) {
            _listenToConnectionState();
            _isAutoReconnecting = false;
            return;
          } else {
            _setStatus(BleStatus.disconnected);
            _connectedDevice = null;
          }
        }
      }
    } catch (_) {
      // Ignore background auto-reconnect scan errors
    } finally {
      _isAutoReconnecting = false;
    }
  }

  /// Syncs reminder schedules with the physical ESP32 pillbox.
  Future<bool> sendRemindersToDevice(List<Reminder> reminders) async {
    if (!isConnected || _connectedDevice == null) {
      return false;
    }

    try {
      int getRowForSection(String section) {
        final s = section.toLowerCase();
        if (s.contains("noon")) return 1;
        if (s.contains("night")) return 2;
        return 0; // Morning default
      }

      int colIndex = 0;
      for (var reminder in reminders) {
        final row = getRowForSection(reminder.section);
        final col = (colIndex % 6);
        final hStr = reminder.time.hour.toString().padLeft(2, '0');
        final mStr = reminder.time.minute.toString().padLeft(2, '0');
        final timeStr = "$hStr:$mStr";

        await _bleService.setSlot(row, col, timeStr);
        colIndex++;
      }

      _lastSyncTime = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("BLE: Error syncing reminders: $e");
      return false;
    }
  }

  /// Sends STOP command to turn off physical alert when medicine is taken.
  Future<void> stopAlert() async {
    if (isConnected) {
      await _bleService.stopAlert();
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    try {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {}
  }
}
