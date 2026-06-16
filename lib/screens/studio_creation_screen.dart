import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';

/// Trainer-only step after profile setup.
///
/// Collects: studio name, location (optional), member capacity.
/// On confirm: shows a "Studio created!" celebration page with the
/// auto-generated 6-digit invite code, then continues to the trainer home.
class StudioCreationScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const StudioCreationScreen({super.key, required this.onComplete});

  @override
  State<StudioCreationScreen> createState() => _StudioCreationScreenState();
}

class _StudioCreationScreenState extends State<StudioCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  int _maxMembers = 30;
  bool _loading = false;
  bool _created = false;
  String _inviteCode = '';

  static const _capacityOptions = [10, 20, 30, 50];

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  String _generateInviteCode() {
    final r = math.Random();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _created = true;
      _inviteCode = _generateInviteCode();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: _created ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.lg),
            const LogoHeartbeat(size: 28, showWordmark: true),
            const SizedBox(height: AppSpacing.xl),
            Text('Create your studio', style: AppTheme.h1()),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This is where your athletes will join you.',
              style: AppTheme.bodyLarge(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            _label('Studio name'),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Studio name is required';
                return null;
              },
              decoration: const InputDecoration(
                hintText: 'e.g. Pulse Studio Mostar',
                prefixIcon: Icon(Icons.fitness_center_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _label('Location (optional)'),
            TextFormField(
              controller: _location,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Mostar, Bosnia & Herzegovina',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label('Maximum members'),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final cap in _capacityOptions)
                  _CapacityChip(
                    value: cap,
                    selected: _maxMembers == cap,
                    onTap: () => setState(() => _maxMembers = cap),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You can upgrade your plan later if you outgrow this.',
              style: AppTheme.caption(),
            ),
            const SizedBox(height: AppSpacing.xl),
            BeatPrimaryButton(
              label: 'Create studio',
              icon: Icons.check_rounded,
              loading: _loading,
              onPressed: _create,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.lg),
          const Align(
            alignment: Alignment.centerLeft,
            child: LogoHeartbeat(size: 28, showWordmark: true),
          ),
          const Spacer(),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.18),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 44,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Studio created!',
            style: AppTheme.h1().copyWith(fontSize: 30),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _name.text.trim().isEmpty ? 'Your studio' : _name.text.trim(),
            style: AppTheme.h2(color: AppColors.brandRed),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  'INVITE CODE',
                  style: AppTheme.micro().copyWith(letterSpacing: 1.6),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _inviteCode.split('').join(' '),
                  style: AppTheme.statNumber(
                    fontSize: 36,
                    color: AppColors.brandRed,
                    weight: FontWeight.w800,
                  ).copyWith(letterSpacing: 6),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Share this with your athletes to join your studio.',
                  textAlign: TextAlign.center,
                  style: AppTheme.caption(),
                ),
              ],
            ),
          ),
          const Spacer(),
          BeatPrimaryButton(
            label: 'Enter your studio',
            icon: Icons.arrow_forward_rounded,
            onPressed: widget.onComplete,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
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

class _CapacityChip extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;
  const _CapacityChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandRed.withValues(alpha: 0.18)
                : AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Up to ',
                style: AppTheme.caption(
                  color: selected
                      ? AppColors.brandRed
                      : AppColors.textSecondary,
                ),
              ),
              Text(
                '$value',
                style: AppTheme.statNumber(
                  fontSize: 18,
                  color:
                      selected ? AppColors.brandRed : AppColors.textPrimary,
                  weight: FontWeight.w700,
                ).copyWith(height: 1.0),
              ),
              const SizedBox(width: 3),
              Text(
                'members',
                style: AppTheme.caption(
                  color: selected
                      ? AppColors.brandRed
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
