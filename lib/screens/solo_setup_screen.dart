import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/ble_hr_service.dart';
import '../widgets/beat_button.dart';
import '../widgets/interval_config.dart';
import '../widgets/mobile_frame.dart';
import 'device_pairing_screen.dart';
import 'workout_screen.dart';

/// Solo-workout setup — the step between "Start workout" and the workout
/// itself. Connect an HR strap (optional), optionally set an interval timer,
/// then press Start. Nothing runs until Start is pressed, so backing out here
/// simply cancels (no stray workout starting on its own).
class SoloSetupScreen extends StatefulWidget {
  final UserProfile profile;
  const SoloSetupScreen({super.key, required this.profile});

  @override
  State<SoloSetupScreen> createState() => _SoloSetupScreenState();
}

class _SoloSetupScreenState extends State<SoloSetupScreen> {
  bool _intervals = false;
  int _workSec = 45;
  int _restSec = 15;
  int _rounds = 8;

  bool get _strapConnected => !kIsWeb && BleHrService.instance.isConnected;

  Future<void> _openPairing() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DevicePairingScreen()));
    if (mounted) setState(() {}); // refresh connected status on return
  }

  void _start() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkoutScreen(
          profile: widget.profile,
          workSec: _intervals ? _workSec : 0,
          restSec: _intervals ? _restSec : 0,
          rounds: _intervals ? _rounds : 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text(Strings.startWorkout),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    _label(Strings.heartRateSensor),
                    _StrapRow(
                      connected: _strapConnected,
                      name: _strapConnected
                          ? (BleHrService.instance.connectedDeviceName ??
                                Strings.heartRateSensor)
                          : null,
                      onTap: _openPairing,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    IntervalConfig(
                      enabled: _intervals,
                      workSec: _workSec,
                      restSec: _restSec,
                      rounds: _rounds,
                      onEnabledChanged: (v) => setState(() => _intervals = v),
                      onWorkChanged: (v) => setState(() => _workSec = v),
                      onRestChanged: (v) => setState(() => _restSec = v),
                      onRoundsChanged: (v) => setState(() => _rounds = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: BeatPrimaryButton(
                  label: Strings.startWorkout,
                  icon: Icons.play_arrow_rounded,
                  onPressed: _start,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(
      t.toUpperCase(),
      style: AppTheme.micro(
        color: AppColors.textSecondary,
      ).copyWith(letterSpacing: 1.4),
    ),
  );
}

/// Strap connect row — shows "Connect" when idle, the device name + a green
/// dot when a strap is paired. Tapping opens the pairing screen either way.
class _StrapRow extends StatelessWidget {
  final bool connected;
  final String? name;
  final VoidCallback onTap;
  const _StrapRow({
    required this.connected,
    required this.name,
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
            border: Border.all(
              color: connected
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (connected ? AppColors.success : AppColors.brandRed)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  connected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.monitor_heart_rounded,
                  color: connected ? AppColors.success : AppColors.brandRed,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? (name ?? Strings.heartRateSensor)
                          : Strings.connectStrap,
                      style: AppTheme.bodyLarge(weight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? Strings.strapConnected
                          : Strings.strapOptional,
                      style: AppTheme.caption(
                        color: connected
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
