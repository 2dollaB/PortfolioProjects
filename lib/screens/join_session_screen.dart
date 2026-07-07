import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/session_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';
import '../widgets/qr_scan_screen.dart';
import 'session_lobby_screen.dart';
import 'workout_screen.dart';

/// Join a group session by its 6-digit code — entered manually or scanned from
/// the trainer's QR. Mirrors [JoinStudioScreen]: sessions are no longer
/// auto-joined by studio membership, so an athlete at home can't wander into a
/// live session; they must have this session's own code. The join is still
/// refused (client + rules) if they aren't a member of the session's studio.
class JoinSessionScreen extends StatefulWidget {
  /// Production: the signed-in athlete. Null keeps the prototype/demo scanner.
  final UserProfile? profile;
  const JoinSessionScreen({super.key, this.profile});

  @override
  State<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends State<JoinSessionScreen> {
  final _code = TextEditingController();
  final bool _scanning = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = Strings.sessionCodeError);
      return;
    }
    await _joinWithCode(code);
  }

  /// Opens the camera, extracts the 6-digit code from a scanned QR and joins.
  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScanScreen(title: Strings.joinSession),
      ),
    );
    if (raw == null || !mounted) return;
    final match = RegExp(r'\d{6}').firstMatch(raw);
    if (match == null) {
      setState(() => _error = Strings.sessionNoMatch);
      return;
    }
    final code = match.group(0)!;
    _code.text = code;
    await _joinWithCode(code);
  }

  /// Shared join path for both manual entry and QR scan.
  Future<void> _joinWithCode(String code) async {
    final uid = AuthService.currentUid;
    if (uid == null) {
      setState(() => _error = Strings.notSignedIn);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await SessionRepository.resolveByCode(code);
      if (session == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = Strings.sessionNoMatch;
        });
        return;
      }
      // Refuse anyone who isn't in this session's studio (rules also block the
      // session read + hr writes, so this is a friendly pre-check, not the gate).
      // The home CTA is hidden unless you're in a studio, so in practice this
      // only fires when you're in studio A and try a session from studio B.
      if (widget.profile?.studioId != session.studioId) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = widget.profile?.studioId == null
              ? Strings.joinStudioFirst
              : Strings.sessionOtherStudio;
        });
        return;
      }
      if (session.isKicked(uid)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = Strings.removedFromSession;
        });
        return;
      }
      if (!mounted) return;
      // Into the waiting room — the workout begins when the trainer hits Start.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionLobbyScreen(
            profile: widget.profile!,
            session: session,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = Strings.couldNotJoinSession(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prototype / not signed in — keep the demo scanner walkthrough.
    if (AuthService.currentUid == null || widget.profile == null) {
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                const Center(
                    child: LogoHeartbeat(size: 28, showWordmark: false)),
                const SizedBox(height: AppSpacing.xl),
                Text(Strings.enterSessionCode, style: AppTheme.h2()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Strings.sessionCodeSubtitle,
                  style: AppTheme.bodyLarge(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _code,
                  textAlign: TextAlign.center,
                  style: AppTheme.statNumber(fontSize: 28)
                      .copyWith(letterSpacing: 8),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onSubmitted: (_) => _join(),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: AppTheme.caption(color: AppColors.danger)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                BeatPrimaryButton(
                  label: Strings.joinSession,
                  icon: Icons.login_rounded,
                  loading: _loading,
                  onPressed: _join,
                ),
                const SizedBox(height: AppSpacing.sm),
                BeatSecondaryButton(
                  label: Strings.scanToJoin,
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: _loading ? null : _scan,
                ),
              ],
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
                  hintText: '••••••',
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
