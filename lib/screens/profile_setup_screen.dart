import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  final UserProfile? existingProfile;
  final VoidCallback onComplete;

  const ProfileSetupScreen({
    super.key,
    this.existingProfile,
    required this.onComplete,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  static const _totalPages = 3;

  // Form values
  String _name = '';
  int _age = 30;
  Sex _sex = Sex.male;
  double _weight = 75.0;
  double _height = 178.0;
  int? _restingHr; // Optional (null = not set)
  FitnessLevel _fitnessLevel = FitnessLevel.casual;
  UserRole _role = UserRole.athlete;

  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    if (widget.existingProfile != null) {
      final p = widget.existingProfile!;
      _name = p.name;
      _age = p.age;
      _sex = p.sex;
      _weight = p.weightKg;
      _height = p.heightCm;
      _restingHr = p.restingHr;
      _fitnessLevel = p.fitnessLevel;
      _role = p.role;
    }
    _nameController = TextEditingController(text: _name);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _saveProfile();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      FocusScope.of(context).unfocus();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _saveProfile() async {
    final profile = UserProfile(
      name: _name.isEmpty ? 'Athlete' : _name,
      age: _age,
      sex: _sex,
      weightKg: _weight,
      heightCm: _height,
      restingHr: _restingHr,
      fitnessLevel: _fitnessLevel,
      role: _role,
    );
    await StorageService.saveProfile(profile);
    widget.onComplete();
  }

  int get _progressPercent => ((_currentPage + 1) / _totalPages * 100).round();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ── Top Bar: Back + BEATSYNC + step indicator ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    GestureDetector(
                      onTap: _previousPage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.surfaceLight),
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            size: 16, color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    const SizedBox(width: 36),
                  const Spacer(),
                  Text('BEATSYNC',
                      style: AppTheme.mono(
                        fontSize: 15, letterSpacing: 3,
                        fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                      )),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Step Progress ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('STEP ${_currentPage + 1} OF $_totalPages',
                          style: AppTheme.mono(
                            fontSize: 11, letterSpacing: 2,
                            color: AppTheme.textMuted, fontWeight: FontWeight.w600,
                          )),
                      Text('$_progressPercent% Complete',
                          style: AppTheme.mono(
                            fontSize: 11,
                            color: AppTheme.accent, fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 4,
                      child: Row(
                        children: List.generate(_totalPages, (index) {
                          final isActive = index <= _currentPage;
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
                              decoration: BoxDecoration(
                                gradient: isActive ? const LinearGradient(
                                  colors: [AppTheme.accent, AppTheme.accentLight],
                                ) : null,
                                color: isActive ? null : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildPersonalPage(),
                  _buildFitnessPage(),
                  _buildRolePage(),
                ],
              ),
            ),

            // ── Bottom: Continue button + Terms ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: AppTheme.accent,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage < _totalPages - 1 ? 'Continue' : 'Start Training',
                        style: AppTheme.heading(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _currentPage < _totalPages - 1 ? Icons.arrow_forward : Icons.bolt,
                        size: 20, color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_currentPage == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'By continuing, you agree to our Terms of Service',
                  style: AppTheme.body(fontSize: 11, color: AppTheme.textMuted),
                ),
              )
            else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // PAGE 1: Personal Profile (Name, Age, Sex, Weight, Height)
  // ═══════════════════════════════════════════
  Widget _buildPersonalPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Personal Profile',
              style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text("Let's build your rhythm",
              style: AppTheme.heading(fontSize: 26)),
          const SizedBox(height: 28),

          // Full Name
          Text('FULL NAME', style: _labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            onChanged: (v) => _name = v,
            style: AppTheme.body(color: Colors.white, fontSize: 16),
            decoration: _inputDecoration('Enter your name'),
          ),
          const SizedBox(height: 24),

          // Age + Gender — side by side
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AGE', style: _labelStyle),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.surfaceLight),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () { if (_age > 14) setState(() => _age--); },
                            child: Icon(Icons.remove, size: 18, color: AppTheme.textMuted),
                          ),
                          Expanded(
                            child: Text('$_age',
                                textAlign: TextAlign.center,
                                style: AppTheme.heading(fontSize: 18)),
                          ),
                          GestureDetector(
                            onTap: () { if (_age < 80) setState(() => _age++); },
                            child: Icon(Icons.add, size: 18, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GENDER', style: _labelStyle),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.surfaceLight),
                      ),
                      child: DropdownButton<Sex>(
                        value: _sex,
                        isExpanded: true,
                        underline: const SizedBox(),
                        dropdownColor: AppTheme.surfaceActive,
                        style: AppTheme.body(color: Colors.white, fontSize: 16),
                        items: Sex.values.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.displayName),
                        )).toList(),
                        onChanged: (v) { if (v != null) setState(() => _sex = v); },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Weight + Height — side by side
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WEIGHT (KG)', style: _labelStyle),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.surfaceLight),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () { if (_weight > 40) setState(() => _weight -= 0.5); },
                            child: Icon(Icons.remove, size: 18, color: AppTheme.textMuted),
                          ),
                          Expanded(
                            child: Text(_weight.toStringAsFixed(1),
                                textAlign: TextAlign.center,
                                style: AppTheme.heading(fontSize: 18)),
                          ),
                          GestureDetector(
                            onTap: () { if (_weight < 160) setState(() => _weight += 0.5); },
                            child: Icon(Icons.add, size: 18, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HEIGHT (CM)', style: _labelStyle),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.surfaceLight),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () { if (_height > 140) setState(() => _height--); },
                            child: Icon(Icons.remove, size: 18, color: AppTheme.textMuted),
                          ),
                          Expanded(
                            child: Text('${_height.round()}',
                                textAlign: TextAlign.center,
                                style: AppTheme.heading(fontSize: 18)),
                          ),
                          GestureDetector(
                            onTap: () { if (_height < 220) setState(() => _height++); },
                            child: Icon(Icons.add, size: 18, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Resting Heart Rate (optional) ──
          Row(
            children: [
              Text('RESTING HR (OPTIONAL)', style: _labelStyle),
              const SizedBox(width: 8),
              const Tooltip(
                message: 'Measure your HR lying down in the morning',
                child: Icon(Icons.info_outline, size: 14, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final current = _restingHr ?? 60;
                    if (current > 30) setState(() => _restingHr = current - 1);
                  },
                  child: Icon(Icons.remove, size: 18, color: AppTheme.textMuted),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _restingHr != null ? '$_restingHr' : '--',
                        textAlign: TextAlign.center,
                        style: AppTheme.heading(
                          fontSize: 18,
                          color: _restingHr != null && _restingHr! <= 60
                              ? AppTheme.success
                              : Colors.white,
                        ),
                      ),
                      Text('bpm',
                          style: AppTheme.mono(
                            fontSize: 10, color: AppTheme.textMuted, letterSpacing: 1,
                          )),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final current = _restingHr ?? 59;
                    if (current < 120) setState(() => _restingHr = current + 1);
                  },
                  child: Icon(Icons.add, size: 18, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (_restingHr != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _restingHr! <= 60
                    ? '✓ Excellent — well-trained heart'
                    : _restingHr! <= 80
                        ? 'Normal range (60–80 bpm)'
                        : 'Higher than average — measure after full rest',
                style: AppTheme.body(
                  fontSize: 11,
                  color: _restingHr! <= 60 ? AppTheme.success : AppTheme.textMuted,
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // PAGE 2: Role Selection (I AM AN...)
  // ═══════════════════════════════════════════
  Widget _buildRolePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Almost there!',
              style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Choose your role',
              style: AppTheme.heading(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            'This determines your BeatSync experience',
            style: AppTheme.body(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Text('I AM AN', style: _labelStyle),
          const SizedBox(height: 12),

          Row(
            children: UserRole.values.map((role) {
              final isSelected = role == _role;
              final icons = {
                UserRole.athlete: Icons.favorite,
                UserRole.trainer: Icons.groups,
              };

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _role = role),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      gradient: isSelected ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.accent.withValues(alpha: 0.2),
                          AppTheme.accent.withValues(alpha: 0.05),
                        ],
                      ) : null,
                      color: isSelected ? null : AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : AppTheme.surfaceLight,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accent.withValues(alpha: 0.15)
                                : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icons[role],
                            color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                            size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(role.displayName.toUpperCase(),
                            style: AppTheme.mono(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Role description
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.boldCard(),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _role == UserRole.athlete
                        ? 'Connect your HR monitor, join group sessions, and track your workouts with real-time analytics.'
                        : 'Host group sessions, display HR on TV screens, and manage your athletes in real-time.',
                    style: AppTheme.body(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // HRmax Preview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glowCard(color: AppTheme.accent),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.monitor_heart, color: AppTheme.accent, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Estimated HRmax',
                        style: AppTheme.body(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text('${_calculatePreviewHrMax()} BPM',
                        style: AppTheme.heading(fontSize: 24, color: AppTheme.accent)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _sex == Sex.female ? 'Gulati' : 'Tanaka',
                    style: AppTheme.mono(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  int _calculatePreviewHrMax() {
    return _sex == Sex.female
        ? (206 - (0.88 * _age)).round()
        : (208 - (0.7 * _age)).round();
  }

  // ═══════════════════════════════════════════
  // PAGE 3(now 2): Fitness Level - expanded
  // ═══════════════════════════════════════════
  Widget _buildFitnessPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Training Profile',
              style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('What\'s your fitness level?',
              style: AppTheme.heading(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            'This helps calibrate your Training Effect and calorie calculations',
            style: AppTheme.body(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 28),

          ...FitnessLevel.values.map((level) {
            final isSelected = level == _fitnessLevel;
            final icons = {
              FitnessLevel.beginner: Icons.directions_walk,
              FitnessLevel.casual: Icons.directions_run,
              FitnessLevel.advanced: Icons.fitness_center,
            };
            final descriptions = {
              FitnessLevel.beginner: 'New to regular exercise. You\'ll see results faster and need more recovery between sessions.',
              FitnessLevel.casual: 'You exercise 2-3 times per week. A balanced level for most active people.',
              FitnessLevel.advanced: 'You train 5+ times per week. Higher threshold needed for training effect.',
            };

            return GestureDetector(
              onTap: () => setState(() => _fitnessLevel = level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isSelected ? LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.15),
                      AppTheme.accent.withValues(alpha: 0.05),
                    ],
                  ) : null,
                  color: isSelected ? null : AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.surfaceLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: isSelected ? LinearGradient(
                          colors: [
                            AppTheme.accent.withValues(alpha: 0.25),
                            AppTheme.accent.withValues(alpha: 0.1),
                          ],
                        ) : null,
                        color: isSelected ? null : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icons[level],
                        color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(level.displayName,
                              style: AppTheme.body(
                                fontSize: 17, fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppTheme.textSecondary,
                              )),
                          const SizedBox(height: 4),
                          Text(descriptions[level]!,
                              style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: AppTheme.accent, size: 22),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SHARED STYLES
  // ═══════════════════════════════════════════
  TextStyle get _labelStyle => AppTheme.mono(
    color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5,
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.body(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.surfaceLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.surfaceLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
