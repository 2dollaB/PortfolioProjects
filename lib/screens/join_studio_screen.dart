import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/studio_repository.dart';
import '../services/user_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';
import '../widgets/mobile_frame.dart';

/// Athlete joins a studio with the 6-digit invite code from their trainer.
/// Production-only: resolves the code, self-joins the studio, sets studioId.
/// The users/{uid} snapshot stream then refreshes home (the CTA disappears).
class JoinStudioScreen extends StatefulWidget {
  const JoinStudioScreen({super.key});

  @override
  State<JoinStudioScreen> createState() => _JoinStudioScreenState();
}

class _JoinStudioScreenState extends State<JoinStudioScreen> {
  final _code = TextEditingController();
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
      setState(() => _error = 'Enter the 6-digit code from your trainer.');
      return;
    }
    final uid = AuthService.currentUid;
    if (uid == null) {
      setState(() => _error = 'You are not signed in.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final studioId = await StudioRepository.resolveStudioId(code);
      if (studioId == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = "That code didn't match a studio.";
        });
        return;
      }
      await StudioRepository.join(uid: uid, studioId: studioId);
      await UserRepository.setStudioId(uid, studioId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You joined the studio!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not join: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: const Text('Join a studio'),
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
                const Center(child: LogoHeartbeat(size: 28, showWordmark: false)),
                const SizedBox(height: AppSpacing.xl),
                Text('Enter your studio code', style: AppTheme.h2()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Your trainer shares a 6-digit code to join their studio.",
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
                  label: 'Join studio',
                  icon: Icons.login_rounded,
                  loading: _loading,
                  onPressed: _join,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
