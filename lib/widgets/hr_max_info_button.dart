import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/strings.dart';
import '../config/theme.dart';

/// Small tappable info icon explaining the Tanaka/Gulati HR-max estimate.
/// Placed wherever an age-derived HR max is shown.
class HrMaxInfoButton extends StatelessWidget {
  final double size;
  const HrMaxInfoButton({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(Strings.hrMaxInfoTitle),
          content: Text(Strings.hrMaxInfoBody, style: AppTheme.bodyLarge()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(Strings.done),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.info_outline_rounded,
            size: size, color: AppColors.textSecondary),
      ),
    );
  }
}
