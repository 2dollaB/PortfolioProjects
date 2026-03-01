import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/hr_data.dart';

/// Initialize flutter_blue_plus (call once at app startup)
Future<void> initBle() async {
  FlutterBluePlus.setLogLevel(LogLevel.warning);
}

/// BLE Heart Rate Monitor Service
/// Handles scanning, connecting, and reading heart rate data
/// from any BLE device that implements the standard HR Service (0x180D)
class BleHrService {
  // Standard BLE Heart Rate Service & Characteristic UUIDs
  static final Guid _hrServiceUuid = Guid('180D');
  static final Guid _hrCharacteristicUuid = Guid('2A37');

  // State
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _hrSubscription;
  StreamSubscription? _connectionSubscription;

  // Streams
  final _hrDataController = StreamController<HrData>.broadcast();
  final _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  final _scanResultsController =
      StreamController<List<ScanResult>>.broadcast();

  Stream<HrData> get hrDataStream => _hrDataController.stream;
  Stream<BleConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  bool get isConnected => _connectedDevice != null;
  String? get connectedDeviceName => _connectedDevice?.platformName;

  /// Start scanning for BLE Heart Rate devices only
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    await stopScan();

    _connectionStateController.add(BleConnectionState.scanning);

    // Only scan for devices that advertise Heart Rate Service
    await FlutterBluePlus.startScan(
      withServices: [_hrServiceUuid],
      timeout: timeout,
      androidUsesFineLocation: false,
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResultsController.add(results);
    });

    // After scan timeout, reset state only if not connected
    Future.delayed(timeout, () {
      if (!_hrDataController.isClosed && _connectedDevice == null) {
        _connectionStateController.add(BleConnectionState.disconnected);
      }
    });
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// Connect to a specific BLE device and start reading HR data
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint('[BeatSync] Connecting to ${device.platformName} (${device.remoteId})...');
      _connectionStateController.add(BleConnectionState.connecting);
      await stopScan();

      // Connect — skip MTU negotiation (Garmin doesn't support it)
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
        license: License.free,
        mtu: null, // Skip MTU negotiation — fixes Garmin timeout
      );
      debugPrint('[BeatSync] ✅ Connected! Discovering services...');
      _connectedDevice = device;

      // Monitor connection state
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[BeatSync] Device disconnected');
          _connectionStateController.add(BleConnectionState.disconnected);
          _connectedDevice = null;
        }
      });

      // Discover services and find HR characteristic
      final found = await _discoverAndSubscribe(device);

      if (found) {
        debugPrint('[BeatSync] ✅ HR data streaming!');
        _connectionStateController.add(BleConnectionState.connected);
      } else {
        debugPrint('[BeatSync] ❌ HR Service not found');
        await device.disconnect();
        _connectedDevice = null;
        _connectionStateController.add(BleConnectionState.error);
      }
    } catch (e) {
      debugPrint('[BeatSync] ❌ Connection error: $e');
      _connectionStateController.add(BleConnectionState.error);
      _connectedDevice = null;
      try { await device.disconnect(); } catch (_) {}
    }
  }

  /// Discover HR service and subscribe to notifications
  Future<bool> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();

    debugPrint('[BeatSync] Found ${services.length} services');
    for (final service in services) {
      debugPrint('[BeatSync]   Service: ${service.uuid}');
      if (service.uuid == _hrServiceUuid) {
        for (final char in service.characteristics) {
          debugPrint('[BeatSync]     Char: ${char.uuid} notify=${char.properties.notify}');
          if (char.uuid == _hrCharacteristicUuid) {
            await char.setNotifyValue(true);

            _hrSubscription = char.onValueReceived.listen((value) {
              final hrData = _parseHrData(value);
              if (hrData != null) {
                _hrDataController.add(hrData);
              }
            });
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Parse raw BLE Heart Rate Measurement data
  HrData? _parseHrData(List<int> data) {
    if (data.isEmpty) return null;

    final flags = data[0];
    final isHr16bit = (flags & 0x01) != 0;
    final hasRrInterval = (flags & 0x10) != 0;

    int bpm;
    int offset;

    if (isHr16bit) {
      if (data.length < 3) return null;
      bpm = data[1] + (data[2] << 8);
      offset = 3;
    } else {
      if (data.length < 2) return null;
      bpm = data[1];
      offset = 2;
    }

    if (bpm < 20 || bpm > 250) return null;

    final rrIntervals = <int>[];
    if (hasRrInterval) {
      while (offset + 1 < data.length) {
        final rr = data[offset] + (data[offset + 1] << 8);
        rrIntervals.add((rr * 1000 / 1024).round());
        offset += 2;
      }
    }

    return HrData(bpm: bpm, rrIntervals: rrIntervals);
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    await _hrSubscription?.cancel();
    _hrSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _connectionStateController.add(BleConnectionState.disconnected);
  }

  /// Clean up all resources
  Future<void> dispose() async {
    await disconnect();
    await stopScan();
    await _hrDataController.close();
    await _connectionStateController.close();
    await _scanResultsController.close();
  }
}

/// BLE connection states
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}
