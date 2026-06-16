import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../widgets/mobile_frame.dart';

/// One heading + body block in a legal document.
typedef LegalSection = ({String heading, String body});

/// Simple scrollable reader for a legal document (Privacy Policy / Terms).
/// Content is drafted below via the [LegalDocScreen.privacy] / [.terms]
/// constructors — plain copy suitable for a group-fitness HR app.
class LegalDocScreen extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final String intro;
  final List<LegalSection> sections;

  const LegalDocScreen({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
            ),
            children: [
              Text(title, style: AppTheme.h1()),
              const SizedBox(height: AppSpacing.xs),
              Text('Last updated $lastUpdated', style: AppTheme.caption()),
              const SizedBox(height: AppSpacing.md),
              Text(
                intro,
                style: AppTheme.bodyLarge(color: AppColors.textSecondary),
              ),
              for (final s in sections) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(s.heading, style: AppTheme.h2()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.body,
                  style: AppTheme.bodyLarge(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Questions? Contact us at privacy@beatsync.app.',
                style: AppTheme.caption(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Privacy Policy for BeatSync.
  factory LegalDocScreen.privacy() {
    return const LegalDocScreen(
      title: 'Privacy Policy',
      lastUpdated: 'June 16, 2026',
      intro:
          'BeatSync helps you and your fitness studio track heart rate during '
          'group workouts. This policy explains what we collect, why, and how '
          'it is used. We collect only what the app needs to work.',
      sections: [
        (
          heading: 'What we collect',
          body:
              'Account details (your email and the name you enter); your '
              'profile (age, sex, height, weight, resting heart rate and '
              'fitness level, used to estimate your heart-rate zones); your '
              'workout summaries (duration, average and max heart rate, time '
              'in each zone, training load); the studio you belong to; and, '
              'when you pair one, the name of your heart-rate strap. We do not '
              'collect precise location or payment information.',
        ),
        (
          heading: 'How it is stored',
          body:
              'Your data is stored in Google Firebase (Firestore and Firebase '
              'Authentication) on our project beatsync-prod. Access is '
              'restricted by security rules so that, in general, only you can '
              'read and write your own profile and workouts.',
        ),
        (
          heading: 'Who can see it',
          body:
              'When you join a studio, the trainer who owns that studio can '
              'see your profile and workout summaries so they can coach you '
              'and run live sessions. Other athletes can see your name and '
              'live heart rate on the session board during a workout. If you '
              'leave the studio, the trainer loses this access for future '
              'sessions. We never sell your data or share it with advertisers.',
        ),
        (
          heading: 'Not medical advice',
          body:
              'BeatSync is a fitness tool, not a medical device. Heart-rate '
              'readings and zones are estimates and may be inaccurate. Do not '
              'rely on the app for medical decisions. Consult a doctor before '
              'starting any exercise program, especially if you have a heart '
              'condition.',
        ),
        (
          heading: 'Deleting your data',
          body:
              'You can leave a studio at any time from Settings → My studio. '
              'To delete your account and associated data, contact us at '
              'privacy@beatsync.app and we will remove your profile and '
              'workouts.',
        ),
      ],
    );
  }

  /// Terms of Service for BeatSync.
  factory LegalDocScreen.terms() {
    return const LegalDocScreen(
      title: 'Terms of Service',
      lastUpdated: 'June 16, 2026',
      intro:
          'These terms govern your use of BeatSync. By creating an account or '
          'using the app, you agree to them.',
      sections: [
        (
          heading: 'Eligibility',
          body:
              'You must be at least 16 years old (or have a guardian’s '
              'consent) and physically able to take part in exercise to use '
              'BeatSync.',
        ),
        (
          heading: 'Your account',
          body:
              'You are responsible for keeping your login details secure and '
              'for activity under your account. Keep your profile information '
              'accurate so heart-rate estimates are meaningful.',
        ),
        (
          heading: 'Acceptable use',
          body:
              'Use BeatSync only for its intended purpose. Do not attempt to '
              'access other users’ data, disrupt the service, or misuse '
              'studio invite codes.',
        ),
        (
          heading: 'Health disclaimer',
          body:
              'Heart-rate data and training metrics are informational only and '
              'are not medical advice. Exercise carries inherent risks; you '
              'take part at your own risk and should stop and seek help if you '
              'feel unwell.',
        ),
        (
          heading: 'Service provided as-is',
          body:
              'BeatSync is provided “as is” without warranties of '
              'any kind. We do not guarantee the app will be uninterrupted, '
              'error-free, or that readings will be accurate.',
        ),
        (
          heading: 'Termination & changes',
          body:
              'You may stop using BeatSync and request deletion at any time. '
              'We may update these terms as the app evolves; continued use '
              'after an update means you accept the revised terms.',
        ),
      ],
    );
  }
}
