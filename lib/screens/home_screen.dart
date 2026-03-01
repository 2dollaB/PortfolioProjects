import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_hr_service.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final BleHrService _bleService = BleHrService();

  // State
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  List<ScanResult> _scanResults = [];
  int _currentBpm = 0;
  int _currentZone = 0;
  int _previousZone = 0;

  // Config — default HRmax using Tanaka for age 30
  final int _hrMax = HrZones.tanaka(30);

  // Animation
  late AnimationController _pulseController;
  late AnimationController _zoneTransitionController;
  late Animation<double> _pulseAnimation;

  // Subscriptions
  StreamSubscription? _hrSub;
  StreamSubscription? _connSub;
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();

    // Pulse animation (heartbeat effect)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Zone transition animation
    _zoneTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Listen to BLE events
    _connSub = _bleService.connectionState.listen((state) {
      setState(() => _connectionState = state);
    });

    _scanSub = _bleService.scanResults.listen((results) {
      setState(() => _scanResults = results);
    });

    _hrSub = _bleService.hrDataStream.listen((data) {
      setState(() {
        _currentBpm = data.bpm;
        _previousZone = _currentZone;
        _currentZone = HrZones.fromBpm(data.bpm, _hrMax);
      });

      // Trigger heartbeat animation
      _pulseController.forward().then((_) => _pulseController.reverse());

      // Trigger zone transition if changed
      if (_currentZone != _previousZone) {
        _zoneTransitionController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _zoneTransitionController.dispose();
    _hrSub?.cancel();
    _connSub?.cancel();
    _scanSub?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _startScan() async {
    await _requestPermissions();
    await _bleService.startScan(timeout: const Duration(seconds: 15));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _connectionState == BleConnectionState.connected
          ? _buildLiveHrView()
          : _buildScannerView(),
    );
  }

  // ═══════════════════════════════════════════════
  // SCANNER VIEW — Find and connect to HR devices
  // ═══════════════════════════════════════════════
  Widget _buildScannerView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),

            // Logo / Title
            Icon(
              Icons.monitor_heart_outlined,
              size: 64,
              color: AppTheme.accent,
            ),
            const SizedBox(height: 16),
            const Text(
              'BeatSync',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your heart rate monitor',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 40),

            // Scan Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _connectionState == BleConnectionState.scanning
                    ? null
                    : _startScan,
                icon: _connectionState == BleConnectionState.scanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(
                  _connectionState == BleConnectionState.scanning
                      ? 'Scanning...'
                      : 'Scan for Devices',
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Scan Results
            Expanded(
              child: _scanResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bluetooth,
                            size: 48,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _connectionState == BleConnectionState.scanning
                                ? 'Looking for HR monitors...\nMake sure Broadcast HR is on'
                                : 'Tap "Scan" to find nearby\nheart rate monitors',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _scanResults.length,
                      itemBuilder: (context, index) {
                        final result = _scanResults[index];
                        final name = result.device.platformName.isNotEmpty
                            ? result.device.platformName
                            : 'Unknown Device';
                        return _buildDeviceCard(name, result);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(String name, ScanResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.monitor_heart,
            color: AppTheme.accent,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Signal: ${result.rssi} dBm',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        trailing: _connectionState == BleConnectionState.connecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textMuted,
              ),
        onTap: () => _bleService.connectToDevice(result.device),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // LIVE HR VIEW — Real-time heart rate display
  // ═══════════════════════════════════════════════
  Widget _buildLiveHrView() {
    final zoneColor = HrZones.colors[_currentZone] ?? Colors.grey;
    final zoneName = HrZones.names[_currentZone] ?? 'Rest';
    final zoneIcon = HrZones.icons[_currentZone] ?? Icons.favorite;
    final pctOfMax = HrZones.percentOfMax(_currentBpm, _hrMax);

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            zoneColor.withValues(alpha: 0.15),
            AppTheme.background,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Device name
                  Row(
                    children: [
                      Icon(Icons.bluetooth_connected,
                          color: zoneColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _bleService.connectedDeviceName ?? 'Connected',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // Disconnect button
                  IconButton(
                    onPressed: () async {
                      await _bleService.disconnect();
                      setState(() {
                        _currentBpm = 0;
                        _currentZone = 0;
                      });
                    },
                    icon: Icon(Icons.close, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Zone label
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(_currentZone),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: zoneColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: zoneColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(zoneIcon, color: zoneColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Zone $_currentZone · $zoneName',
                      style: TextStyle(
                        color: zoneColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // BPM — Main display with pulse animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Column(
                children: [
                  // Heart icon
                  Icon(
                    Icons.favorite,
                    color: zoneColor,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  // BPM number
                  Text(
                    _currentBpm > 0 ? '$_currentBpm' : '--',
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: zoneColor.withValues(alpha: 0.5),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'BPM',
                    style: TextStyle(
                      fontSize: 20,
                      color: AppTheme.textSecondary,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // % of HRmax
            Text(
              '$pctOfMax% of max',
              style: TextStyle(
                fontSize: 18,
                color: zoneColor,
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(flex: 1),

            // Zone bar at bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildZoneBar(),
            ),

            const SizedBox(height: 16),

            // HRmax info
            Text(
              'HRmax: $_hrMax BPM (Tanaka)',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  /// Visual zone indicator bar
  Widget _buildZoneBar() {
    return Row(
      children: List.generate(5, (index) {
        final zone = index + 1;
        final isActive = zone == _currentZone;
        final color = HrZones.colors[zone]!;

        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isActive ? 28 : 16,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isActive ? color : color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: isActive
                ? Center(
                    child: Text(
                      'Z$zone',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }
}
