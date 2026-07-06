import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';
import '../widgets/mobile_frame.dart';

/// Sends a Firebase password-reset email. Firebase delivers and hosts the
/// reset page, so there's no backend here.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = Strings.emailInvalid);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await AuthService.sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
      _sent = err == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text(Strings.resetPasswordTitle),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: _sent ? _sentView() : _formView(),
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        const Center(child: LogoHeartbeat(size: 28, showWordmark: false)),
        const SizedBox(height: AppSpacing.xl),
        Text(Strings.resetPasswordTitle, style: AppTheme.h2()),
        const SizedBox(height: AppSpacing.xs),
        Text(
          Strings.resetPasswordSubtitle,
          style: AppTheme.bodyLarge(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: Strings.email,
            prefixIcon: const Icon(Icons.mail_outline_rounded),
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
          label: Strings.sendResetLink,
          icon: Icons.send_rounded,
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _sentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Icon(Icons.mark_email_read_rounded,
            size: 64, color: AppColors.success),
        const SizedBox(height: AppSpacing.lg),
        Text(
          Strings.resetLinkSent,
          style: AppTheme.bodyLarge(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        BeatPrimaryButton(
          label: Strings.backToSignIn,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
