import 'dart:math' as math;
import '../widgets/mobile_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../widgets/beat_button.dart';

/// One step in the post-registration setup wizard.
enum _PageType {
  personal,
  fitness,
  strap,
  studioForm,
  studioSuccess,
}

/// Post-registration setup wizard.
///
/// **Athletes (3 pages):** Personal -> Fitness -> Strap pairing
/// **Trainers (2 pages):** Studio form -> Studio success
///
/// Trainers skip the personal-fitness data entirely. They manage sessions,
/// they don't run workouts. If they want to train, they create an athlete
/// account on the side.
class ProfileSetupScreen extends StatefulWidget {
  /// Name collected on the register screen. We don't ask for it again.
  final String? initialName;
  final UserProfile? existingProfile;

  /// Called with the final picked role when the wizard completes.
  /// The parent uses this to mount the right home (athlete vs trainer).
  final void Function(UserRole role) onComplete;

  /// Initial role suggestion. The wizard's own role-pick page can override it.
  final UserRole role;

  const ProfileSetupScreen({
    super.key,
    this.initialName,
    this.existingProfile,
    required this.onComplete,
    this.role = UserRole.athlete,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _pageController = PageController();
  int _page = 0;

  // â”€â”€ Page 1: Personal â”€â”€
  final _ageCtrl = TextEditingController(text: '30');
  final _weightCtrl = TextEditingController(text: '75');
  final _heightCtrl = TextEditingController(text: '178');
  final _restingHrCtrl = TextEditingController();
  Sex _sex = Sex.male;

  // â”€â”€ Page 2: Fitness â”€â”€
  FitnessLevel _fitnessLevel = FitnessLevel.casual;

  // â”€â”€ Page 3: Role â”€â”€
  late UserRole _role;

  // â”€â”€ Page 4: HR strap â”€â”€
  _StrapStatus _strap = _StrapStatus.idle;
  String _strapName = '';

  // â”€â”€ Page 5: Studio (trainer only) â”€â”€
  final _studioNameCtrl = TextEditingController();
  final _studioLocationCtrl = TextEditingController();
  int _studioCapacity = 30;
  String _inviteCode = '';

  // Role is picked OUTSIDE the wizard (dedicated role-select screen after
  // register). Wizard receives it via widget.role and doesn't change it.
  //
  // Trainers don't train — they manage. So we skip the personal/fitness/strap
  // pages entirely and jump straight to studio creation.
  //   Trainer:  Studio form → Studio success     (2 pages)
  //   Athlete:  Personal → Fitness → Strap       (3 pages)
  List<_PageType> get _pageTypes => _role == UserRole.trainer
      ? const [_PageType.studioForm, _PageType.studioSuccess]
      : const [_PageType.personal, _PageType.fitness, _PageType.strap];

  int get _totalPages => _pageTypes.length;

  _PageType get _currentPageType => _pageTypes[_page];

  @override
  void initState() {
    super.initState();
    _role = widget.role;
    final existing = widget.existingProfile;
    if (existing != null) {
      _ageCtrl.text = existing.age.toString();
      _weightCtrl.text = existing.weightKg.toStringAsFixed(0);
      _heightCtrl.text = existing.heightCm.toStringAsFixed(0);
      _restingHrCtrl.text = existing.restingHr?.toString() ?? '';
      _sex = existing.sex;
      _fitnessLevel = existing.fitnessLevel;
      _role = existing.role;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _restingHrCtrl.dispose();
    _studioNameCtrl.dispose();
    _studioLocationCtrl.dispose();
    super.dispose();
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Navigation
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String? _validateCurrentPage() {
    switch (_currentPageType) {
      case _PageType.personal:
        final age = int.tryParse(_ageCtrl.text);
        if (age == null || age < 13 || age > 100) {
          return 'Age must be between 13 and 100';
        }
        final w = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
        if (w == null || w < 30 || w > 250) {
          return 'Weight must be between 30 and 250 kg';
        }
        final h = double.tryParse(_heightCtrl.text.replaceAll(',', '.'));
        if (h == null || h < 100 || h > 230) {
          return 'Height must be between 100 and 230 cm';
        }
        final rhrText = _restingHrCtrl.text.trim();
        if (rhrText.isNotEmpty) {
          final rhr = int.tryParse(rhrText);
          if (rhr == null || rhr < 30 || rhr > 120) {
            return 'Resting HR must be between 30 and 120 bpm';
          }
        }
        return null;
      case _PageType.studioForm:
        if (_studioNameCtrl.text.trim().isEmpty) {
          return 'Studio name is required';
        }
        return null;
      default:
        return null;
    }
  }

  String _generateInviteCode() {
    final r = math.Random();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  Future<void> _onContinue() async {
    final error = _validateCurrentPage();
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

    // When leaving the studio form, generate the invite code BEFORE
    // advancing to the success page so it can display it.
    if (_currentPageType == _PageType.studioForm && _inviteCode.isEmpty) {
      _inviteCode = _generateInviteCode();
    }

    if (_page < _totalPages - 1) {
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await _saveAndFinish();
    }
  }

  void _onBack() {
    FocusScope.of(context).unfocus();
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _saveAndFinish() async {
    final age = int.tryParse(_ageCtrl.text) ?? 30;
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? 75;
    final height = double.tryParse(_heightCtrl.text.replaceAll(',', '.')) ?? 178;
    final restingHr = int.tryParse(_restingHrCtrl.text.trim());

    final profile = UserProfile(
      name: (widget.initialName ?? '').trim().isEmpty
          ? 'Athlete'
          : widget.initialName!.trim(),
      age: age,
      sex: _sex,
      weightKg: weight,
      heightCm: height,
      restingHr: restingHr,
      fitnessLevel: _fitnessLevel,
      role: _role,
    );

    // Save lightly â€” the production flow uses real storage. Prototype is a noop.
    try {
      await StorageService.saveProfile(profile);
    } catch (_) {/* prototype/web â€” ignore */}

    widget.onComplete(_role);
  }

  String _continueLabel() {
    if (_page == _totalPages - 1) {
      return _role == UserRole.trainer ? 'Enter your studio' : 'Start training';
    }
    switch (_currentPageType) {
      case _PageType.studioForm:
        return 'Create studio';
      case _PageType.strap:
        return _strap != _StrapStatus.connected ? 'Skip for now' : 'Continue';
      default:
        return 'Continue';
    }
  }

  IconData? _continueIcon() {
    if (_page == _totalPages - 1) return Icons.bolt_rounded;
    return Icons.arrow_forward_rounded;
  }

  int _previewHrMax() {
    final age = int.tryParse(_ageCtrl.text) ?? 30;
    return _sex == Sex.female
        ? (206 - 0.88 * age).round()
        : (208 - 0.7 * age).round();
  }

  Widget _buildPage(_PageType type) {
    switch (type) {
      case _PageType.personal:
        return _PersonalPage(
          nameHint: widget.initialName ?? 'your training profile',
          ageCtrl: _ageCtrl,
          weightCtrl: _weightCtrl,
          heightCtrl: _heightCtrl,
          restingHrCtrl: _restingHrCtrl,
          sex: _sex,
          onSexChanged: (s) => setState(() => _sex = s),
        );
      case _PageType.fitness:
        return _FitnessPage(
          selected: _fitnessLevel,
          onChanged: (lvl) => setState(() => _fitnessLevel = lvl),
          previewHrMax: _previewHrMax(),
          formulaLabel:
              _sex == Sex.female ? 'Gulati formula' : 'Tanaka formula',
        );
      case _PageType.strap:
        return _StrapPage(
          status: _strap,
          strapName: _strapName,
          onSearch: () async {
            setState(() => _strap = _StrapStatus.searching);
            await Future.delayed(const Duration(milliseconds: 1400));
            if (!mounted) return;
            setState(() {
              _strap = _StrapStatus.connected;
              _strapName = 'Polar H10';
            });
          },
          onDisconnect: () => setState(() {
            _strap = _StrapStatus.idle;
            _strapName = '';
          }),
        );
      case _PageType.studioForm:
        return _StudioFormPage(
          nameCtrl: _studioNameCtrl,
          locationCtrl: _studioLocationCtrl,
          capacity: _studioCapacity,
          onCapacityChanged: (v) => setState(() => _studioCapacity = v),
        );
      case _PageType.studioSuccess:
        return _StudioSuccessPage(
          studioName: _studioNameCtrl.text.trim().isEmpty
              ? 'Your studio'
              : _studioNameCtrl.text.trim(),
          inviteCode: _inviteCode,
        );
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Build
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              page: _page,
              total: _totalPages,
              onBack: _page == 0 ? null : _onBack,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final type in _pageTypes) _buildPage(type),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.md,
              ),
              child: BeatPrimaryButton(
                label: _continueLabel(),
                icon: _continueIcon(),
                onPressed: _onContinue,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Top bar â€” back button + step progress
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TopBar extends StatelessWidget {
  final int page;
  final int total;
  final VoidCallback? onBack;
  const _TopBar({required this.page, required this.total, this.onBack});

  @override
  Widget build(BuildContext context) {
    final pct = ((page + 1) / total * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (onBack != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.darkBgSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 36),
              const Spacer(),
              Text(
                'BEATSYNC',
                style: AppTheme.micro(color: AppColors.darkTextPrimary)
                    .copyWith(
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP ${page + 1} OF $total',
                style: AppTheme.micro().copyWith(letterSpacing: 1.6),
              ),
              Text(
                '$pct% complete',
                style: AppTheme.micro(color: AppColors.brandRed)
                    .copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: Row(
                children: List.generate(total, (i) {
                  final active = i <= page;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      margin: EdgeInsets.only(left: i > 0 ? 3 : 0),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.brandRed
                            : AppColors.darkBgTertiary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Reusable: section header + numeric field
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PageScroll extends StatelessWidget {
  final Widget child;
  const _PageScroll({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: child,
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String overline;
  final String title;
  final String? subtitle;
  const _PageHeader({
    required this.overline,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(overline.toUpperCase(),
            style: AppTheme.micro().copyWith(letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(title, style: AppTheme.h1().copyWith(fontSize: 26)),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  // ignore: unused_element_parameter
  const _FieldLabel(this.text);

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

class _NumericField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final bool allowDecimal;

  const _NumericField({
    required this.controller,
    required this.hint,
    required this.suffix,
    this.allowDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        if (allowDecimal)
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
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PAGE 1: Personal
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PersonalPage extends StatelessWidget {
  final String nameHint;
  final TextEditingController ageCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController heightCtrl;
  final TextEditingController restingHrCtrl;
  final Sex sex;
  final ValueChanged<Sex> onSexChanged;

  const _PersonalPage({
    required this.nameHint,
    required this.ageCtrl,
    required this.weightCtrl,
    required this.heightCtrl,
    required this.restingHrCtrl,
    required this.sex,
    required this.onSexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            overline: 'Personal profile',
            title: "Let's build your rhythm",
            subtitle: 'A few numbers to calibrate your zones and effort scores.',
          ),

          // Age + Sex
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Age'),
                    _NumericField(
                      controller: ageCtrl,
                      hint: '30',
                      suffix: 'yrs',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Sex'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.darkBgSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: DropdownButton<Sex>(
                        value: sex,
                        isExpanded: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.expand_more_rounded,
                            color: AppColors.darkTextSecondary),
                        dropdownColor: AppColors.darkBgSecondary,
                        style: AppTheme.bodyLarge(),
                        items: Sex.values
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.displayName),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) onSexChanged(v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Weight + Height
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Weight'),
                    _NumericField(
                      controller: weightCtrl,
                      hint: '75',
                      suffix: 'kg',
                      allowDecimal: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Height'),
                    _NumericField(
                      controller: heightCtrl,
                      hint: '178',
                      suffix: 'cm',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Resting HR
          Row(
            children: [
              _FieldLabel('Resting HR (optional)'),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Measure lying down in the morning before getting up.',
                child: Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.darkTextSecondary),
              ),
            ],
          ),
          _NumericField(
            controller: restingHrCtrl,
            hint: 'e.g. 62',
            suffix: 'bpm',
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              nameHint,
              style: AppTheme.caption(),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PAGE 2: Fitness
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FitnessPage extends StatelessWidget {
  final FitnessLevel selected;
  final ValueChanged<FitnessLevel> onChanged;
  final int previewHrMax;
  final String formulaLabel;

  const _FitnessPage({
    required this.selected,
    required this.onChanged,
    required this.previewHrMax,
    required this.formulaLabel,
  });

  static const _icons = {
    FitnessLevel.beginner: Icons.directions_walk_rounded,
    FitnessLevel.casual: Icons.directions_run_rounded,
    FitnessLevel.advanced: Icons.fitness_center_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            overline: 'Training profile',
            title: "What's your fitness level?",
            subtitle:
                'Calibrates your training effect and calorie calculations.',
          ),
          for (final lvl in FitnessLevel.values) ...[
            _FitnessOption(
              level: lvl,
              icon: _icons[lvl]!,
              selected: selected == lvl,
              onTap: () => onChanged(lvl),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.brandRed.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.monitor_heart_rounded,
                      color: AppColors.brandRed, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated HR max', style: AppTheme.caption()),
                      Text(
                        '$previewHrMax bpm',
                        style: AppTheme.statNumber(
                          fontSize: 24,
                          color: AppColors.brandRed,
                          weight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkBgTertiary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    formulaLabel,
                    style: AppTheme.micro(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FitnessOption extends StatelessWidget {
  final FitnessLevel level;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FitnessOption({
    required this.level,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandRed.withValues(alpha: 0.12)
                : AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.darkBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (selected
                          ? AppColors.brandRed
                          : AppColors.darkTextSecondary)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? AppColors.brandRed
                      : AppColors.darkTextSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.displayName,
                      style:
                          AppTheme.bodyLarge(weight: FontWeight.w600).copyWith(
                        fontSize: 15,
                      ),
                    ),
                    Text(level.description, style: AppTheme.caption()),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.brandRed, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PAGE 3: HR strap pairing
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
enum _StrapStatus { idle, searching, connected }

class _StrapPage extends StatelessWidget {
  final _StrapStatus status;
  final String strapName;
  final VoidCallback onSearch;
  final VoidCallback onDisconnect;

  const _StrapPage({
    required this.status,
    required this.strapName,
    required this.onSearch,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            overline: 'Bluetooth',
            title: 'Connect your strap',
            subtitle: 'Polar · Wahoo · Garmin · generic Bluetooth straps.',
          ),
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (status == _StrapStatus.connected
                            ? AppColors.success
                            : AppColors.brandRed)
                        .withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.darkBgSecondary,
                    border: Border.all(
                      color: (status == _StrapStatus.connected
                              ? AppColors.success
                              : AppColors.brandRed)
                          .withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    status == _StrapStatus.connected
                        ? Icons.favorite_rounded
                        : Icons.bluetooth_searching_rounded,
                    color: status == _StrapStatus.connected
                        ? AppColors.success
                        : AppColors.brandRed,
                    size: 44,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (status == _StrapStatus.idle) ...[
            BeatSecondaryButton(
              label: 'Search for straps',
              icon: Icons.search_rounded,
              onPressed: onSearch,
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                'You can also pair from settings later.',
                style: AppTheme.caption(),
              ),
            ),
          ],
          if (status == _StrapStatus.searching) ...[
            const Center(
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.brandRed),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text('Searching for nearby strapsâ€¦',
                  style: AppTheme.caption(color: AppColors.brandRed)),
            ),
          ],
          if (status == _StrapStatus.connected) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected',
                          style: AppTheme.caption(color: AppColors.success)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '$strapName · 92% battery',
                          style: AppTheme.bodyLarge(weight: FontWeight.w600)
                              .copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onDisconnect,
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PAGE 5: Studio form (trainer only)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _StudioFormPage extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController locationCtrl;
  final int capacity;
  final ValueChanged<int> onCapacityChanged;

  const _StudioFormPage({
    required this.nameCtrl,
    required this.locationCtrl,
    required this.capacity,
    required this.onCapacityChanged,
  });

  static const _options = [10, 20, 30, 50];

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            overline: 'Your studio',
            title: 'Build your space',
            subtitle: 'This is where your athletes will join you.',
          ),
          _FieldLabel('Studio name'),
          TextField(
            controller: nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'e.g. Pulse Studio Mostar',
              prefixIcon: Icon(Icons.fitness_center_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FieldLabel('Location (optional)'),
          TextField(
            controller: locationCtrl,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Mostar, Bosnia & Herzegovina',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _FieldLabel('Maximum members'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final v in _options)
                _CapacityChip(
                  value: v,
                  selected: capacity == v,
                  onTap: () => onCapacityChanged(v),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Upgrade later if you outgrow this.',
            style: AppTheme.caption(),
          ),
        ],
      ),
    );
  }
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
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandRed.withValues(alpha: 0.18)
                : AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.darkBorder,
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
                      : AppColors.darkTextSecondary,
                ),
              ),
              Text(
                '$value',
                style: AppTheme.statNumber(
                  fontSize: 18,
                  color: selected
                      ? AppColors.brandRed
                      : AppColors.darkTextPrimary,
                  weight: FontWeight.w700,
                ).copyWith(height: 1.0),
              ),
              const SizedBox(width: 3),
              Text(
                'members',
                style: AppTheme.caption(
                  color: selected
                      ? AppColors.brandRed
                      : AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PAGE 6: Studio success (trainer only)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _StudioSuccessPage extends StatelessWidget {
  final String studioName;
  final String inviteCode;
  const _StudioSuccessPage({
    required this.studioName,
    required this.inviteCode,
  });

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.lg),
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
            studioName,
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
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                Text(
                  'INVITE CODE',
                  style: AppTheme.micro().copyWith(letterSpacing: 1.6),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  inviteCode.split('').join(' '),
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
        ],
      ),
    );
  }
}