import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../services/ble_hr_service.dart';
import '../widgets/beat_button.dart';
import '../widgets/mobile_frame.dart';

/// Pair a BLE heart-rate sensor — any chest strap, or a watch in
/// heart-rate-broadcast mode. Drives the shared [BleHrService.instance];
/// once connected, the workout screen reads real HR from its
/// [BleHrService.hrDataStream] instead of the simulated curve.
class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen>
    with SingleTickerProviderStateMixin {
  final _ble = BleHrService.instance;

  late BleConnectionState _state;
  List<ScanResult> _results = const [];
  String? _connectingId;
  String _connectingName = '';
  int? _bpm;
  bool _failed = false;
  bool _occupied = false;

  StreamSubscription? _stateSub;
  StreamSubscription? _resultsSub;
  StreamSubscription? _hrSub;
  StreamSubscription? _battSub;
  StreamSubscription? _rssiSub;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _state = _ble.isConnected
        ? BleConnectionState.connected
        : BleConnectionState.disconnected;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _stateSub = _ble.connectionState.listen((s) {
      if (!mounted) return;
      // The scan's 15s timeout can fire while a connect is mid-flight and
      // emit a stale `disconnected` — the real outcome arrives right after
      // as `connected` or `error`. Ignore it.
      if (s == BleConnectionState.disconnected && _connectingId != null) {
        return;
      }
      setState(() {
        _occupied = s == BleConnectionState.occupied;
        _failed = s == BleConnectionState.error || _occupied;
        _state = s;
        if (s != BleConnectionState.connecting) _connectingId = null;
        if (s != BleConnectionState.connected) _bpm = null;
      });
    });
    _resultsSub = _ble.scanResults.listen((r) {
      if (mounted) setState(() => _results = r);
    });
    _hrSub = _ble.hrDataStream.listen((d) {
      if (mounted) setState(() => _bpm = d.bpm);
    });
    _battSub = _ble.batteryStream.listen((_) {
      if (mounted) setState(() {});
    });
    _rssiSub = _ble.rssiStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _stateSub?.cancel();
    _resultsSub?.cancel();
    _hrSub?.cancel();
    _battSub?.cancel();
    _rssiSub?.cancel();
    // Keep an active connection alive for the workout; just stop scanning.
    if (!_ble.isConnected) unawaited(_ble.stopScan());
    super.dispose();
  }

  /// Android 12+ needs runtime BLUETOOTH_SCAN/CONNECT. iOS and Web Bluetooth
  /// show their own native prompts on first use.
  Future<bool> _ensurePermissions() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    final ok = statuses.values.every((s) => s.isGranted);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Strings.btPermissionNeeded),
      ));
    }
    return ok;
  }

  Future<void> _startScan() async {
    if (!await _ensurePermissions()) return;
    setState(() {
      _results = const [];
      _failed = false;
      _occupied = false;
    });
    try {
      await _ble.startScan();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _stopScan() async {
    await _ble.stopScan();
    if (mounted) setState(() => _state = BleConnectionState.disconnected);
  }

  Future<void> _connect(ScanResult r) async {
    setState(() {
      _connectingId = r.device.remoteId.str;
      _connectingName = _nameOf(r);
    });
    await _ble.connectToDevice(r.device, strapName: _strapKeyOf(r));
  }

  static String _nameOf(ScanResult r) {
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    if (r.advertisementData.advName.isNotEmpty) {
      return r.advertisementData.advName;
    }
    return Strings.heartRateSensor;
  }

  /// The strap's advertised name — the cross-phone-stable key for the claim
  /// registry. Empty when the strap advertises no name (can't be coordinated).
  static String _strapKeyOf(ScanResult r) {
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    return r.advertisementData.advName;
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(Strings.heartRateSensor, style: AppTheme.h2()),
                  ],
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_state) {
      case BleConnectionState.connected:
        return _connectedView();
      case BleConnectionState.scanning:
      case BleConnectionState.connecting:
        return _searchView();
      case BleConnectionState.disconnected:
      case BleConnectionState.error:
      case BleConnectionState.occupied:
        return _idleView();
    }
  }

  // ── Idle / error: hero + CTA ─────────────────────────────────────────
  Widget _idleView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const Spacer(),
          _PulseHero(animation: _pulse, active: false),
          const SizedBox(height: AppSpacing.lg),
          Text(Strings.pairYourSensor, style: AppTheme.h1()),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Strings.pairSensorSubtitle,
            style: AppTheme.bodyLarge(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (_failed) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                _occupied
                    ? Strings.deviceOccupied
                    : Strings.couldNotConnectSensor,
                style: AppTheme.caption(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const Spacer(),
          BeatPrimaryButton(
            label: _failed ? Strings.tryAgain : Strings.startScanning,
            icon: Icons.bluetooth_searching_rounded,
            onPressed: _startScan,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  // ── Scanning / connecting: hero + live device list ───────────────────
  Widget _searchView() {
    final connecting = _state == BleConnectionState.connecting;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        _PulseHero(animation: _pulse, active: true, size: 150),
        const SizedBox(height: AppSpacing.md),
        Text(
          connecting ? Strings.connectingTo(_connectingName) : Strings.scanning,
          style: AppTheme.h2(),
        ),
        const SizedBox(height: AppSpacing.micro),
        Text(
          connecting ? Strings.holdTight : Strings.wearStrap,
          style: AppTheme.caption(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    Strings.lookingForSensors,
                    style: AppTheme.caption(color: AppColors.textTertiary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) {
                    final r = _results[i];
                    return _DeviceCard(
                      name: _nameOf(r),
                      rssi: r.rssi,
                      connecting:
                          _connectingId == r.device.remoteId.str,
                      onTap: connecting ? null : () => _connect(r),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg,
          ),
          child: BeatSecondaryButton(
            label: Strings.stop,
            icon: Icons.stop_rounded,
            onPressed: connecting ? null : _stopScan,
          ),
        ),
      ],
    );
  }

  // ── Connected: live HR card + actions ────────────────────────────────
  Widget _connectedView() {
    final battery = _ble.batteryLevel;
    final rssi = _ble.rssi;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.15),
                  blurRadius: AppElevation.lg,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    Strings.connectedCaps,
                    style: AppTheme.micro(color: AppColors.success)
                        .copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.4),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _ble.connectedDeviceName ?? Strings.heartRateSensor,
                  style: AppTheme.h2(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _bpm?.toString() ?? '––',
                      style: AppTheme.statNumber(
                        fontSize: 64, color: AppColors.brandRed,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text('bpm', style: AppTheme.caption()),
                  ],
                ),
                Text(
                  _bpm == null ? Strings.waitingFirstBeat : Strings.liveHrReady,
                  style: AppTheme.caption(),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (battery >= 0) ...[
                      _InfoPill(
                        icon: Icons.battery_5_bar_rounded,
                        label: '$battery%',
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    _InfoPill(
                      icon: Icons.network_cell_rounded,
                      label: rssi == 0
                          ? Strings.signalLabel
                          : rssi > -60
                              ? Strings.signalStrong
                              : rssi > -75
                                  ? Strings.signalGood
                                  : Strings.signalWeak,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: BeatSecondaryButton(
                  label: Strings.disconnect,
                  icon: Icons.bluetooth_disabled_rounded,
                  onPressed: () => _ble.disconnect(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: BeatPrimaryButton(
                  label: Strings.done,
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Radar-style hero: a bluetooth badge with rings that ripple outward
/// while scanning/connecting and sit still otherwise.
class _PulseHero extends StatelessWidget {
  final Animation<double> animation;
  final bool active;
  final double size;
  const _PulseHero({
    required this.animation,
    required this.active,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => CustomPaint(
          painter: _RingsPainter(t: animation.value, active: active),
          child: child,
        ),
        child: Center(
          child: Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandRed.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.brandRed.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              Icons.bluetooth_rounded,
              color: AppColors.brandRed,
              size: size * 0.16,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double t;
  final bool active;
  _RingsPainter({required this.t, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final inner = size.width * 0.20;
    final outer = size.width * 0.50;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (!active) {
      paint.color = AppColors.brandRed.withValues(alpha: 0.18);
      canvas.drawCircle(center, size.width * 0.32, paint);
      return;
    }
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = inner + (outer - inner) * phase;
      final eased = math.pow(1 - phase, 2).toDouble();
      paint.color = AppColors.brandRed.withValues(alpha: 0.4 * eased);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.t != t || old.active != active;
}

/// One discovered sensor in the scan list.
class _DeviceCard extends StatelessWidget {
  final String name;
  final int rssi;
  final bool connecting;
  final VoidCallback? onTap;
  const _DeviceCard({
    required this.name,
    required this.rssi,
    required this.connecting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.monitor_heart_rounded,
                  color: AppColors.brandRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTheme.bodyLarge(weight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(Strings.heartRateSensor, style: AppTheme.caption()),
                  ],
                ),
              ),
              _SignalBars(rssi: rssi),
              const SizedBox(width: AppSpacing.sm),
              if (connecting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.brandRed,
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int rssi;
  const _SignalBars({required this.rssi});

  @override
  Widget build(BuildContext context) {
    final strength = rssi > -60 ? 3 : rssi > -75 ? 2 : 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            width: 3,
            height: 6.0 + i * 4,
            decoration: BoxDecoration(
              color: i < strength ? AppColors.success : AppColors.border,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.caption(color: AppColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
