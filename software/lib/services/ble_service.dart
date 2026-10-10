import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String expectedDeviceName = "MedAlert_ESP32";

  // Exact matching UUIDs defined in hardware/MedAlert/MedAlert.ino
  static final Guid serviceUuid = Guid("7f6d0001-4b5c-4a7a-9c7e-9a2f3b6c1d10");
  static final Guid characteristicUuid = Guid(
    "7f6d0002-4b5c-4a7a-9c7e-9a2f3b6c1d10",
  );

  BluetoothDevice? _activeDevice;
  BluetoothCharacteristic? _activeCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  final StreamController<Map<String, dynamic>> _dataStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get incomingDataStream =>
      _dataStreamController.stream;

  BluetoothDevice? get activeDevice => _activeDevice;
  bool get hasActiveCharacteristic => _activeCharacteristic != null;

  /// Scans for the MedAlert ESP32 device and establishes a connection.
  Future<BluetoothDevice?> scanAndConnect() async {
    try {
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        debugPrint("BLE: Adapter is not on.");
        return null;
      }
    } catch (e) {
      debugPrint("BLE: Error checking adapter state: $e");
      return null;
    }

    // Stop existing scan if any
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}

    BluetoothDevice? targetDevice;
    final Completer<BluetoothDevice?> completer = Completer();

    final scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;

        final hasMatchingService = r.advertisementData.serviceUuids.contains(
          serviceUuid,
        );

        if (name.contains("MedAlert") || hasMatchingService) {
          debugPrint("BLE: Match found -> $name [${r.device.remoteId}]");
          FlutterBluePlus.stopScan();
          targetDevice = r.device;
          if (!completer.isCompleted) {
            completer.complete(targetDevice);
          }
          break;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint(
        "BLE: StartScan with service filter failed, fallback scan: $e",
      );
      try {
        await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      } catch (e2) {
        debugPrint("BLE: Scan failed: $e2");
        scanSub.cancel();
        return null;
      }
    }

    try {
      final device = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );
      scanSub.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      if (device != null) {
        await connectToDeviceInstance(device);
        return device;
      }
    } catch (e) {
      debugPrint("BLE: Scan/Connect error: $e");
      scanSub.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      return null;
    }

    return targetDevice;
  }

  /// Connects to a specific discovered BluetoothDevice, discovers service and characteristic.
  Future<bool> connectToDeviceInstance(BluetoothDevice device) async {
    try {
      _cleanupResources();
      _activeDevice = device;

      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
        license: License.free,
      );

      // Discover services & characteristics
      final services = await device.discoverServices();
      for (var s in services) {
        if (s.uuid == serviceUuid) {
          for (var c in s.characteristics) {
            if (c.uuid == characteristicUuid) {
              _activeCharacteristic = c;
              if (c.properties.notify) {
                await c.setNotifyValue(true);
                _notifySubscription = c.onValueReceived.listen((data) {
                  _handleIncomingBytes(data);
                });
              }
              debugPrint("BLE: Characteristic discovered and subscribed.");
              return true;
            }
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint("BLE: Connect to instance failed: $e");
      _cleanupResources();
      return false;
    }
  }

  void _handleIncomingBytes(List<int> bytes) {
    try {
      final str = utf8.decode(bytes);
      debugPrint("BLE Received: $str");
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) {
        _dataStreamController.add(decoded);
      }
    } catch (e) {
      debugPrint("BLE: Error decoding incoming payload: $e");
    }
  }

  /// Sends a raw JSON command payload to the ESP32.
  Future<bool> sendCommand(Map<String, dynamic> jsonCmd) async {
    if (_activeCharacteristic == null) {
      debugPrint("BLE: Cannot send command, characteristic not connected.");
      return false;
    }
    try {
      final jsonStr = jsonEncode(jsonCmd);
      debugPrint("BLE Sending: $jsonStr");
      await _activeCharacteristic!.write(utf8.encode(jsonStr));
      return true;
    } catch (e) {
      debugPrint("BLE: Send command error: $e");
      return false;
    }
  }

  /// Sets slot schedule: {"cmd":"SET","r":r,"c":c,"time":"HH:MM"}
  Future<bool> setSlot(int row, int col, String timeString) {
    return sendCommand({"cmd": "SET", "r": row, "c": col, "time": timeString});
  }

  /// Sends STOP command to turn off LED and Buzzer on ESP32
  Future<bool> stopAlert() {
    return sendCommand({"cmd": "STOP"});
  }

  /// Sends TRIGGER command to manually test a slot
  Future<bool> triggerSlot(int row, int col) {
    return sendCommand({"cmd": "TRIGGER", "r": row, "c": col});
  }

  /// Sends GET_ALL command to request full schedule dump
  Future<bool> requestAllSchedule() {
    return sendCommand({"cmd": "GET_ALL"});
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      debugPrint("BLE: Disconnect error: $e");
    } finally {
      _cleanupResources();
    }
  }

  void _cleanupResources() {
    _notifySubscription?.cancel();
    _notifySubscription = null;
    _activeCharacteristic = null;
    _activeDevice = null;
  }

  // --- Stubs for AppState compatibility ---
  Future<void> connectToDevice(Function(Map<String, dynamic>) onNotify) async {
    incomingDataStream.listen(onNotify);
  }

  Stream<BluetoothConnectionState> get connectionState =>
      _activeDevice?.connectionState ??
      Stream.value(BluetoothConnectionState.disconnected);

  Future<String?> readSchedule() async {
    if (_activeCharacteristic != null) {
      await requestAllSchedule();
    }
    return null;
  }
}
