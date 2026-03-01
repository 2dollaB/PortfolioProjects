import 'dart:async';
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

  /// Start scanning for BLE Heart Rate devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    // Stop any existing scan
    await stopScan();

    _connectionStateController.add(BleConnectionState.scanning);

    // Scan for devices advertising the HR Service
    await FlutterBluePlus.startScan(
      withServices: [_hrServiceUuid],
      timeout: timeout,
      androidUsesFineLocation: false,
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResultsController.add(results);
    });

    // Auto-stop after timeout
    Future.delayed(timeout, () {
      if (!_hrDataController.isClosed) {
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
      _connectionStateController.add(BleConnectionState.connecting);
      await stopScan();

      // Connect (license: empty string for non-commercial/hobby use)
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
        license: License.free,
      );
      _connectedDevice = device;

      // Monitor connection state
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _connectionStateController.add(BleConnectionState.disconnected);
          _connectedDevice = null;
        }
      });

      // Discover services and find HR characteristic
      await _discoverAndSubscribe(device);

      _connectionStateController.add(BleConnectionState.connected);
    } catch (e) {
      _connectionStateController.add(BleConnectionState.error);
      _connectedDevice = null;
      rethrow;
    }
  }

  /// Discover HR service and subscribe to notifications
  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid == _hrServiceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid == _hrCharacteristicUuid) {
            // Enable notifications
            await char.setNotifyValue(true);

            // Listen for HR data
            _hrSubscription = char.onValueReceived.listen((value) {
              final hrData = _parseHrData(value);
              if (hrData != null) {
                _hrDataController.add(hrData);
              }
            });
            return;
          }
        }
      }
    }

    throw Exception('Heart Rate Service not found on device.');
  }

  /// Parse raw BLE Heart Rate Measurement data
  /// BLE HR Measurement format:
  ///   Byte 0: Flags
  ///     Bit 0: 0 = HR uint8, 1 = HR uint16
  ///     Bit 4: 1 = RR interval present
  ///   Byte 1(-2): Heart rate value
  ///   Remaining: RR intervals (uint16, units of 1/1024 sec)
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

    // Parse RR intervals if present
    final rrIntervals = <int>[];
    if (hasRrInterval) {
      while (offset + 1 < data.length) {
        // RR interval in 1/1024 seconds, convert to milliseconds
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
