import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/hr_data.dart';
import '../services/ble_hr_service.dart';
import '../services/storage_service.dart';

/// Singleton BleHrService instance — lives for app lifetime
final bleServiceProvider = Provider<BleHrService>((ref) {
  final service = BleHrService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Live HR data stream from connected sensor
final hrDataStreamProvider = StreamProvider<HrData>((ref) {
  return ref.watch(bleServiceProvider).hrDataStream;
});

/// BLE connection state stream
final bleConnectionStateProvider = StreamProvider<BleConnectionState>((ref) {
  return ref.watch(bleServiceProvider).connectionState;
});

/// BLE scan results stream
final bleScanResultsProvider = StreamProvider<List<ScanResult>>((ref) {
  return ref.watch(bleServiceProvider).scanResults;
});

/// Battery level stream
final bleBatteryProvider = StreamProvider<int>((ref) {
  return ref.watch(bleServiceProvider).batteryStream;
});

/// RSSI signal strength stream
final bleRssiProvider = StreamProvider<int>((ref) {
  return ref.watch(bleServiceProvider).rssiStream;
});

/// Controller for BLE actions (scan, connect, disconnect, auto-reconnect)
class BleController extends Notifier<void> {
  @override
  void build() {}

  BleHrService get _ble => ref.read(bleServiceProvider);

  Future<void> startScan() => _ble.startScan();
  Future<void> stopScan() => _ble.stopScan();

  Future<void> connectToDevice(BluetoothDevice device) async {
    await _ble.connectToDevice(device);
    // Save for auto-reconnect
    await StorageService.saveLastDevice(
      device.remoteId.str,
      device.platformName,
    );
  }

  Future<void> disconnect() async {
    await _ble.disconnect();
    await StorageService.clearLastDevice();
  }

  /// Try to reconnect to the last known device
  Future<bool> tryAutoReconnect() async {
    final last = await StorageService.loadLastDevice();
    if (last.id == null) return false;

    // Scan briefly and look for the saved device
    await _ble.startScan(timeout: const Duration(seconds: 5));

    final completer = Completer<bool>();
    StreamSubscription? sub;

    sub = _ble.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.remoteId.str == last.id) {
          sub?.cancel();
          _ble.connectToDevice(r.device);
          completer.complete(true);
          return;
        }
      }
    });

    // Timeout after scan
    Future.delayed(const Duration(seconds: 6), () {
      if (!completer.isCompleted) {
        sub?.cancel();
        completer.complete(false);
      }
    });

    return completer.future;
  }
}

final bleControllerProvider = NotifierProvider<BleController, void>(
  BleController.new,
);
