import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';

/// Top header used on both athlete + trainer home screens.
///
/// Two-line greeting on the left, large tappable avatar on the right.
/// The avatar leads to settings/profile.
class HomeHeader extends StatelessWidget {
  /// e.g. "Good morning"
  final String greeting;

  /// First name shown big underneath the greeting.
  final String name;

  /// Optional small line under the name (e.g. studio name for trainer).
  final String? subtitle;

  /// Initials shown inside the avatar circle.
  final String initials;

  /// Tap on the avatar — typically opens settings/profile.
  final VoidCallback onAvatarTap;

  const HomeHeader({
    super.key,
    required this.greeting,
    required this.name,
    required this.initials,
    required this.onAvatarTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppTheme.caption().copyWith(
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: AppTheme.h1().copyWith(
                  fontSize: 32,
                  height: 1.05,
                  letterSpacing: -0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.micro),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      subtitle!,
                      style: AppTheme.caption(color: AppColors.darkTextPrimary)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _AvatarButton(initials: initials, onTap: onAvatarTap),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final String initials;
  final VoidCallback onTap;

  const _AvatarButton({required this.initials, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.brandRed.withValues(alpha: 0.18),
            border: Border.all(
              color: AppColors.brandRed.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandRed.withValues(alpha: 0.18),
                blurRadius: 16,
                spreadRadius: -4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: AppTheme.h2(color: AppColors.brandRed).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
