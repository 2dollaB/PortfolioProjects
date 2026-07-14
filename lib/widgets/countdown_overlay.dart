import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../services/clock_sync.dart';

/// Full-screen synced 3-2-1 → GO shown to observers of a group session
/// (trainer monitor + TV board). Counts down to a shared [target] instant
/// (the session's `runningSince`) using [ClockSync.now] so every screen lands
/// on GO at the same real-world moment.
///
/// This is the passive version — it just displays. The athlete's own workout
/// screen has its own countdown that also gates when its clock starts.
class SyncedCountdownOverlay extends StatefulWidget {
  final DateTime target;

  /// Dim the board behind (TV/monitor) instead of painting fully opaque.
  final bool dim;
  const SyncedCountdownOverlay({
    super.key,
    required this.target,
    this.dim = true,
  });

  @override
  State<SyncedCountdownOverlay> createState() => _SyncedCountdownOverlayState();
}

class _SyncedCountdownOverlayState extends State<SyncedCountdownOverlay> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _recompute();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(_recompute);
    });
  }

  void _recompute() {
    final remaining = widget.target.difference(ClockSync.now());
    _seconds = remaining.isNegative
        ? 0
        : (remaining.inMilliseconds / 1000).ceil();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: widget.dim
            ? AppColors.bgPrimary.withValues(alpha: 0.94)
            : AppColors.bgPrimary,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Strings.getReady,
              style: AppTheme.h2().copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _seconds > 0 ? Strings.startingIn : '',
              style: AppTheme.caption(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                _seconds > 0 ? '$_seconds' : Strings.go,
                key: ValueKey(_seconds),
                style: AppTheme.statNumber(
                  fontSize: 120,
                  color: AppColors.brandRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
