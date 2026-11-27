import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Connects to the Gabay ESP32 sensor (see esp32/gabay_sensor).
/// The sensor sends text like "412,36.5" = gas reading, temperature in °C.
class BleSensor {
  static const deviceName = 'Gabay-Sensor';
  static final serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final dataUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _dataSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  final void Function(int gas, double tempC) onData;
  final void Function(String status) onStatus;

  BleSensor({required this.onData, required this.onStatus});

  bool get connected => _device != null;

  Future<void> connect() async {
    final perms = await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse].request();
    if (perms.values.any((p) => p.isPermanentlyDenied || p.isDenied)) {
      onStatus('Bluetooth permission denied');
      return;
    }
    if (await FlutterBluePlus.isSupported == false) {
      onStatus('Bluetooth not supported on this phone');
      return;
    }
    onStatus('Searching for $deviceName…');
    final found = Completer<BluetoothDevice?>();
    final scanSub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == deviceName && !found.isCompleted) found.complete(r.device);
      }
    });
    await FlutterBluePlus.startScan(withNames: [deviceName], timeout: const Duration(seconds: 12));
    final device = await found.future.timeout(const Duration(seconds: 13), onTimeout: () => null);
    await FlutterBluePlus.stopScan();
    await scanSub.cancel();
    if (device == null) {
      onStatus('Sensor not found. Is it powered on?');
      return;
    }
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      final services = await device.discoverServices();
      final service = services.firstWhere((s) => s.uuid == serviceUuid);
      final ch = service.characteristics.firstWhere((c) => c.uuid == dataUuid);
      await ch.setNotifyValue(true);
      _dataSub = ch.onValueReceived.listen(_parse);
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          onStatus('Sensor disconnected');
          _cleanup();
        }
      });
      _device = device;
      onStatus('Connected to $deviceName');
    } catch (e) {
      onStatus('Could not connect: $e');
      await device.disconnect();
    }
  }

  void _parse(List<int> bytes) {
    final parts = utf8.decode(bytes, allowMalformed: true).trim().split(',');
    if (parts.length < 2) return;
    final gas = int.tryParse(parts[0]);
    final temp = double.tryParse(parts[1]);
    if (gas != null && temp != null) onData(gas, temp);
  }

  void _cleanup() {
    _dataSub?.cancel();
    _connSub?.cancel();
    _dataSub = null;
    _connSub = null;
    _device = null;
  }

  Future<void> disconnect() async {
    final d = _device;
    _cleanup();
    await d?.disconnect();
  }
}
