import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';

/// Email + password sign-in. Firebase wiring lands later — for now
/// this is the visual + interaction shell.
class LoginScreen extends StatefulWidget {
  final VoidCallback onSignedIn;
  final VoidCallback onCreateAccount;

  const LoginScreen({
    super.key,
    required this.onSignedIn,
    required this.onCreateAccount,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const LogoHeartbeat(size: 28, showWordmark: true),
              const SizedBox(height: AppSpacing.xxl),
              Text('Welcome back', style: AppTheme.h1()),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sign in to keep your training history in sync.',
                style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              _Label('Email'),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'you@studio.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _Label('Password'),
              TextField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _error!,
                  style: AppTheme.caption(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              BeatPrimaryButton(
                label: 'Sign in',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _OrDivider(),
              const SizedBox(height: AppSpacing.lg),
              _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onTap: () {},
              ),
              const SizedBox(height: AppSpacing.sm),
              _SocialButton(
                icon: Icons.apple_rounded,
                label: 'Continue with Apple',
                onTap: () {},
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: AppTheme.caption(),
                    ),
                    TextButton(
                      onPressed: widget.onCreateAccount,
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  // ignore: unused_element_parameter
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.micro(color: AppColors.darkTextSecondary)
            .copyWith(letterSpacing: 1.4),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Divider(color: AppColors.darkBorder.withValues(alpha: 0.6))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('OR', style: AppTheme.micro()),
        ),
        Expanded(
            child: Divider(color: AppColors.darkBorder.withValues(alpha: 0.6))),
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
          foregroundColor: AppColors.darkTextPrimary,
          side: const BorderSide(color: AppColors.darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
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
