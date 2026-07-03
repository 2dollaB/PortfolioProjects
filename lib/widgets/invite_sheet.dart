import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import 'beat_button.dart';

/// Bottom-sheet that displays the studio invite QR code + 6-digit code.
/// Used by trainer session control + TV view.
class InviteSheet extends StatelessWidget {
  final String code;
  const InviteSheet({super.key, this.code = '479321'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Strings.athletesJoinCode,
            style: AppTheme.h2(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 160,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // scaleDown keeps the spaced digits on one line on narrow phones
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      code.split('').join(' '),
                      maxLines: 1,
                      style: AppTheme.statNumber(
                        fontSize: 32,
                        color: AppColors.bgPrimary,
                      ).copyWith(letterSpacing: 6, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BeatPrimaryButton(
            label: Strings.done,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  static void show(BuildContext context, {String code = '479321'}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => InviteSheet(code: code),
    );
  }
}
