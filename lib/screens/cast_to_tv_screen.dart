import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../main.dart' show kWebAppUrl;
import '../services/tv_pairing_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/mobile_frame.dart';
import 'tv_host_screen.dart';

/// Trainer's "Connect to TV" tab.
///
/// The TV board lives on the web app. The trainer opens [kWebAppUrl]/#/tv on
/// any TV browser once; it shows a 4-digit code. Entering that code here links
/// the TV to this studio — from then on the board follows the live session
/// (joins, synced countdown, workout) on its own, with no further TV input.
class CastToTvScreen extends StatefulWidget {
  final String? studioId;
  const CastToTvScreen({super.key, this.studioId});

  @override
  State<CastToTvScreen> createState() => _CastToTvScreenState();
}

class _CastToTvScreenState extends State<CastToTvScreen> {
  final _codeCtrl = TextEditingController();
  bool _connecting = false;
  bool _connected = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final code = _codeCtrl.text.trim();
    final studioId = widget.studioId;
    if (code.length != 4) {
      setState(() => _error = Strings.tvCodeError);
      return;
    }
    if (studioId == null) {
      // Demo / no studio — nothing to link. Just preview.
      setState(() => _error = Strings.tvNoStudio);
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    final reason = await TvPairingRepository.pair(
      code: code,
      studioId: studioId,
    );
    if (!mounted) return;
    setState(() {
      _connecting = false;
      if (reason == null) {
        _connected = true;
      } else {
        _error = reason == 'noCode'
            ? Strings.tvCodeNoMatch
            : Strings.tvPairFailed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: Text(Strings.connectToTv)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _connected ? _connectedView() : _pairView(),
          ),
        ),
      ),
    );
  }

  Widget _pairView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          Strings.connectToTvTitle,
          style: AppTheme.h1().copyWith(fontSize: 26),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          Strings.connectToTvSubtitle,
          style: AppTheme.bodyLarge(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Step(n: 1, text: Strings.tvPhoneStep1),
        // The URL to open on the TV.
        Padding(
          padding: const EdgeInsets.only(left: 32, bottom: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '${kWebAppUrl.replaceFirst('https://', '')}/#/tv',
              style: AppTheme.mono(color: AppColors.textPrimary),
            ),
          ),
        ),
        _Step(n: 2, text: Strings.tvPhoneStep2),
        const SizedBox(height: AppSpacing.lg),
        Text(
          Strings.tvEnterCode,
          style: AppTheme.micro(
            color: AppColors.textSecondary,
          ).copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _codeCtrl,
          textAlign: TextAlign.center,
          style: AppTheme.statNumber(fontSize: 28).copyWith(letterSpacing: 12),
          keyboardType: TextInputType.number,
          maxLength: 4,
          onSubmitted: (_) => _connect(),
          decoration: const InputDecoration(counterText: '', hintText: '••••'),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTheme.caption(
              color: AppColors.danger,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        BeatPrimaryButton(
          label: Strings.connect,
          icon: Icons.tv_rounded,
          loading: _connecting,
          onPressed: _connect,
        ),
        const SizedBox(height: AppSpacing.sm),
        BeatSecondaryButton(
          label: Strings.previewOnThisDevice,
          icon: Icons.smartphone_rounded,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TvHostScreen(studioId: widget.studioId),
            ),
          ),
        ),
      ],
    );
  }

  Widget _connectedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          Strings.tvConnected,
          style: AppTheme.h1().copyWith(fontSize: 24),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          Strings.tvConnectedHint,
          style: AppTheme.bodyLarge(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        BeatSecondaryButton(
          label: Strings.tvConnectAnother,
          icon: Icons.tv_rounded,
          onPressed: () => setState(() {
            _connected = false;
            _codeCtrl.clear();
          }),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandRed.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.brandRed.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '$n',
              style: AppTheme.caption(
                color: AppColors.brandRed,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: AppTheme.bodyLarge(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
