import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/strings.dart';
import '../config/theme.dart';

/// Small tappable info icon that opens a dialog explaining how a displayed
/// number is calculated (zones, TRIMP, calories, HR max…). Same pattern as
/// HrMaxInfoButton, parametrized with title + body.
class CalcInfoButton extends StatelessWidget {
  final String title;
  final String body;
  final double size;

  const CalcInfoButton({
    super.key,
    required this.title,
    required this.body,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Text(body, style: AppTheme.bodyLarge()),
          ),
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
