import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../models/reminder.dart';
import '../main.dart';
import 'dart:convert';

enum BleStatus { disconnected, scanning, connecting, connected }

class BleProvider with ChangeNotifier, WidgetsBindingObserver {
  final BleService _bleService = BleService();

  BleStatus _status = BleStatus.disconnected;
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _connectionSubscription;

  BleStatus get status => _status;
  bool get isConnected => _status == BleStatus.connected;
  BluetoothDevice? get connectedDevice => _connectedDevice;

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
        _status == BleStatus.disconnected) {
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
        _status == BleStatus.connected)
      return;

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
      _showSnackBar("MedAlert device not found", Colors.red);
    }
  }

  void _listenToConnectionState() {
    _connectionSubscription?.cancel();
    if (_connectedDevice == null) return;

    _connectionSubscription = _connectedDevice!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        _setStatus(BleStatus.connected);
        _showSnackBar("Connected to MedAlert Box", Colors.green);
      } else if (state == BluetoothConnectionState.disconnected) {
        if (_status == BleStatus.connected) {
          _setStatus(BleStatus.disconnected);
          _showSnackBar("Device disconnected", Colors.red);
        } else {
          _setStatus(BleStatus.disconnected);
        }
        _connectedDevice = null;
        _connectionSubscription?.cancel();
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
    // If previously connected device exists in FlutterBluePlus system
    List<BluetoothDevice> systemDevices = await FlutterBluePlus.systemDevices(
      [],
    );
    for (var d in systemDevices) {
      if (d.platformName.contains("MedAlert") ||
          d.advName.contains("MedAlert")) {
        _connectedDevice = d;
        _setStatus(BleStatus.connecting);
        try {
          await d.connect(
            timeout: const Duration(seconds: 10),
            license: License.free,
          );
          _listenToConnectionState();
          return;
        } catch (e) {
          _setStatus(BleStatus.disconnected);
          _connectedDevice = null;
        }
      }
    }
  }

  // IoT Ready: structure method and placeholder call
  Future<void> sendRemindersToDevice(List<Reminder> reminders) async {
    if (!isConnected || _connectedDevice == null) {
      print("Cannot send reminders: Device not connected.");
      return;
    }

    try {
      final String jsonPayload = jsonEncode(
        reminders.map((r) => r.toJson()).toList(),
      );
      // ignore: unused_local_variable
      print("Sending reminders payload: \$jsonPayload");
      // Placeholder: actual characteristic write would go here
    } catch (e) {
      print("Error packaging reminders: \$e");
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    // ScaffoldMessenger relies on global context or a specific key.
    // For simplicity, we use the root messenger if accessible, or we leave logic to UI.
    // Since we need to show snackbars natively from Provider, using scaffold messenger global key is best.
    // Wait, let's use a simpler approach or rely on the UI to react.
    // However, the requested rule "If device not found: Show floating SnackBar"
    // I will use a minimal static dispatch.
    try {
      // Find navigator key or use builder context. In a standard setup, we can't easily show a snackbar from provider without context.
      // But we can define a global key. Since we don't have one set up yet, we will just print and let the user handle it or use a callback.
      // Actually, we can dispatch it utilizing the current context if we pass it, but we can't.
      // Let's implement a quick workaround or keep it simple.
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {}
  }
}
