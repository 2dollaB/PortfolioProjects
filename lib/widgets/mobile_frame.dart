import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Constrains content to a phone-app width on desktop browsers so the
/// mobile-first UI doesn't stretch absurdly. On phones / narrow viewports
/// it's a no-op passthrough.
///
/// Used on every screen EXCEPT the TV view and the trainer session control
/// panel, which are designed full-bleed for large displays.
class MobileFrame extends StatelessWidget {
  final Widget child;

  /// Width cap. iPhone 14 Pro Max is 430 logical px; 560 gives tablet
  /// portrait + small browsers a touch of breathing room while still
  /// preventing absurd stretch on full desktop monitors.
  final double maxWidth;

  /// Background colour shown in the side gutters on desktop.
  final Color gutterColor;

  const MobileFrame({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.gutterColor = AppColors.darkBgPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Container(
          color: gutterColor,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
