import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../services/auth_service.dart';
import '../services/session_repository.dart';
import '../services/session_store.dart';
import '../widgets/beat_button.dart';
import '../widgets/workout_type_sheet.dart';
import 'trainer_monitor_screen.dart';

/// "Start session" — name + type + optional interval timer setup.
class SessionHostScreen extends StatefulWidget {
  /// Production: the trainer's studio to host the cloud session in.
  /// Null (prototype/demo) keeps the local in-memory session.
  final String? studioId;
  const SessionHostScreen({super.key, this.studioId});

  @override
  State<SessionHostScreen> createState() => _SessionHostScreenState();
}

class _SessionHostScreenState extends State<SessionHostScreen> {
  final _name = TextEditingController(text: 'Friday HIIT 18:00');
  WorkoutType _type = WorkoutType.hiit;
  bool _intervals = true;
  int _workSec = 45;
  int _restSec = 15;
  int _rounds = 8;
  bool _launching = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _launch() async {
    final name =
        _name.text.trim().isEmpty ? Strings.untitledSession : _name.text.trim();
    final studioId = widget.studioId;
    final uid = AuthService.currentUid;

    if (studioId == null || uid == null) {
      // Demo: persist in the in-memory store so trainer home + recent
      // sessions update when we come back.
      SessionStore.instance.startLive(
        name: name,
        type: _type,
        workSec: _intervals ? _workSec : 0,
        restSec: _intervals ? _restSec : 0,
        rounds: _intervals ? _rounds : 1,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TrainerMonitorScreen()),
      );
      return;
    }

    setState(() => _launching = true);
    final w = _intervals ? _workSec : 0;
    final r = _intervals ? _restSec : 0;
    final rounds = _intervals ? _rounds : 1;
    final String sessionId;
    try {
      sessionId = await SessionRepository.start(
        studioId: studioId,
        trainerUid: uid,
        name: name,
        type: _type.name,
        workSec: w,
        restSec: r,
        rounds: rounds,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _launching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.couldNotStartSession)),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TrainerMonitorScreen(
          session: CloudSession(
            id: sessionId,
            studioId: studioId,
            trainerUid: uid,
            name: name,
            type: _type.name,
            status: 'live',
            startedAt: DateTime.now(),
            workSec: w,
            restSec: r,
            rounds: rounds,
          ),
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
        title: Text(Strings.startSessionTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
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
                  _label(Strings.sessionNameLabel),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Friday HIIT 18:00',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _label(Strings.typeLabel),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final t in WorkoutType.values)
                        _TypeChip(
                          label: Strings.workoutTypeLabel(t.displayName),
                          selected: _type == t,
                          onTap: () => setState(() => _type = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Intervals toggle
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(Strings.intervalTimer,
                                      style: AppTheme.bodyLarge(
                                          weight: FontWeight.w600)),
                                  Text(
                                    Strings.intervalTimerDesc,
                                    style: AppTheme.caption(),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _intervals,
                              onChanged: (v) => setState(() => _intervals = v),
                              activeThumbColor: AppColors.brandRed,
                            ),
                          ],
                        ),
                        if (_intervals) ...[
                          const SizedBox(height: AppSpacing.md),
                          Divider(color: AppColors.border),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _DurationStepper(
                                  label: Strings.work,
                                  unit: Strings.sec,
                                  value: _workSec,
                                  onChanged: (v) =>
                                      setState(() => _workSec = v),
                                  color: AppColors.brandRed,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: _DurationStepper(
                                  label: Strings.rest,
                                  unit: Strings.sec,
                                  value: _restSec,
                                  onChanged: (v) =>
                                      setState(() => _restSec = v),
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: _DurationStepper(
                                  label: Strings.rounds,
                                  unit: '',
                                  value: _rounds,
                                  onChanged: (v) =>
                                      setState(() => _rounds = v),
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.bgTertiary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            Strings.qrJoinHint,
                            style: AppTheme.caption(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: BeatPrimaryButton(
                label: Strings.launchSession,
                icon: Icons.play_arrow_rounded,
                loading: _launching,
                onPressed: _launch,
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
          style: AppTheme.micro(color: AppColors.textSecondary)
              .copyWith(letterSpacing: 1.4),
        ),
      );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandRed.withValues(alpha: 0.18)
                : AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.bodyLarge(
              color: selected ? AppColors.brandRed : AppColors.textPrimary,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
            ).copyWith(fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _DurationStepper extends StatelessWidget {
  final String label;
  final String unit;
  final int value;
  final ValueChanged<int> onChanged;
  final Color color;

  const _DurationStepper({
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: AppTheme.micro(color: color).copyWith(letterSpacing: 1.4)),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            _IconBtn(
              icon: Icons.remove_rounded,
              onTap: () {
                if (value > 1) onChanged(value - 1);
              },
            ),
            Expanded(
              // value + unit on one line ("45 sec"), scaled down if tight
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$value',
                      style: AppTheme.statNumber(fontSize: 22, color: color),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Text(unit, style: AppTheme.micro()),
                    ],
                  ],
                ),
              ),
            ),
            _IconBtn(
              icon: Icons.add_rounded,
              onTap: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.bgPrimary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}