import 'dart:convert';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String deviceName = "MedAlert";
  static const String serviceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String charReadUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  static const String charWriteUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
  static const String charNotifyUuid = "6e400004-b5a3-f393-e0a9-e50e24dcca9e";

  BluetoothDevice? _device;
  BluetoothCharacteristic? _readCharacteristic;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _notifySubscription;

  // Expose device connection state for UI
  Stream<BluetoothConnectionState> get connectionState =>
      _device?.connectionState ??
      Stream.value(BluetoothConnectionState.disconnected);

  Future<void> connectToDevice(Function(Map<String, dynamic>) onNotify) async {
    // Start scanning
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName == deviceName ||
            r.device.advName == deviceName) {
          FlutterBluePlus.stopScan();
          _device = r.device;
          try {
            await _device!.connect(license: License.free);
            await _discoverServices(onNotify);
          } catch (e) {
            print('Connection error: \$e');
          }
          break;
        }
      }
    });
  }

  Future<void> _discoverServices(
    Function(Map<String, dynamic>) onNotify,
  ) async {
    if (_device == null) return;

    List<BluetoothService> services = await _device!.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == serviceUuid) {
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.uuid.toString() == charReadUuid) {
            _readCharacteristic = characteristic;
          } else if (characteristic.uuid.toString() == charWriteUuid) {
            _writeCharacteristic = characteristic;
          } else if (characteristic.uuid.toString() == charNotifyUuid) {
            _notifyCharacteristic = characteristic;
          }
        }
        await _setupNotifications(onNotify);
        break;
      }
    }
  }

  Future<void> _setupNotifications(
    Function(Map<String, dynamic>) onNotify,
  ) async {
    if (_notifyCharacteristic == null) return;

    if (_notifyCharacteristic!.properties.notify) {
      await _notifyCharacteristic!.setNotifyValue(true);
      _notifySubscription = _notifyCharacteristic!.onValueReceived.listen((
        value,
      ) {
        try {
          String jsonString = utf8.decode(value);
          Map<String, dynamic> data = jsonDecode(jsonString);
          onNotify(data);
        } catch (e) {
          print('Error decoding BLE notify response: \$e');
        }
      });
    }
  }

  Future<void> sendCommand(Map<String, dynamic> jsonCmd) async {
    if (_writeCharacteristic == null) return;
    try {
      String jsonString = jsonEncode(jsonCmd);
      List<int> bytes = utf8.encode(jsonString);
      await _writeCharacteristic!.write(bytes, withoutResponse: false);
    } catch (e) {
      print('Error sending BLE command: \$e');
    }
  }

  Future<String?> readSchedule() async {
    if (_readCharacteristic == null) return null;
    try {
      List<int> value = await _readCharacteristic!.read();
      return utf8.decode(value);
    } catch (e) {
      print('Error reading BLE schedule: \$e');
      return null;
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _device?.disconnect();
  }
}
