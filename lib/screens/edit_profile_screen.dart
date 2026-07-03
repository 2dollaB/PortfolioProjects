import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';
import '../widgets/beat_button.dart';

/// Edit personal info. Reuses the same numeric fields as the wizard.
/// Saves on tap of Save and pops back to settings.
class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final void Function(UserProfile updated)? onSaved;

  const EditProfileScreen({
    super.key,
    required this.profile,
    this.onSaved,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _weight;
  late final TextEditingController _height;
  late final TextEditingController _restingHr;
  late Sex _sex;
  late FitnessLevel _fitnessLevel;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.name);
    _age = TextEditingController(text: p.age.toString());
    _weight = TextEditingController(text: p.weightKg.toStringAsFixed(0));
    _height = TextEditingController(text: p.heightCm.toStringAsFixed(0));
    _restingHr = TextEditingController(
      text: p.restingHr?.toString() ?? '',
    );
    _sex = p.sex;
    _fitnessLevel = p.fitnessLevel;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    _restingHr.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return Strings.nameRequired;
    final age = int.tryParse(_age.text);
    if (age == null || age < 13 || age > 100) {
      return Strings.ageRange;
    }
    final w = double.tryParse(_weight.text.replaceAll(',', '.'));
    if (w == null || w < 30 || w > 250) {
      return Strings.weightRange;
    }
    final h = double.tryParse(_height.text.replaceAll(',', '.'));
    if (h == null || h < 100 || h > 230) {
      return Strings.heightRange;
    }
    final rhrText = _restingHr.text.trim();
    if (rhrText.isNotEmpty) {
      final rhr = int.tryParse(rhrText);
      if (rhr == null || rhr < 30 || rhr > 120) {
        return Strings.restingHrRange;
      }
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    // Preserve email/studioId/manualHrMax — the edit form doesn't expose them.
    final updated = UserProfile(
      id: widget.profile.id,
      name: _name.text.trim(),
      email: widget.profile.email,
      studioId: widget.profile.studioId,
      age: int.parse(_age.text),
      sex: _sex,
      weightKg: double.parse(_weight.text.replaceAll(',', '.')),
      heightCm: double.parse(_height.text.replaceAll(',', '.')),
      restingHr: int.tryParse(_restingHr.text.trim()),
      fitnessLevel: _fitnessLevel,
      role: widget.profile.role,
      manualHrMax: widget.profile.manualHrMax,
    );
    // Persist to Firestore when signed in (production); prototype has no user.
    // Local-first: the write lands in the local cache instantly and syncs in
    // the background, so awaiting the server ack here left the button doing
    // "nothing" on a flaky connection (and lost the edit if the app was
    // killed before the ack).
    final uid = AuthService.currentUid;
    if (uid != null) {
      unawaited(UserRepository.update(uid, updated));
    }
    widget.onSaved?.call(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Strings.pick('Profile updated', 'Profil ažuriran')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  int _previewHrMax() {
    final age = int.tryParse(_age.text) ?? widget.profile.age;
    return _sex == Sex.female
        ? (206 - 0.88 * age).round()
        : (208 - 0.7 * age).round();
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(Strings.personalInfo),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
          ),
          children: [
            _label(Strings.name),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: Strings.pick('Your name', 'Vaše ime'),
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(Strings.age),
                      _numField(_age, hint: '30', suffix: 'yrs'),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(Strings.sex),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bgSecondary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButton<Sex>(
                          value: _sex,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon: Icon(Icons.expand_more_rounded,
                              color: AppColors.textSecondary),
                          dropdownColor: AppColors.bgSecondary,
                          style: AppTheme.bodyLarge(),
                          items: Sex.values
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(Strings.sexName(s)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _sex = v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(Strings.weight),
                      _numField(_weight, hint: '75', suffix: 'kg', decimal: true),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(Strings.height),
                      _numField(_height, hint: '178', suffix: 'cm'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            _label(Strings.restingHrOptional),
            _numField(_restingHr, hint: 'e.g. 62', suffix: 'bpm'),
            const SizedBox(height: AppSpacing.lg),

            _label(Strings.fitnessLevel),
            for (final lvl in FitnessLevel.values) ...[
              _fitnessChip(lvl),
              const SizedBox(height: AppSpacing.xs),
            ],

            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.brandRed.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.monitor_heart_rounded,
                        color: AppColors.brandRed, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Strings.estimatedHrMax, style: AppTheme.caption()),
                        Text(
                          '${_previewHrMax()} bpm',
                          style: AppTheme.statNumber(
                            fontSize: 22,
                            color: AppColors.brandRed,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            BeatPrimaryButton(
              label: Strings.pick('Save changes', 'Spremi promjene'),
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
          ],
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

  Widget _numField(
    TextEditingController c, {
    required String hint,
    required String suffix,
    bool decimal = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        if (decimal)
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
        suffixStyle: AppTheme.caption(),
      ),
    );
  }

  Widget _fitnessChip(FitnessLevel level) {
    final selected = _fitnessLevel == level;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _fitnessLevel = level),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandRed.withValues(alpha: 0.12)
                : AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.fitnessName(level),
                      style: AppTheme.bodyLarge(weight: FontWeight.w600)
                          .copyWith(fontSize: 14),
                    ),
                    Text(Strings.fitnessDesc(level), style: AppTheme.caption()),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.brandRed, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
