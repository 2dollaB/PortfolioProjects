import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../models/workout_type.dart';
import '../services/ble_hr_service.dart';
import '../services/session_client.dart';
import '../services/storage_service.dart';
import '../services/tv_server.dart';
import 'join_session_screen.dart';
import 'profile_edit_screen.dart';
import 'session_host_screen.dart';
import 'workout_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile profile;
  final Function(UserProfile)? onProfileUpdated;

  const HomeScreen({super.key, required this.profile, this.onProfileUpdated});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late UserProfile _profile;
  final BleHrService _bleService = BleHrService();

  int _currentBpm = 0;
  int _currentZone = 0;
  bool _isConnected = false;
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  String? _connectedDeviceName;

  // UX-A — Weekly stats
  int _weekSessions = 0;
  int _weekMinutes = 0;
  int _weekCalories = 0;
  int _streak = 0;

  // TV & Session
  TvServer? _tvServer;
  SessionClient? _sessionClient;

  // Subscriptions
  StreamSubscription? _hrSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _scanSub;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Bottom nav — removed broken tab bar

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;

    // Pulse animation for heart icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _connectionSub = _bleService.connectionState.listen((state) {
      if (!mounted) return;
      final connected = state == BleConnectionState.connected;
      setState(() => _isConnected = connected);
      if (connected) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
        setState(() {
          _currentBpm = 0;
          _currentZone = 0;
          _connectedDeviceName = null;
        });
      }
    });

    _hrSub = _bleService.hrDataStream.listen((data) {
      if (!mounted) return;
      setState(() {
        _currentBpm = data.bpm;
        _currentZone = HrZones.fromBpm(data.bpm, _profile.hrMax);
      });
    });

    _scanSub = _bleService.scanResults.listen((results) {
      if (!mounted) return;
      setState(() => _scanResults = results);
    });

    // Auto-scan on start (with permission check)
    _initBleAndScan();

    // UX-A — Load weekly stats
    _loadWeeklyStats();
  }

  Future<void> _loadWeeklyStats() async {
    final stats = await StorageService.weeklyStats();
    final streak = await StorageService.calculateStreak();
    if (mounted) {
      setState(() {
        _weekSessions = stats.sessions;
        _weekMinutes = stats.minutes;
        _weekCalories = stats.calories;
        _streak = streak;
      });
    }
  }

  /// Request BLE permissions and then auto-reconnect or scan
  Future<void> _initBleAndScan() async {
    // Request BLE permissions
    final bleStatus = await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    if (bleStatus.isDenied || bleStatus.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bluetooth permission required to scan for HR monitors'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    // Try auto-reconnect to last device
    final lastDevice = await StorageService.loadLastDevice();
    if (lastDevice.id != null) {
      setState(() => _connectedDeviceName = lastDevice.name);
      // Try connecting to the bonded device
      try {
        final bondedDevices = await FlutterBluePlus.bondedDevices;
        for (final device in bondedDevices) {
          if (device.remoteId.str == lastDevice.id) {
            await _bleService.connectToDevice(device);
            return; // Connected, don't scan
          }
        }
      } catch (_) {
        // Auto-reconnect failed, fall through to scan
      }
      setState(() => _connectedDeviceName = null);
    }

    _startScan();
  }

  @override
  void dispose() {
    _hrSub?.cancel();
    _connectionSub?.cancel();
    _scanSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    try {
      await _bleService.startScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bluetooth error: $e'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connectToDevice(ScanResult result) async {
    HapticFeedback.mediumImpact();
    setState(() => _connectedDeviceName = result.device.platformName);
    try {
      await _bleService.connectToDevice(result.device);
      // Save for auto-reconnect
      await StorageService.saveLastDevice(
        result.device.remoteId.str,
        result.device.platformName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
        setState(() => _connectedDeviceName = null);
      }
    }
  }

  Future<void> _disconnectDevice() async {
    HapticFeedback.mediumImpact();
    await _bleService.disconnect();
    await StorageService.clearLastDevice();
    setState(() {
      _connectedDeviceName = null;
      _currentBpm = 0;
      _currentZone = 0;
    });
  }

  void _startWorkout() async {
    HapticFeedback.heavyImpact();

    // Show workout type selection sheet
    final selectedType = await showModalBottomSheet<WorkoutType>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Select Workout Type',
                style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Choose the type that matches your session',
                style: AppTheme.body(fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
              children: WorkoutType.values.map((type) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(ctx, type);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(type.icon, size: 26, color: AppTheme.accent),
                        const SizedBox(height: 6),
                        Text(type.displayName,
                            style: AppTheme.body(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: Colors.white,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );

    if (selectedType == null || !mounted) return;

    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => WorkoutScreen(
        profile: _profile,
        bleService: _bleService,
        tvServer: _tvServer,
        sessionClient: _sessionClient,
        workoutType: selectedType,
      ),
      transitionsBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ), child: child),
        );
      },
    ));
  }



  void _openProfile() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(

          profile: _profile,
          onSaved: (updated) {
            setState(() => _profile = updated);
            widget.onProfileUpdated?.call(updated);
          },
        ),
      ),
    );
  }

  void _openHostSession() {
    _tvServer ??= TvServer();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SessionHostScreen(tvServer: _tvServer!)),
    );
  }

  void _openJoinSession() {
    _sessionClient ??= SessionClient();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => JoinSessionScreen(
        sessionClient: _sessionClient!,
      ),
    ));
  }



  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.3, -0.5),
          radius: 1.4,
          colors: [
            Color(0xFF12122A),
            Color(0xFF0A0A12),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _isConnected
            ? _buildConnectedView()
            : _buildScannerView(),
      ),
    );
  }



  // ═══════════════════════════════════════════════════
  // SCANNER VIEW — When no device is connected
  // ═══════════════════════════════════════════════════
  Widget _buildScannerView() {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Header: Logo + Settings ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // BeatSync logo
                  Row(
                    children: [
                      Icon(Icons.favorite, color: AppTheme.accent, size: 22),
                      const SizedBox(width: 8),
                      Text('BeatSync',
                          style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openProfile,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_outline, size: 20, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── User Profile Card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.boldCard(),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.accent.withValues(alpha: 0.3),
                            AppTheme.accentDark.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          _profile.name.isNotEmpty ? _profile.name[0].toUpperCase() : 'A',
                          style: AppTheme.heading(fontSize: 22, color: AppTheme.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_profile.name.isEmpty ? 'Athlete' : _profile.name,
                              style: AppTheme.heading(fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${_profile.role.displayName} • ${_profile.fitnessLevel.displayName} • ${_isConnected ? 'Connected' : 'Offline'}',
                              style: AppTheme.body(fontSize: 12, color: _isConnected ? AppTheme.success : AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // UX-A — Weekly Stats Card
            _buildWeeklyStatsCard(),
            const SizedBox(height: 16),

            // ── Connection Status + BPM ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.5),
                    radius: 1.5,
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.06),
                      AppTheme.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    // Connection dot + status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isScanning ? AppTheme.warning : AppTheme.textMuted,
                            boxShadow: _isScanning ? [
                              BoxShadow(color: AppTheme.warning.withValues(alpha: 0.5), blurRadius: 6),
                            ] : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isScanning ? 'Scanning...' : 'No Device Connected',
                          style: AppTheme.body(
                            fontSize: 13,
                            color: _isScanning ? AppTheme.warning : AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Large "--" BPM display
                    Text('--',
                        style: AppTheme.heading(fontSize: 64, fontWeight: FontWeight.w800,
                            color: AppTheme.textMuted)),
                    Text('BPM',
                        style: AppTheme.body(fontSize: 16, color: AppTheme.textMuted)),
                    const SizedBox(height: 16),

                    // Zone labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (i) {
                          final zone = i + 1;
                          return Text(
                            HrZones.names[zone]?.toUpperCase() ?? 'Z$zone',
                            style: AppTheme.mono(
                              fontSize: 9, letterSpacing: 0.5,
                              color: AppTheme.textMuted.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── START WORKOUT button (UX-2: enabled even without BLE) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final proceed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Row(
                          children: [
                            Icon(Icons.bluetooth_disabled, color: AppTheme.warning, size: 24),
                            const SizedBox(width: 10),
                            Text('No HR Monitor', style: AppTheme.heading(fontSize: 18)),
                          ],
                        ),
                        content: Text(
                          'Start workout without heart rate data?\n\nNo calories, HR zones, or analytics will be recorded.',
                          style: AppTheme.body(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Connect First', style: AppTheme.body(color: AppTheme.textMuted)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.warning,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Start Anyway', style: AppTheme.body(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                    if (proceed == true) _startWorkout();
                  },
                  icon: Icon(Icons.play_arrow_rounded, size: 24, color: AppTheme.textMuted.withValues(alpha: 0.7)),
                  label: Text('START WORKOUT',
                      style: AppTheme.heading(
                        fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1,
                        color: AppTheme.textMuted.withValues(alpha: 0.7),
                      )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Available Devices ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Available Devices',
                      style: AppTheme.heading(fontSize: 17, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isScanning ? null : _startScan,
                    child: Row(
                      children: [
                        if (_isScanning)
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              color: AppTheme.accent, strokeWidth: 2),
                          )
                        else
                          Icon(Icons.refresh_rounded, size: 16, color: AppTheme.accent),
                        const SizedBox(width: 6),
                        Text(
                          _isScanning ? 'SEARCHING' : 'SCAN',
                          style: AppTheme.mono(
                            fontSize: 11, letterSpacing: 1.2,
                            color: AppTheme.accent, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Device List ──
            if (_scanResults.isEmpty && !_isScanning)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.bluetooth_searching, size: 48,
                        color: AppTheme.textMuted.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('No devices found',
                        style: AppTheme.body(color: AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    Text('Make sure your HR monitor is active',
                        style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted.withValues(alpha: 0.6))),
                  ],
                ),
              )
            else
              ..._scanResults.map((result) => _buildDeviceRow(result)),

            const SizedBox(height: 16),

            // ── Group Session Actions ──
            if (_profile.role == UserRole.trainer) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Group Session',
                    style: AppTheme.heading(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'Host Session', Icons.cast_connected, AppTheme.accent,
                        onTap: _openHostSession,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        'Join Session', Icons.qr_code_scanner, AppTheme.success,
                        onTap: _openJoinSession,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildActionButton(
                  'Join Group Session', Icons.qr_code_scanner, AppTheme.success,
                  onTap: _openJoinSession,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceRow(ScanResult result) {
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : 'Unknown Device';
    final rssi = result.rssi;
    String signalStr = 'Weak';
    Color signalColor = AppTheme.danger;
    if (rssi > -60) {
      signalStr = 'Strong';
      signalColor = AppTheme.success;
    } else if (rssi > -80) {
      signalStr = 'Moderate';
      signalColor = AppTheme.warning;
    }

    final icoData = name.toLowerCase().contains('apple')
        ? Icons.watch
        : name.toLowerCase().contains('wahoo') || name.toLowerCase().contains('tickr')
            ? Icons.sensors
            : Icons.monitor_heart;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: AppTheme.boldCard(borderRadius: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icoData, size: 20, color: AppTheme.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTheme.body(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Signal: $signalStr',
                      style: AppTheme.body(fontSize: 11, color: signalColor)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _connectToDevice(result),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Text('PAIR',
                    style: AppTheme.mono(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppTheme.accent, letterSpacing: 1,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: AppTheme.body(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // UX-A — Weekly Stats Card
  Widget _buildWeeklyStatsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        child: Row(
          children: [
            _buildStatItem('$_weekSessions', 'Sessions', Icons.fitness_center_rounded, AppTheme.accent),
            _buildStatDivider(),
            _buildStatItem('$_weekMinutes', 'Minutes', Icons.timer_outlined, const Color(0xFF06B6D4)),
            _buildStatDivider(),
            _buildStatItem('$_weekCalories', 'Calories', Icons.local_fire_department, const Color(0xFFF97316)),
            _buildStatDivider(),
            _buildStatItem('$_streak', 'Streak 🔥', Icons.trending_up_rounded, AppTheme.success),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.heading(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: AppTheme.body(fontSize: 9, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 36, color: AppTheme.surfaceLight);
  }



  // ═══════════════════════════════════════════════════
  // CONNECTED VIEW — Device connected, showing live HR
  // ═══════════════════════════════════════════════════
  Widget _buildConnectedView() {
    final zoneColor = HrZones.colors[_currentZone] ?? AppTheme.textMuted;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite, color: AppTheme.accent, size: 22),
                      const SizedBox(width: 8),
                      Text('BeatSync',
                          style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openProfile,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_outline, size: 20, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── User Profile Card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.boldCard(),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.accent.withValues(alpha: 0.3),
                            AppTheme.accentDark.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          _profile.name.isNotEmpty ? _profile.name[0].toUpperCase() : 'A',
                          style: AppTheme.heading(fontSize: 22, color: AppTheme.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_profile.name.isEmpty ? 'Athlete' : _profile.name,
                              style: AppTheme.heading(fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${_profile.role.displayName} • Connected',
                              style: AppTheme.body(fontSize: 12, color: AppTheme.success)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // UX-A — Weekly Stats Card
            _buildWeeklyStatsCard(),
            const SizedBox(height: 12),

            // ── Connected Device Badge ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.success,
                      boxShadow: [
                        BoxShadow(color: AppTheme.success.withValues(alpha: 0.5), blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_connectedDeviceName ?? 'HR Monitor',
                      style: AppTheme.body(fontSize: 14, color: AppTheme.success, fontWeight: FontWeight.w500)),
                  Text(' Connected',
                      style: AppTheme.body(fontSize: 14, color: AppTheme.textSecondary)),
                  const Spacer(),
                  // Disconnect button
                  GestureDetector(
                    onTap: _disconnectDevice,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_off, size: 14, color: AppTheme.danger),
                          const SizedBox(width: 4),
                          Text('Disconnect',
                              style: AppTheme.mono(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: AppTheme.danger, letterSpacing: 0.5,
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Zone badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: zoneColor.withValues(alpha: 0.3)),
                    ),
                    child: Text('ZONE $_currentZone',
                        style: AppTheme.mono(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: zoneColor, letterSpacing: 1,
                        )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 7.7 Hero BPM Card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: AppTheme.glassmorphCard(tint: zoneColor),
                child: Column(
                  children: [
                    // Device name + zone badge row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.success,
                            boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.5), blurRadius: 4)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(_connectedDeviceName ?? 'HR Monitor',
                            style: AppTheme.body(fontSize: 11, color: AppTheme.textMuted)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: zoneColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            HrZones.names[_currentZone]?.toUpperCase() ?? 'REST',
                            style: AppTheme.mono(fontSize: 9, fontWeight: FontWeight.w700,
                                color: zoneColor, letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Large BPM with pulse
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _currentBpm > 0 ? _pulseAnim.value : 1.0,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(
                                scale: Tween(begin: 0.9, end: 1.0).animate(anim),
                                child: child,
                              ),
                            ),
                            child: Text(
                              _currentBpm > 0 ? '$_currentBpm' : '--',
                              key: ValueKey(_currentBpm),
                              style: AppTheme.bpmDisplay(fontSize: 80, glowColor: zoneColor),
                            ),
                          ),
                        );
                      },
                    ),
                    Text('BPM',
                        style: AppTheme.body(fontSize: 14, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 20),

                    // Zone progress bar
                    Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Row(
                          children: List.generate(5, (i) {
                            final zone = i + 1;
                            final isActive = zone <= _currentZone;
                            final color = HrZones.colors[zone]!;
                            return Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: EdgeInsets.only(right: i < 4 ? 2 : 0),
                                decoration: BoxDecoration(
                                  color: isActive ? color : color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: isActive ? [
                                    BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4),
                                  ] : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Zone labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: List.generate(5, (i) {
                          final zone = i + 1;
                          final isCurrentZone = zone == _currentZone;
                          final color = HrZones.colors[zone]!;
                          return Expanded(
                            child: Text(
                              HrZones.names[zone]?.substring(0, 3).toUpperCase() ?? 'Z$zone',
                              textAlign: TextAlign.center,
                              style: AppTheme.mono(
                                fontSize: 8, letterSpacing: 0.3,
                                color: isCurrentZone ? color : AppTheme.textMuted.withValues(alpha: 0.4),
                                fontWeight: isCurrentZone ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── START WORKOUT Button ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton.icon(
                  onPressed: _startWorkout,
                  icon: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.white),
                  label: Text('START WORKOUT',
                      style: AppTheme.heading(
                        fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1,
                        color: Colors.white,
                      )),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Available Devices ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Available Devices',
                      style: AppTheme.heading(fontSize: 17, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _startScan,
                    child: Text('SCAN',
                        style: AppTheme.mono(
                          fontSize: 11, letterSpacing: 1.2,
                          color: AppTheme.accent, fontWeight: FontWeight.w600,
                        )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._scanResults.map((result) => _buildDeviceRow(result)),
            const SizedBox(height: 20),

            // ── Group Actions ──
            if (_profile.role == UserRole.trainer) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'Host', Icons.cast_connected, AppTheme.accent,
                        onTap: _openHostSession,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        'Join', Icons.qr_code_scanner, AppTheme.success,
                        onTap: _openJoinSession,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildActionButton(
                  'Join Group Session', Icons.qr_code_scanner, AppTheme.success,
                  onTap: _openJoinSession,
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
