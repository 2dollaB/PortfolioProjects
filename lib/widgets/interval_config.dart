import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';

/// Interval-timer setup card — a toggle plus stacked Work / Rest / Rounds
/// steppers (each with - / + and a typable field). Shared by the trainer's
/// session host and the solo-workout setup. The parent owns the values.
class IntervalConfig extends StatelessWidget {
  final bool enabled;
  final int workSec;
  final int restSec;
  final int rounds;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onWorkChanged;
  final ValueChanged<int> onRestChanged;
  final ValueChanged<int> onRoundsChanged;

  const IntervalConfig({
    super.key,
    required this.enabled,
    required this.workSec,
    required this.restSec,
    required this.rounds,
    required this.onEnabledChanged,
    required this.onWorkChanged,
    required this.onRestChanged,
    required this.onRoundsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    Text(
                      Strings.intervalTimer,
                      style: AppTheme.bodyLarge(weight: FontWeight.w600),
                    ),
                    Text(Strings.intervalTimerDesc, style: AppTheme.caption()),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onEnabledChanged,
                activeThumbColor: AppColors.brandRed,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),
            _DurationStepper(
              label: Strings.work,
              unit: Strings.sec,
              value: workSec,
              onChanged: onWorkChanged,
              color: AppColors.brandRed,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DurationStepper(
              label: Strings.rest,
              unit: Strings.sec,
              value: restSec,
              onChanged: onRestChanged,
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.sm),
            _DurationStepper(
              label: Strings.rounds,
              unit: Strings.setsUnit,
              value: rounds,
              onChanged: onRoundsChanged,
              color: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _DurationStepper extends StatefulWidget {
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
  State<_DurationStepper> createState() => _DurationStepperState();
}

class _DurationStepperState extends State<_DurationStepper> {
  late final TextEditingController _ctrl = TextEditingController(
    text: '${widget.value}',
  );
  final _focus = FocusNode();

  @override
  void didUpdateWidget(_DurationStepper old) {
    super.didUpdateWidget(old);
    // Keep the field in sync when +/- change the value from outside, but not
    // while the user is mid-edit (typing) — that would fight their cursor.
    if (widget.value != old.value &&
        !_focus.hasFocus &&
        _ctrl.text != '${widget.value}') {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commitField(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    widget.onChanged(parsed.clamp(1, 999));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.label.toUpperCase(),
            style: AppTheme.micro(
              color: widget.color,
            ).copyWith(letterSpacing: 1.4),
          ),
        ),
        _IconBtn(
          icon: Icons.remove_rounded,
          onTap: () {
            if (widget.value > 1) widget.onChanged(widget.value - 1);
          },
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 56,
          height: 40,
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: AppTheme.statNumber(fontSize: 20, color: widget.color),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: widget.color),
              ),
            ),
            onChanged: _commitField,
            onSubmitted: (v) {
              _commitField(v);
              _ctrl.text = '${widget.value}';
            },
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _IconBtn(
          icon: Icons.add_rounded,
          onTap: () => widget.onChanged(widget.value + 1),
        ),
        // Always reserve the unit column (even empty, e.g. Rounds) so the
        // - / field / + controls line up across all three rows.
        const SizedBox(width: AppSpacing.xs),
        SizedBox(width: 26, child: Text(widget.unit, style: AppTheme.micro())),
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
