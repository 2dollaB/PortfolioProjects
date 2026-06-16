import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/session_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';
import 'session_lobby_screen.dart';
import 'workout_screen.dart';

/// Join a group session.
///
/// Production: studio members don't need a code — the screen watches the
/// studio's live session and joins it in one tap. Demo keeps the mock QR
/// scanner flow.
class JoinSessionScreen extends StatefulWidget {
  /// Production: the signed-in athlete (their studioId locates the session).
  /// Null keeps the prototype/demo scanner.
  final UserProfile? profile;
  const JoinSessionScreen({super.key, this.profile});

  @override
  State<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends State<JoinSessionScreen> {
  final _code = TextEditingController();
  final bool _scanning = true;

  Stream<CloudSession?>? _liveStream;

  @override
  void initState() {
    super.initState();
    final studioId = widget.profile?.studioId;
    if (AuthService.currentUid != null && studioId != null) {
      _liveStream = SessionRepository.watchLive(studioId);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _join(CloudSession live) {
    final uid = AuthService.currentUid;
    if (uid != null && live.isKicked(uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.removedFromSession)),
      );
      return;
    }
    // Into the waiting room — the workout begins when the trainer hits Start.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionLobbyScreen(
          profile: widget.profile!,
          session: live,
        ),
      ),
    );
  }

  String _stateLabel(CloudSession live) {
    if (!live.isRunning) return Strings.waitingToStart;
    final m = DateTime.now().difference(live.workoutStartedAt ?? live.startedAt).inMinutes;
    if (m < 1) return Strings.justStarted;
    return Strings.startedMinAgo(m);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _liveStream;
    if (stream == null && AuthService.currentUid == null) {
      return _buildDemo(context);
    }

    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text(Strings.joinSession),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            // Signed in but not in a studio yet — sessions live inside one.
            child: stream == null
                ? Center(
                    child: Text(
                      Strings.joinStudioFirst,
                      style: AppTheme.caption(),
                      textAlign: TextAlign.center,
                    ),
                  )
                : StreamBuilder<CloudSession?>(
                    stream: stream,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final live = snap.data;
                      if (live == null) return const _NoLiveSession();
                      return _LiveSessionCard(
                        session: live,
                        startedLabel: _stateLabel(live),
                        onJoin: () => _join(live),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemo(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(Strings.joinSession),
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
                Strings.scanQrTitle,
                style: AppTheme.h2(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Strings.holdSteady,
                style: AppTheme.bodyLarge(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: _ScannerStage(active: _scanning)),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: AppColors.border.withValues(alpha: 0.6))),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text(Strings.orEnterCode, style: AppTheme.micro()),
                  ),
                  Expanded(
                      child: Divider(
                          color: AppColors.border.withValues(alpha: 0.6))),
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
                label: Strings.joinSession,
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

/// Production: no live session right now — the stream flips this view to the
/// join card the moment the trainer launches one.
class _NoLiveSession extends StatelessWidget {
  const _NoLiveSession();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.podcasts_rounded,
              color: AppColors.textSecondary,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(Strings.noLiveSession, style: AppTheme.h2()),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Strings.noLiveSessionHint,
            style: AppTheme.caption(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Production: the studio's live session, one tap to join.
class _LiveSessionCard extends StatelessWidget {
  final CloudSession session;
  final String startedLabel;
  final VoidCallback onJoin;
  const _LiveSessionCard({
    required this.session,
    required this.startedLabel,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandRed.withValues(alpha: 0.12),
              blurRadius: 32,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.brandRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  Strings.liveNow,
                  style: AppTheme.micro(color: AppColors.brandRed).copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(session.name, style: AppTheme.h1().copyWith(fontSize: 26)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${Strings.workoutTypeLabel(session.typeLabel)} · $startedLabel',
              style: AppTheme.bodyLarge(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            BeatPrimaryButton(
              label: Strings.joinSession,
              icon: Icons.login_rounded,
              onPressed: onJoin,
            ),
          ],
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
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
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
                    Strings.scanning,
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