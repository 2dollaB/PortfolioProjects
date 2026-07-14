import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/strings.dart';
import 'calc_info_button.dart';

/// Small tappable info icon explaining the Tanaka/Gulati HR-max estimate.
/// Opens the same themed stepped sheet the workout-summary tooltips use, so
/// the explanation reads consistently wherever an age-derived HR max shows.
class HrMaxInfoButton extends StatelessWidget {
  final double size;
  const HrMaxInfoButton({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => showInfoSheet(context, Strings.hrMaxInfoTitle, [
        InfoStep(title: Strings.hrMaxStep1Title, body: Strings.hrMaxStep1Body),
        InfoStep(
          title: Strings.hrMaxStep2Title,
          formula: Strings.calcHrMaxFormula,
          body: Strings.hrMaxStep2Body,
        ),
        InfoStep(title: Strings.hrMaxStep3Title, body: Strings.hrMaxStep3Body),
      ]),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.info_outline_rounded,
          size: size,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
