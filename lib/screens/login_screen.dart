import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';

/// Mock login for the prototype.
///
/// Recognized accounts:
///   athlete@beatsync.ba / test123  â†’ routes to athlete home
///   trainer@beatsync.ba / test123  â†’ routes to trainer home
///
/// Anything else â†’ "Invalid credentials" error.
/// Empty fields â†’ per-field validation message.
class LoginScreen extends StatefulWidget {
  /// Called with the resolved role after successful login. The parent flow
  /// uses this to mount the right home screen.
  final void Function(UserRole role) onSignedIn;

  /// Switch to register flow.
  final VoidCallback onCreateAccount;

  /// Production hook. When provided, the screen calls this with the entered
  /// credentials and shows the returned error (or nothing on success — the
  /// AuthGate reacts to the auth state change). When null, the mock demo
  /// login is used and [onSignedIn] drives navigation.
  final Future<String?> Function(String email, String password)? authenticate;

  const LoginScreen({
    super.key,
    required this.onSignedIn,
    required this.onCreateAccount,
    this.authenticate,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  static const _athleteEmail = 'athlete@beatsync.ba';
  static const _trainerEmail = 'trainer@beatsync.ba';
  static const _testPassword = 'test123';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required';
    if (!value.contains('@') || !value.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    // Production: delegate to Firebase auth. Success → AuthGate navigates.
    if (widget.authenticate != null) {
      setState(() => _loading = true);
      final err = await widget.authenticate!(
        _email.text.trim().toLowerCase(),
        _password.text,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _loading = false);

    final email = _email.text.trim().toLowerCase();
    final password = _password.text;

    if (password != _testPassword ||
        (email != _athleteEmail && email != _trainerEmail)) {
      setState(() => _error = 'Invalid credentials');
      return;
    }

    final role = email == _trainerEmail ? UserRole.trainer : UserRole.athlete;
    widget.onSignedIn(role);
  }

  Future<void> _googleSignIn() async {
    // Mock: route to athlete by default for the prototype.
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onSignedIn(UserRole.athlete);
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
                const SizedBox(height: AppSpacing.xxl),
                Text('Welcome back', style: AppTheme.h1()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Sign in to keep your training history in sync.',
                  style: AppTheme.bodyLarge(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                _Label('Email'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validateEmail,
                  decoration: const InputDecoration(
                    hintText: 'athlete@beatsync.ba',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Label('Password'),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'test123',
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: AppColors.danger),
                        const SizedBox(width: 6),
                        Text(
                          _error!,
                          style: AppTheme.caption(color: AppColors.danger)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                BeatPrimaryButton(
                  label: 'Sign in',
                  loading: _loading,
                  onPressed: _submit,
                ),
                // Google sign-in + demo accounts are prototype-only.
                if (widget.authenticate == null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const _OrDivider(),
                  const SizedBox(height: AppSpacing.lg),
                  _SocialButton(
                    icon: Icons.g_mobiledata_rounded,
                    label: 'Continue with Google',
                    onTap: _googleSignIn,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'DEMO ACCOUNTS',
                            style: AppTheme.micro().copyWith(letterSpacing: 1.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_athleteEmail · $_testPassword',
                            style: AppTheme.caption(color: AppColors.textPrimary),
                          ),
                          Text(
                            '$_trainerEmail · $_testPassword',
                            style: AppTheme.caption(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?", style: AppTheme.caption()),
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
        style: AppTheme.micro(color: AppColors.textSecondary)
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
          child: Divider(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('OR', style: AppTheme.micro()),
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