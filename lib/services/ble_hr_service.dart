import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/hr_data.dart';
import 'auth_service.dart';
import 'strap_claim_repository.dart';

/// Initialize flutter_blue_plus (call once at app startup)
Future<void> initBle() async {
  FlutterBluePlus.setLogLevel(LogLevel.warning);
}

/// BLE Heart Rate Monitor Service
/// Handles scanning, connecting, and reading heart rate data
/// from any BLE device that implements the standard HR Service (0x180D)
class BleHrService {
  /// App-wide shared instance — pairing, settings and workout screens all
  /// talk to the same connection. Never call [dispose] on it.
  static final BleHrService instance = BleHrService();

  // Standard BLE Heart Rate Service & Characteristic UUIDs
  static final Guid _hrServiceUuid = Guid('180D');
  static final Guid _hrCharacteristicUuid = Guid('2A37');

  // 10.1 — Battery Service
  static final Guid _batteryServiceUuid = Guid('180F');
  static final Guid _batteryLevelUuid = Guid('2A19');

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

  // 10.1 — Battery level (-1 = unknown)
  int _batteryLevel = -1;
  int get batteryLevel => _batteryLevel;
  final _batteryController = StreamController<int>.broadcast();
  Stream<int> get batteryStream => _batteryController.stream;

  // 10.2 — RSSI signal strength
  int _rssi = 0;
  int get rssi => _rssi;
  final _rssiController = StreamController<int>.broadcast();
  Stream<int> get rssiStream => _rssiController.stream;
  Timer? _rssiTimer;

  // Cross-phone strap claim — the advertised name we've reserved in Firestore
  // for the current connection, kept alive by [_claimTimer].
  String? _claimedStrap;
  Timer? _claimTimer;

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

  /// Connect to a specific BLE device and start reading HR data.
  ///
  /// [strapName] is the strap's advertised name — the cross-phone-stable key
  /// used to reserve it in the global claim registry. If another live user
  /// already holds it, the connect is refused with [BleConnectionState.occupied]
  /// and no BLE link is opened (so we never hijack an in-use strap).
  Future<void> connectToDevice(BluetoothDevice device, {String? strapName}) async {
    final uid = AuthService.currentUid;
    final canClaim = strapName != null && strapName.isNotEmpty && uid != null;
    if (canClaim) {
      final ok = await StrapClaimRepository.tryClaim(
        strapName: strapName,
        uid: uid,
        userName: AuthService.currentUser?.displayName ?? '',
      );
      if (!ok) {
        debugPrint('[BeatSync] ⛔ Strap "$strapName" is claimed by another user');
        _connectionStateController.add(BleConnectionState.occupied);
        return;
      }
    }
    try {
      debugPrint('[BeatSync] Connecting to ${device.platformName} (${device.remoteId})...');
      _connectionStateController.add(BleConnectionState.connecting);
      await stopScan();

      // Connect — skip MTU negotiation (Garmin doesn't support it)
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
        // ⚠️ flutter_blue_plus v2 dual license: this declares NON-commercial
        // use. Before charging customers, either buy the commercial license
        // or pin to the last BSD release (1.35.x). Tracked in HANDOFF.md.
        // ignore: deprecated_member_use
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
          _releaseClaim();
          _connectionStateController.add(BleConnectionState.disconnected);
          _connectedDevice = null;
        }
      });

      // Discover services and find HR characteristic
      final found = await _discoverAndSubscribe(device);

      if (found) {
        debugPrint('[BeatSync] ✅ HR data streaming!');
        _connectionStateController.add(BleConnectionState.connected);

        // Hold the cross-phone claim for as long as we stay connected.
        if (canClaim) {
          _claimedStrap = strapName;
          _claimTimer?.cancel();
          _claimTimer = Timer.periodic(const Duration(seconds: 15),
              (_) => StrapClaimRepository.heartbeat(strapName));
        }

        // 10.1 — Read battery level
        _readBatteryLevel(device);

        // 10.2 — Start RSSI polling every 10s
        _rssiTimer?.cancel();
        _rssiTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
          try {
            final r = await device.readRssi();
            _rssi = r;
            _rssiController.add(r);
          } catch (_) {}
        });
        // Initial read
        try {
          _rssi = await device.readRssi();
          _rssiController.add(_rssi);
        } catch (_) {}
      } else {
        debugPrint('[BeatSync] ❌ HR Service not found');
        if (canClaim) await StrapClaimRepository.release(strapName);
        await device.disconnect();
        _connectedDevice = null;
        _connectionStateController.add(BleConnectionState.error);
      }
    } catch (e) {
      debugPrint('[BeatSync] ❌ Connection error: $e');
      if (canClaim) await StrapClaimRepository.release(strapName);
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

  /// 10.1 — Read battery level from BLE Battery Service
  Future<void> _readBatteryLevel(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid == _batteryServiceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid == _batteryLevelUuid) {
              final value = await char.read();
              if (value.isNotEmpty) {
                _batteryLevel = value[0];
                _batteryController.add(_batteryLevel);
                debugPrint('[BeatSync] 🔋 Battery: $_batteryLevel%');
              }
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[BeatSync] Battery read failed: $e');
    }
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

  /// Cancels the heartbeat and frees our cross-phone strap claim. Idempotent.
  void _releaseClaim() {
    _claimTimer?.cancel();
    _claimTimer = null;
    final strap = _claimedStrap;
    _claimedStrap = null;
    if (strap != null) StrapClaimRepository.release(strap);
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    _releaseClaim();
    _rssiTimer?.cancel();
    _rssiTimer = null;
    await _hrSubscription?.cancel();
    _hrSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _batteryLevel = -1;
    _rssi = 0;
    _connectionStateController.add(BleConnectionState.disconnected);
  }

  /// Clean up all resources
  Future<void> dispose() async {
    await disconnect();
    await stopScan();
    await _hrDataController.close();
    await _connectionStateController.close();
    await _scanResultsController.close();
    await _batteryController.close();
    await _rssiController.close();
  }
}

/// BLE connection states
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
  occupied,
}
