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

  // Form values
  String _name = '';
  int _age = 30;
  Sex _sex = Sex.male;
  double _weight = 75.0;
  double _height = 178.0;
  FitnessLevel _fitnessLevel = FitnessLevel.casual;

  // Text controller to avoid rebuild issues
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
      _fitnessLevel = p.fitnessLevel;
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
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (_currentPage < 2) {
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
      fitnessLevel: _fitnessLevel,
    );
    await StorageService.saveProfile(profile);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Top row: Back + Progress
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Back button
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: _previousPage,
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
                    )
                  else
                    const SizedBox(width: 48),

                  // Progress indicator
                  Expanded(
                    child: Row(
                      children: List.generate(3, (index) {
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: index <= _currentPage
                                  ? AppTheme.accent
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 48),
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
                  _buildNameAgePage(),
                  _buildBodyPage(),
                  _buildFitnessPage(),
                ],
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage < 2 ? 'Continue' : 'Start Training',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // PAGE 1: Name, Age, Sex
  // ═══════════════════════════════════════════
  Widget _buildNameAgePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Welcome to',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const Text(
            'BeatSync',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s personalize your experience',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 36),

          // Name
          Text('Your name', style: _labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            onChanged: (v) => _name = v,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: _inputDecoration('Enter your name'),
          ),
          const SizedBox(height: 28),

          // Age
          Text('Age: $_age years', style: _labelStyle),
          const SizedBox(height: 8),
          SliderTheme(
            data: _sliderTheme,
            child: Slider(
              value: _age.toDouble(),
              min: 14,
              max: 80,
              divisions: 66,
              label: '$_age',
              onChanged: (v) => setState(() => _age = v.round()),
            ),
          ),
          const SizedBox(height: 28),

          // Sex
          Text('Sex', style: _labelStyle),
          const SizedBox(height: 12),
          Row(
            children: Sex.values.map((sex) {
              final isSelected = sex == _sex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sex = sex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accent.withValues(alpha: 0.2)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accent
                            : AppTheme.surfaceLight,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      sex.displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // PAGE 2: Weight, Height
  // ═══════════════════════════════════════════
  Widget _buildBodyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'Body Metrics',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Used for accurate calorie calculation',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 36),

          // Weight
          Text('Weight: ${_weight.toStringAsFixed(1)} kg', style: _labelStyle),
          const SizedBox(height: 8),
          SliderTheme(
            data: _sliderTheme,
            child: Slider(
              value: _weight,
              min: 40,
              max: 160,
              divisions: 240,
              label: '${_weight.toStringAsFixed(1)} kg',
              onChanged: (v) =>
                  setState(() => _weight = (v * 2).round() / 2),
            ),
          ),
          const SizedBox(height: 32),

          // Height
          Text('Height: ${_height.round()} cm', style: _labelStyle),
          const SizedBox(height: 8),
          SliderTheme(
            data: _sliderTheme,
            child: Slider(
              value: _height,
              min: 140,
              max: 220,
              divisions: 80,
              label: '${_height.round()} cm',
              onChanged: (v) => setState(() => _height = v.roundToDouble()),
            ),
          ),
          const SizedBox(height: 32),

          // HRmax Preview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.monitor_heart, color: AppTheme.accent, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated HRmax',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    Text(
                      '${_calculatePreviewHrMax()} BPM',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  _sex == Sex.female ? 'Gulati' : 'Tanaka',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
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
  // PAGE 3: Fitness Level
  // ═══════════════════════════════════════════
  Widget _buildFitnessPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'Fitness Level',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Helps calibrate your Training Effect',
            style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 32),

          ...FitnessLevel.values.map((level) {
            final isSelected = level == _fitnessLevel;
            final icons = {
              FitnessLevel.beginner: Icons.directions_walk,
              FitnessLevel.casual: Icons.directions_run,
              FitnessLevel.advanced: Icons.fitness_center,
            };

            return GestureDetector(
              onTap: () => setState(() => _fitnessLevel = level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent : AppTheme.surfaceLight,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accent.withValues(alpha: 0.2)
                            : AppTheme.surfaceLight,
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
                          Text(
                            level.displayName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            level.description,
                            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: AppTheme.accent),
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
  TextStyle get _labelStyle => TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      );

  SliderThemeData get _sliderTheme => SliderThemeData(
        activeTrackColor: AppTheme.accent,
        inactiveTrackColor: AppTheme.surfaceLight,
        thumbColor: AppTheme.accent,
        overlayColor: AppTheme.accent.withValues(alpha: 0.2),
        valueIndicatorColor: AppTheme.accent,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
