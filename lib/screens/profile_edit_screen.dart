import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class ProfileEditScreen extends StatefulWidget {
  final UserProfile profile;
  final Function(UserProfile) onSaved;

  const ProfileEditScreen({
    super.key,
    required this.profile,
    required this.onSaved,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameController;
  late int _age;
  late Sex _sex;
  late double _weight;
  late double _height;
  int? _restingHr;
  late FitnessLevel _fitnessLevel;
  late UserRole _role;
  String _hrMaxFormula = 'auto'; // auto=sex-based, tanaka, fox, custom
  int? _customHrMax;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _age = widget.profile.age;
    _sex = widget.profile.sex;
    _weight = widget.profile.weightKg;
    _height = widget.profile.heightCm;
    _restingHr = widget.profile.restingHr;
    _fitnessLevel = widget.profile.fitnessLevel;
    _role = widget.profile.role;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int _previewHrMax() {
    if (_hrMaxFormula == 'custom' && _customHrMax != null) return _customHrMax!;
    if (_hrMaxFormula == 'tanaka') return (208 - 0.7 * _age).round(); // Tanaka universal
    if (_hrMaxFormula == 'fox') return (220 - _age); // Fox
    // auto = sex-based (Tanaka for male, Gulati for female)
    return _sex == Sex.female
        ? (206 - (0.88 * _age)).round()
        : (208 - (0.7 * _age)).round();
  }

  Future<void> _save() async {
    final updated = UserProfile(
      id: widget.profile.id,
      name: _nameController.text.isEmpty ? 'Athlete' : _nameController.text,
      age: _age,
      sex: _sex,
      weightKg: _weight,
      heightCm: _height,
      restingHr: _restingHr,
      fitnessLevel: _fitnessLevel,
      role: _role,
      manualHrMax: widget.profile.manualHrMax,
    );
    await StorageService.saveProfile(updated);
    widget.onSaved(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: AppTheme.body(color: AppTheme.accent, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HRmax preview card
            Container(
              width: double.infinity,
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
                      Text('Estimated HRmax',
                          style: AppTheme.body(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 2),
                      Text('${_previewHrMax()} BPM',
                          style: AppTheme.heading(fontSize: 26)),
                    ],
                  ),
                ],
              ),
            ),
            // 9.3 — HRmax Formula picker
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text('Formula',
                      style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _hrMaxFormula,
                    dropdownColor: AppTheme.surface,
                    style: AppTheme.mono(fontSize: 12, color: AppTheme.accent),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('Auto (Sex-Based)')),
                      DropdownMenuItem(value: 'tanaka', child: Text('Tanaka (208-0.7×age)')),
                      DropdownMenuItem(value: 'fox', child: Text('Fox (220-age)')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom')),
                    ],
                    onChanged: (v) => setState(() => _hrMaxFormula = v ?? 'auto'),
                  ),
                ],
              ),
            ),
            if (_hrMaxFormula == 'custom') ...[
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => _customHrMax = int.tryParse(v)),
                style: AppTheme.body(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter max HR (e.g. 185)',
                  hintStyle: AppTheme.body(color: AppTheme.textMuted, fontSize: 14),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),

            // Name
            _label('Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: AppTheme.body(color: Colors.white, fontSize: 18),
              decoration: _inputDeco('Your name'),
            ),
            const SizedBox(height: 24),

            // Age
            _label('Age: $_age years'),
            SliderTheme(
              data: _sliderTheme,
              child: Slider(
                value: _age.toDouble(),
                min: 14, max: 80, divisions: 66,
                onChanged: (v) => setState(() => _age = v.round()),
              ),
            ),
            const SizedBox(height: 16),

            // Sex
            _label('Sex'),
            const SizedBox(height: 8),
            Row(
              children: Sex.values.map((sex) {
                final sel = sex == _sex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _sex = sex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: sel ? LinearGradient(
                          colors: [
                            AppTheme.accent.withValues(alpha: 0.2),
                            AppTheme.accent.withValues(alpha: 0.08),
                          ],
                        ) : null,
                        color: sel ? null : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? AppTheme.accent : AppTheme.surfaceLight,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(sex.displayName,
                          textAlign: TextAlign.center,
                          style: AppTheme.body(
                            color: sel ? AppTheme.accent : AppTheme.textSecondary,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Weight
            _label('Weight: ${_weight.toStringAsFixed(1)} kg'),
            SliderTheme(
              data: _sliderTheme,
              child: Slider(
                value: _weight,
                min: 40, max: 160, divisions: 240,
                onChanged: (v) => setState(() => _weight = (v * 2).round() / 2),
              ),
            ),
            const SizedBox(height: 16),

            // Height
            _label('Height: ${_height.round()} cm'),
            SliderTheme(
              data: _sliderTheme,
              child: Slider(
                value: _height,
                min: 140, max: 220, divisions: 80,
                onChanged: (v) => setState(() => _height = v.roundToDouble()),
              ),
            ),
            const SizedBox(height: 24),

            // Fitness Level
            _label('Fitness Level'),
            const SizedBox(height: 12),
            ...FitnessLevel.values.map((level) {
              final sel = level == _fitnessLevel;
              return GestureDetector(
                onTap: () => setState(() => _fitnessLevel = level),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: sel ? LinearGradient(
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.15),
                        AppTheme.accent.withValues(alpha: 0.05),
                      ],
                    ) : null,
                    color: sel ? null : AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.surfaceLight,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(level.displayName,
                                style: AppTheme.body(
                                  fontSize: 16, fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : AppTheme.textSecondary,
                                )),
                            const SizedBox(height: 2),
                            Text(level.description,
                                style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      if (sel) Icon(Icons.check_circle, color: AppTheme.accent, size: 22),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            // Role
            _label('Role'),
            const SizedBox(height: 8),
            Row(
              children: UserRole.values.map((role) {
                final sel = role == _role;
                final color = role == UserRole.trainer
                    ? const Color(0xFF22C55E) : AppTheme.accent;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _role = role),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: sel ? LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.2),
                            color.withValues(alpha: 0.08),
                          ],
                        ) : null,
                        color: sel ? null : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? color : AppTheme.surfaceLight,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(role.displayName,
                          textAlign: TextAlign.center,
                          style: AppTheme.body(
                            color: sel ? color : AppTheme.textSecondary,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                          )),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: AppTheme.body(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500));

  SliderThemeData get _sliderTheme => SliderThemeData(
        activeTrackColor: AppTheme.accent,
        inactiveTrackColor: AppTheme.surfaceLight,
        thumbColor: AppTheme.accent,
        overlayColor: AppTheme.accent.withValues(alpha: 0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.body(color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
