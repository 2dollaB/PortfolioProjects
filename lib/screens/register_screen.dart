import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegistered;
  final VoidCallback onBackToLogin;

  const RegisterScreen({
    super.key,
    required this.onRegistered,
    required this.onBackToLogin,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  Future<void> _submit() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onRegistered();
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
              Text('Create your account', style: AppTheme.h1()),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Two minutes — then you can train.',
                style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              _label('Name'),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  hintText: 'Jan Minarik',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _label('Email'),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'you@studio.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _label('Password'),
              TextField(
                controller: _password,
                obscureText: _obscure,
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
              const SizedBox(height: AppSpacing.md),
              _label('Confirm password'),
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              BeatPrimaryButton(
                label: 'Create account',
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _OrDivider(),
              const SizedBox(height: AppSpacing.lg),
              _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onTap: widget.onRegistered,
              ),
              const SizedBox(height: AppSpacing.sm),
              _SocialButton(
                icon: Icons.apple_rounded,
                label: 'Continue with Apple',
                onTap: widget.onRegistered,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  'By signing up you agree to our Terms & Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: AppTheme.caption(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: AppTheme.caption(),
                    ),
                    TextButton(
                      onPressed: widget.onBackToLogin,
                      child: const Text('Back to login'),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          text.toUpperCase(),
          style: AppTheme.micro(color: AppColors.darkTextSecondary)
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
