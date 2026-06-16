import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../widgets/mobile_frame.dart';

/// Placeholder for the unbuilt subscription/billing feature.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: const Text('Subscription')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandRed.withValues(alpha: 0.15),
                      border: Border.all(
                        color: AppColors.brandRed.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: AppColors.brandRed,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Subscriptions — coming soon',
                    style: AppTheme.h2(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "Paid plans aren't available yet. You're on the free plan — "
                    'everything in BeatSync is unlocked while we build this out.',
                    style: AppTheme.bodyLarge(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
