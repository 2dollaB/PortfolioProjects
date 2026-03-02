import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_hr_service.dart';
import '../models/user_profile.dart';

import '../config/hr_zones.dart';
import '../config/theme.dart';
import 'workout_screen.dart';
import 'workout_history_screen.dart';
import 'profile_edit_screen.dart';
import 'tv_host_screen.dart';
import '../services/tv_server.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile profile;
  final Function(UserProfile)? onProfileUpdated;

  const HomeScreen({super.key, required this.profile, this.onProfileUpdated});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final BleHrService _bleService = BleHrService();
  final TvServer _tvServer = TvServer();

  // State
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  List<ScanResult> _scanResults = [];
  int _currentBpm = 0;
  int _currentZone = 0;
  String? _connectingDeviceId;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Subscriptions
  StreamSubscription? _hrSub;
  StreamSubscription? _connSub;
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _connSub = _bleService.connectionState.listen((state) {
      setState(() => _connectionState = state);

      // Show error feedback
      if (state == BleConnectionState.error && mounted) {
        _connectingDeviceId = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Connection failed. Tried GATT + advertisement mode. Check device is actively broadcasting HR.'),
            backgroundColor: HrZones.colors[5],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      if (state == BleConnectionState.connected) {
        _connectingDeviceId = null;
      }
      if (state == BleConnectionState.disconnected) {
        _connectingDeviceId = null;
      }
    });

    _scanSub = _bleService.scanResults.listen((results) {
      setState(() => _scanResults = results);
    });

    _hrSub = _bleService.hrDataStream.listen((data) {
      setState(() {
        _currentBpm = data.bpm;
        _currentZone = HrZones.fromBpm(data.bpm, widget.profile.hrMax);
      });
      _pulseController.forward().then((_) => _pulseController.reverse());
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
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

  void _startWorkout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutScreen(
          profile: widget.profile,
          bleService: _bleService,
          tvServer: _tvServer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _connectionState == BleConnectionState.connected
          ? _buildConnectedView()
          : _buildScannerView(),
    );
  }

  // ═══════════════════════════════════════════
  // SCANNER VIEW
  // ═══════════════════════════════════════════
  Widget _buildScannerView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top bar with History + Profile
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WorkoutHistoryScreen())),
                  icon: Icon(Icons.history, color: AppTheme.textSecondary),
                  tooltip: 'Workout History',
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => TvHostScreen(tvServer: _tvServer))),
                      icon: Icon(Icons.tv,
                        color: _tvServer.isRunning ? AppTheme.accent : AppTheme.textSecondary),
                      tooltip: 'TV Display',
                    ),
                    IconButton(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ProfileEditScreen(
                          profile: widget.profile,
                          onSaved: (p) => widget.onProfileUpdated?.call(p),
                        ))),
                      icon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
                      tooltip: 'Edit Profile',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Icon(Icons.monitor_heart_outlined, size: 64, color: AppTheme.accent),
            const SizedBox(height: 16),
            const Text(
              'BeatSync',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Text(
              'Hey ${widget.profile.name}! Connect your HR monitor',
              style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'HRmax: ${widget.profile.hrMax} BPM',
                style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _connectionState == BleConnectionState.scanning ? null : _startScan,
                icon: _connectionState == BleConnectionState.scanning
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(
                  _connectionState == BleConnectionState.scanning ? 'Scanning...' : 'Scan for Devices',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _scanResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bluetooth, size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            _connectionState == BleConnectionState.scanning
                                ? 'Looking for HR monitors...\nMake sure Broadcast HR is on'
                                : 'Tap "Scan" to find nearby\nheart rate monitors',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
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
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.monitor_heart, color: AppTheme.accent),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Signal: ${result.rssi} dBm',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        trailing: _connectingDeviceId == result.device.remoteId.str
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textMuted),
        onTap: _connectionState == BleConnectionState.connecting
            ? null
            : () {
                setState(() => _connectingDeviceId = result.device.remoteId.str);
                _bleService.connectToDevice(result.device);
              },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CONNECTED VIEW — Ready to start workout
  // ═══════════════════════════════════════════
  Widget _buildConnectedView() {
    final zoneColor = HrZones.colors[_currentZone] ?? Colors.grey;
    final zoneName = HrZones.names[_currentZone] ?? 'Rest';
    final pctOfMax = HrZones.percentOfMax(_currentBpm, widget.profile.hrMax);

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [zoneColor.withValues(alpha: 0.15), AppTheme.background],
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
                  Row(
                    children: [
                      Icon(Icons.bluetooth_connected, color: zoneColor, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _bleService.connectedDeviceName ?? 'Connected',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () async {
                      await _bleService.disconnect();
                      setState(() { _currentBpm = 0; _currentZone = 0; });
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: zoneColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: zoneColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Zone $_currentZone · $zoneName',
                  style: TextStyle(color: zoneColor, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // BPM
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(scale: _pulseAnimation.value, child: child),
              child: Column(
                children: [
                  Icon(Icons.favorite, color: zoneColor, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    _currentBpm > 0 ? '$_currentBpm' : '--',
                    style: TextStyle(
                      fontSize: 100, fontWeight: FontWeight.w200, color: Colors.white, height: 1,
                      shadows: [Shadow(color: zoneColor.withValues(alpha: 0.5), blurRadius: 40)],
                    ),
                  ),
                  Text('BPM',
                      style: TextStyle(fontSize: 18, color: AppTheme.textSecondary, letterSpacing: 4, fontWeight: FontWeight.w300)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('$pctOfMax% of max',
                style: TextStyle(fontSize: 16, color: zoneColor, fontWeight: FontWeight.w500)),

            const Spacer(flex: 1),

            // Zone bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildZoneBar(),
            ),

            const SizedBox(height: 32),

            // START WORKOUT button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _startWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: zoneColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text('START WORKOUT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

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
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                  : [],
            ),
            child: isActive
                ? Center(
                    child: Text('Z$zone',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  )
                : null,
          ),
        );
      }),
    );
  }
}
