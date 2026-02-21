import 'dart:convert';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String deviceName = "MedAlert";
  static const String serviceUuid = "7f6d0001-4b5c-4a7a-9c7e-9a2f3b6c1d10";
  static const String characteristicUuid =
      "7f6d0002-4b5c-4a7a-9c7e-9a2f3b6c1d10";

  BluetoothDevice? _device;
  BluetoothCharacteristic? _sharedCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _notifySubscription;
  StreamSubscription? _connectionSubscription;

  bool get isConnected => _device != null;

  Stream<BluetoothConnectionState> get connectionState =>
      _device?.connectionState ??
      Stream.value(BluetoothConnectionState.disconnected);

  Future<void> connectToDevice(Function(Map<String, dynamic>) onNotify) async {
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      print('Bluetooth adapter is not on.');
      return;
    }
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;
        if (name == deviceName) {
          await FlutterBluePlus.stopScan();
          await _scanSubscription?.cancel();
          _scanSubscription = null;
          _device = r.device;
          _connectionSubscription = _device!.connectionState.listen((
            state,
          ) async {
            if (state == BluetoothConnectionState.disconnected) {
              print('Device disconnected. Attempting reconnect...');
              _sharedCharacteristic = null;
              await Future.delayed(const Duration(seconds: 2));
              await connectToDevice(onNotify);
            }
          });
          try {
            await _device!.connect(autoConnect: false, license: License.free);
            await _discoverServices(onNotify);
            print('BLE CONNECTED SUCCESSFULLY');
          } catch (e) {
            print('Connection error: $e');
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
    final services = await _device!.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() ==
              characteristicUuid.toLowerCase()) {
            _sharedCharacteristic = characteristic;
            break;
          }
        }
        await _setupNotifications(onNotify);
        return;
      }
    }
    print('Target service/characteristic not found on device.');
  }

  Future<void> _setupNotifications(
    Function(Map<String, dynamic>) onNotify,
  ) async {
    if (_sharedCharacteristic == null) return;
    if (_sharedCharacteristic!.properties.notify) {
      await _sharedCharacteristic!.setNotifyValue(true);
      await _notifySubscription?.cancel();
      _notifySubscription = _sharedCharacteristic!.onValueReceived.listen((
        value,
      ) {
        if (value.isEmpty) return;
        try {
          final data = jsonDecode(utf8.decode(value)) as Map<String, dynamic>;
          onNotify(data);
        } catch (e) {
          print('Error decoding BLE notify: $e');
        }
      });
    }
  }

  Future<bool> sendCommand(Map<String, dynamic> jsonCmd) async {
    if (_sharedCharacteristic == null ||
        !_sharedCharacteristic!.properties.write) {
      print('Characteristic not ready for write.');
      return false;
    }
    try {
      await _device?.requestMtu(512);
      await _sharedCharacteristic!.write(
        utf8.encode(jsonEncode(jsonCmd)),
        withoutResponse: false,
      );
      return true;
    } catch (e) {
      print('Error sending BLE command: $e');
      return false;
    }
  }

  Future<String?> readSchedule() async {
    if (_sharedCharacteristic == null ||
        !_sharedCharacteristic!.properties.read)
      return null;
    try {
      return utf8.decode(await _sharedCharacteristic!.read());
    } catch (e) {
      print('Error reading BLE characteristic: $e');
      return null;
    }
  }

  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _scanSubscription?.cancel();
    await _device?.disconnect();
    _sharedCharacteristic = null;
    _device = null;
  }

  void dispose() => disconnect();
}
