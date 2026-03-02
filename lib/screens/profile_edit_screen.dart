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
  late FitnessLevel _fitnessLevel;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _age = widget.profile.age;
    _sex = widget.profile.sex;
    _weight = widget.profile.weightKg;
    _height = widget.profile.heightCm;
    _fitnessLevel = widget.profile.fitnessLevel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int _previewHrMax() {
    return _sex == Sex.female
        ? (206 - (0.88 * _age)).round()
        : (208 - (0.7 * _age)).round();
  }

  Future<void> _save() async {
    final updated = UserProfile(
      name: _nameController.text.isEmpty ? 'Athlete' : _nameController.text,
      age: _age,
      sex: _sex,
      weightKg: _weight,
      heightCm: _height,
      fitnessLevel: _fitnessLevel,
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
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: TextStyle(color: AppTheme.accent, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HRmax preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
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
                      Text('Estimated HRmax',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      Text('${_previewHrMax()} BPM',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Name
            _label('Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 18),
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
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel ? AppTheme.accent : AppTheme.surfaceLight,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Text(sex.displayName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
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
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? AppTheme.accent : AppTheme.surfaceLight,
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(level.displayName,
                                style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : AppTheme.textSecondary,
                                )),
                            Text(level.description,
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      if (sel) Icon(Icons.check_circle, color: AppTheme.accent),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500));

  SliderThemeData get _sliderTheme => SliderThemeData(
        activeTrackColor: AppTheme.accent,
        inactiveTrackColor: AppTheme.surfaceLight,
        thumbColor: AppTheme.accent,
        overlayColor: AppTheme.accent.withValues(alpha: 0.2),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
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
