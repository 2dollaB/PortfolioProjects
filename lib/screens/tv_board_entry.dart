import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/tv_pairing_repository.dart';
import 'tv_host_screen.dart';

/// Web TV board entry (opened at `…/#/tv`).
///
/// Signs in anonymously, publishes a short pairing code, and shows it big on
/// the wall. When the trainer enters that code on their phone, the pairing
/// doc gains a studioId and this screen swaps to the live [TvHostScreen] —
/// which then follows the session (lobby → countdown → workout) on its own.
class TvBoardEntry extends StatefulWidget {
  const TvBoardEntry({super.key});

  @override
  State<TvBoardEntry> createState() => _TvBoardEntryState();
}

class _TvBoardEntryState extends State<TvBoardEntry> {
  String? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    var uid = AuthService.currentUid;
    uid ??= await AuthService.signInAnonymously();
    if (uid == null) {
      if (mounted) setState(() => _error = Strings.tvSignInFailed);
      return;
    }
    try {
      final code = await TvPairingRepository.createForTv(uid);
      if (mounted) setState(() => _code = code);
    } catch (_) {
      if (mounted) setState(() => _error = Strings.tvCodeFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _Splash(child: _message(_error!, retry: true));
    }
    final code = _code;
    if (code == null) {
      return const _Splash(child: CircularProgressIndicator());
    }
    return StreamBuilder<TvPairing?>(
      stream: TvPairingRepository.watch(code),
      builder: (context, snap) {
        final pairing = snap.data;
        if (pairing != null && pairing.isPaired) {
          // Linked — hand over to the live board (no close on the TV root).
          return TvHostScreen(studioId: pairing.studioId, showClose: false);
        }
        return _Splash(child: _codeView(code));
      },
    );
  }

  Widget _codeView(String code) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Strings.tvConnectTitle,
          style: AppTheme.h1().copyWith(fontSize: 40),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          Strings.tvConnectSubtitle,
          style: AppTheme.bodyLarge(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: AppColors.brandRed.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            code.split('').join(' '),
            style: AppTheme.statNumber(
              fontSize: 88,
              color: AppColors.brandRed,
            ).copyWith(letterSpacing: 12),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              Strings.tvWaitingForPhone,
              style: AppTheme.caption(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _message(String text, {bool retry = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.tv_off_rounded, size: 48, color: AppColors.textTertiary),
        const SizedBox(height: AppSpacing.md),
        Text(
          text,
          style: AppTheme.bodyLarge(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        if (retry) ...[
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: () {
              setState(() {
                _error = null;
                _code = null;
              });
              _prepare();
            },
            child: Text(Strings.retry),
          ),
        ],
      ],
    );
  }
}

class _Splash extends StatelessWidget {
  final Widget child;
  const _Splash({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: child,
        ),
      ),
    );
  }
}
