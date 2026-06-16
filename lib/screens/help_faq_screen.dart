import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../widgets/mobile_frame.dart';

/// Static help / frequently-asked-questions for athletes and trainers.
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  static const List<({String q, String a})> _faqs = [
    (
      q: 'How do I join a studio?',
      a: 'Ask your trainer for their 6-digit invite code, then open '
          'Settings → My studio (or the “Join a studio” button on Home) and '
          'enter the code. You can belong to one studio at a time.',
    ),
    (
      q: 'How do I leave or switch studios?',
      a: 'Go to Settings → My studio and tap “Leave studio”. Once you’ve left, '
          'you can join a different studio with its invite code.',
    ),
    (
      q: 'Which heart-rate straps work?',
      a: 'Any standard Bluetooth heart-rate strap or watch that broadcasts '
          'heart rate — Polar, Garmin, Coros, Wahoo and similar. Pair it from '
          'Settings → Connected devices, then start a workout. (Apple Watch '
          'cannot broadcast heart rate to other apps.)',
    ),
    (
      q: 'What do the heart-rate zones mean?',
      a: 'Zones are a percentage of your maximum heart rate, from Warmup '
          '(easy) to VO2 Max (all-out). They’re estimated from your age, sex '
          'and profile — keep those up to date in Personal info for the best '
          'accuracy.',
    ),
    (
      q: 'How does a live session work?',
      a: 'Your trainer starts a session and you join from Home. During the '
          'session your heart rate appears on the studio board in real time. '
          'When it ends, your workout is saved to your history.',
    ),
    (
      q: 'How is my data handled?',
      a: 'Your profile and workouts are stored securely and shared only with '
          'your studio’s trainer. See the Privacy Policy in Settings → Support '
          'for the full details.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: const Text('Help & FAQ')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
            ),
            children: [
              for (final f in _faqs)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Theme(
                    // Drop the default ExpansionTile dividers for a clean card.
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
                      ),
                      iconColor: AppColors.brandRed,
                      collapsedIconColor: AppColors.textSecondary,
                      title: Text(f.q, style: AppTheme.bodyLarge(weight: FontWeight.w600)),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            f.a,
                            style: AppTheme.bodyLarge(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
