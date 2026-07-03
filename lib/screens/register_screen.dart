import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';

/// Mock registration for the prototype.
/// Validates required fields, then hands control back to the parent flow
/// which mounts the profile setup wizard (role pick + fitness + strap + studio).
class RegisterScreen extends StatefulWidget {
  /// Called with the user's typed name so the wizard can skip asking for it again.
  final void Function(String name) onRegistered;
  final VoidCallback onBackToLogin;

  /// Production hook. When provided, creates the Firebase account; on success
  /// the AuthGate takes over (user becomes signed in → onboarding). Shows the
  /// returned error otherwise. When null, the mock prototype flow is used.
  final Future<String?> Function(String name, String email, String password)?
      register;

  const RegisterScreen({
    super.key,
    required this.onRegistered,
    required this.onBackToLogin,
    this.register,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    if ((v ?? '').trim().isEmpty) return Strings.nameRequired;
    return null;
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return Strings.emailRequired;
    if (!value.contains('@') || !value.contains('.')) {
      return Strings.emailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return Strings.passwordRequired;
    if (value.length < 6) return Strings.passwordTooShort;
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '').isEmpty) return Strings.confirmPasswordRequired;
    if (v != _password.text) return Strings.passwordsDontMatch;
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Production: create the Firebase account. Success → AuthGate navigates.
    if (widget.register != null) {
      setState(() => _loading = true);
      final err = await widget.register!(
        _name.text.trim(),
        _email.text.trim().toLowerCase(),
        _password.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onRegistered(_name.text.trim());
  }

  Future<void> _googleSignup() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onRegistered(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                const LogoHeartbeat(size: 28, showWordmark: true),
                const SizedBox(height: AppSpacing.xl),
                Text(Strings.createYourAccount, style: AppTheme.h1()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Strings.registerTagline,
                  style: AppTheme.bodyLarge(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                _label(Strings.name),
                TextFormField(
                  controller: _name,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateName,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: Strings.pick('Your full name', 'Vaše ime i prezime'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _label(Strings.email),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateEmail,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'you@studio.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _label(Strings.password),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validatePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: Strings.pick('At least 6 characters', 'Najmanje 6 znakova'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _label(Strings.confirmPassword),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: Strings.pick('Repeat your password', 'Ponovite lozinku'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                BeatPrimaryButton(
                  label: Strings.createAccount,
                  loading: _loading,
                  onPressed: _submit,
                ),
                // Google sign-up is prototype-only (MVP = email/password).
                if (widget.register == null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const _OrDivider(),
                  const SizedBox(height: AppSpacing.lg),
                  _SocialButton(
                    icon: Icons.g_mobiledata_rounded,
                    label: Strings.continueWithGoogle,
                    onTap: _googleSignup,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Text(
                    Strings.bySigningUp,
                    textAlign: TextAlign.center,
                    style: AppTheme.caption(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(Strings.haveAccount, style: AppTheme.caption()),
                      TextButton(
                        onPressed: widget.onBackToLogin,
                        child: Text(Strings.backToLogin),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          t.toUpperCase(),
          style: AppTheme.micro(color: AppColors.textSecondary)
              .copyWith(letterSpacing: 1.4),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(Strings.or, style: AppTheme.micro()),
        ),
        Expanded(
          child: Divider(color: AppColors.border.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTheme.bodyLarge(weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}