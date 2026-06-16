import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';

/// "I'm an Athlete" vs "I'm a Trainer" card-pair selector.
class RoleSelectScreen extends StatefulWidget {
  final void Function(UserRole role) onSelected;

  const RoleSelectScreen({super.key, required this.onSelected});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  UserRole? _selected;

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const LogoHeartbeat(size: 28, showWordmark: true),
              const SizedBox(height: AppSpacing.xxl),
              Text(Strings.pickYourRole, style: AppTheme.h1()),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Strings.roleTailor,
                style: AppTheme.bodyLarge(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              _RoleCard(
                icon: Icons.directions_run_rounded,
                title: Strings.imAthlete,
                desc: Strings.athleteCardDesc,
                selected: _selected == UserRole.athlete,
                onTap: () => setState(() => _selected = UserRole.athlete),
              ),
              const SizedBox(height: AppSpacing.md),
              _RoleCard(
                icon: Icons.groups_2_rounded,
                title: Strings.imTrainer,
                desc: Strings.trainerCardDesc,
                selected: _selected == UserRole.trainer,
                onTap: () => setState(() => _selected = UserRole.trainer),
              ),
              const Spacer(),
              BeatPrimaryButton(
                label: Strings.continueLabel,
                icon: Icons.arrow_forward_rounded,
                onPressed: _selected == null
                    ? null
                    : () => widget.onSelected(_selected!),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.brandRed.withValues(alpha: 0.18),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: (selected ? AppColors.brandRed : AppColors.bgTertiary)
                      .withValues(alpha: selected ? 0.18 : 1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  color:
                      selected ? AppColors.brandRed : AppColors.textSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.h2()),
                    const SizedBox(height: 2),
                    Text(desc, style: AppTheme.caption()),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.brandRed : AppColors.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}