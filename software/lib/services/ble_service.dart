import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String deviceName = "MedAlert_ESP32";

  Future<BluetoothDevice?> scanAndConnect() async {
    print("Starting BLE Scan sequence...");
    try {
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        print("Bluetooth adapter is NOT on.");
        return null;
      }
    } catch (e) {
      print("Error checking adapter state: \$e");
      return null;
    }

    print("Adapter is ON. Initiating startScan()...");
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      print("Exception from startScan(): \$e");
      // Could be missing permissions!
      rethrow;
    }

    BluetoothDevice? targetDevice;
    Completer<BluetoothDevice?> completer = Completer();

    var subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;

        if (name.isNotEmpty) {
          print("Discovered device: \$name [ID: \${r.device.remoteId}]");
        }

        if (name.contains("MedAlert")) {
          print("MATCH FOUND: \$name");
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
      final device = await completer.future.timeout(
        const Duration(seconds: 10),
      );
      subscription.cancel();

      if (device != null) {
        print("Attempting to connect to device...");
        await device.connect(
          autoConnect: false,
          timeout: const Duration(seconds: 10),
          license: License.free,
        );
        print("Successfully connected!");
        return device;
      }
    } catch (e) {
      print("Scan/Connect timeout or error: \$e");
      subscription.cancel();
      FlutterBluePlus.stopScan();
      return null;
    }

    return targetDevice;
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      // Ignore disconnect errors
    }
  }

  // --- Legacy stubs to satisfy AppState (to be refactored out later) ---
  Future<void> connectToDevice(Function(Map<String, dynamic>) onNotify) async {}
  Stream<BluetoothConnectionState> get connectionState =>
      Stream.value(BluetoothConnectionState.disconnected);
  Future<String?> readSchedule() async => null;
  Future<bool> sendCommand(Map<String, dynamic> jsonCmd) async => false;
}
