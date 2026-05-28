import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../widgets/beat_button.dart';
import 'trainer_monitor_screen.dart';

/// "Start session" — name + type + optional interval timer setup.
class SessionHostScreen extends StatefulWidget {
  const SessionHostScreen({super.key});

  @override
  State<SessionHostScreen> createState() => _SessionHostScreenState();
}

class _SessionHostScreenState extends State<SessionHostScreen> {
  final _name = TextEditingController(text: 'Friday HIIT 18:00');
  String _type = 'HIIT';
  bool _intervals = true;
  int _workSec = 45;
  int _restSec = 15;
  int _rounds = 8;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      appBar: AppBar(
        title: const Text('Start session'),
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
                  _label('Session name'),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Friday HIIT 18:00',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _label('Type'),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final t in const ['HIIT', 'Strength', 'Cardio', 'CrossFit', 'Custom'])
                        _TypeChip(
                          label: t,
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
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Interval timer',
                                      style: AppTheme.bodyLarge(
                                          weight: FontWeight.w600)),
                                  Text(
                                    'Auto work/rest cycles with countdown.',
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
                          const Divider(color: AppColors.darkBorder),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _DurationStepper(
                                  label: 'Work',
                                  unit: 'sec',
                                  value: _workSec,
                                  onChanged: (v) =>
                                      setState(() => _workSec = v),
                                  color: AppColors.brandRed,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: _DurationStepper(
                                  label: 'Rest',
                                  unit: 'sec',
                                  value: _restSec,
                                  onChanged: (v) =>
                                      setState(() => _restSec = v),
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: _DurationStepper(
                                  label: 'Rounds',
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
                      color: AppColors.darkBgTertiary,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.darkTextSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            "Athletes will scan a QR code to join once you launch the session.",
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
                label: 'Launch session',
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const TrainerMonitorScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          t.toUpperCase(),
          style: AppTheme.micro(color: AppColors.darkTextSecondary)
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
                : AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.darkBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.bodyLarge(
              color: selected ? AppColors.brandRed : AppColors.darkTextPrimary,
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
              child: Column(
                children: [
                  Text(
                    '$value',
                    style: AppTheme.statNumber(fontSize: 22, color: color),
                  ),
                  if (unit.isNotEmpty)
                    Text(unit, style: AppTheme.micro()),
                ],
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
            color: AppColors.darkBgPrimary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Icon(icon, size: 16, color: AppColors.darkTextPrimary),
        ),
      ),
    );
  }
}
