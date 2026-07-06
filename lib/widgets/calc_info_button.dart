import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';

/// One page of an explainer sheet: a short title, an optional formula block,
/// and body copy. Kept design-system friendly (theme styles only).
class InfoStep {
  final String title;
  final String? formula;
  final String body;
  const InfoStep({required this.title, this.formula, required this.body});
}

/// Opens the themed, swipeable [_InfoSheet]. Reusable so both the info icon
/// and other tappable surfaces (e.g. the HR-max stat card) share one look.
void showInfoSheet(BuildContext context, String title, List<InfoStep> steps) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _InfoSheet(title: title, steps: steps),
  );
}

/// Small tappable info icon that opens a stepped explainer of how a displayed
/// number is calculated (zones, TRIMP, calories, HR max…).
class CalcInfoButton extends StatelessWidget {
  final String title;
  final List<InfoStep> steps;
  final double size;

  const CalcInfoButton({
    super.key,
    required this.title,
    required this.steps,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => showInfoSheet(context, title, steps),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.info_outline_rounded,
            size: size, color: AppColors.textSecondary),
      ),
    );
  }
}

class _InfoSheet extends StatefulWidget {
  final String title;
  final List<InfoStep> steps;
  const _InfoSheet({required this.title, required this.steps});

  @override
  State<_InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<_InfoSheet> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == widget.steps.length - 1;

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.steps.length > 1;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.sm, 0),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: AppTheme.h2())),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: widget.steps.length,
                itemBuilder: (_, i) => _StepView(step: widget.steps[i]),
              ),
            ),
            // Dots
            if (multi)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.steps.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? AppColors.brandRed : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              child: Row(
                children: [
                  if (multi && _page > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      child: Text(Strings.pick('Back', 'Natrag')),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      _isLast
                          ? Strings.done
                          : Strings.pick('Next', 'Dalje'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  final InfoStep step;
  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.title,
              style: AppTheme.bodyLarge(weight: FontWeight.w600)),
          if (step.formula != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bgTertiary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border(
                  left: BorderSide(color: AppColors.brandRed, width: 3),
                  top: BorderSide(color: AppColors.border),
                  right: BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Text(step.formula!,
                  style: AppTheme.mono(fontSize: 14, letterSpacing: 0.3)),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(step.body,
              textAlign: TextAlign.justify,
              style: AppTheme.bodyLarge(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
