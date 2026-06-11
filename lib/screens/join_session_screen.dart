import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../services/mock_data.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';
import 'workout_screen.dart';

/// Join a group session by scanning a QR or entering a 6-digit invite code.
/// Camera preview is mocked for the prototype â€” the design + flow is the focus.
class JoinSessionScreen extends StatefulWidget {
  const JoinSessionScreen({super.key});

  @override
  State<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends State<JoinSessionScreen> {
  final _code = TextEditingController();
  final bool _scanning = true;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      appBar: AppBar(
        title: const Text('Join session'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scan the QR code from your trainer',
                style: AppTheme.h2(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Hold your phone steady â€” we connect automatically.',
                style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _ScannerStage(active: _scanning)),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: AppColors.darkBorder.withValues(alpha: 0.6))),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text('OR ENTER CODE', style: AppTheme.micro()),
                  ),
                  Expanded(
                      child: Divider(
                          color: AppColors.darkBorder.withValues(alpha: 0.6))),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _code,
                textAlign: TextAlign.center,
                style: AppTheme.statNumber(fontSize: 28).copyWith(
                  letterSpacing: 8,
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: 'â€¢â€¢â€¢â€¢â€¢â€¢',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              BeatPrimaryButton(
                label: 'Join session',
                icon: Icons.login_rounded,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => WorkoutScreen(
                      profile: MockData.athleteProfile,
                      inGroupSession: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _ScannerStage extends StatelessWidget {
  final bool active;
  const _ScannerStage({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Placeholder QR target
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.brandRed.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: CustomPaint(painter: _CornerBracketsPainter()),
            ),
          ),
          // Brand watermark
          Positioned(
            top: AppSpacing.md,
            child: Opacity(
              opacity: 0.7,
              child: const LogoHeartbeat(size: 22, showWordmark: false),
            ),
          ),
          if (active)
            Positioned(
              bottom: AppSpacing.lg,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Scanningâ€¦',
                    style: AppTheme.caption(color: AppColors.success),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brandRed
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 24.0;
    // Top-left
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - len, size.height),
        Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - len),
        Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}