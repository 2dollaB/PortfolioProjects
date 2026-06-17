import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/hr_zones.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../widgets/mobile_frame.dart';

/// Read-only summary of the health data BeatSync derives heart-rate zones from.
/// Editing happens in Personal info (EditProfileScreen).
class HealthDataScreen extends StatelessWidget {
  final UserProfile profile;
  const HealthDataScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final hrMax = profile.hrMax;
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: Text(Strings.healthData)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
            ),
            children: [
              Row(
                children: [
                  Expanded(child: _Stat(label: Strings.hrMax, value: '$hrMax', unit: 'bpm')),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _Stat(
                      label: Strings.restingHrLabel,
                      value: profile.restingHr?.toString() ?? '—',
                      unit: 'bpm',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: _Stat(label: Strings.age, value: '${profile.age}')),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Group(
                title: Strings.pick('Body', 'Tijelo'),
                rows: [
                  (Strings.weight, '${profile.weightKg.round()} kg'),
                  (Strings.height, '${profile.heightCm.round()} cm'),
                  (Strings.sex, Strings.sexName(profile.sex)),
                  (Strings.fitnessLevel,
                      Strings.fitnessName(profile.fitnessLevel)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(Strings.pick('HEART-RATE ZONES', 'ZONE PULSA'),
                  style: AppTheme.micro().copyWith(letterSpacing: 1.4)),
              const SizedBox(height: AppSpacing.xs),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (int z = 1; z <= 5; z++) ...[
                      _ZoneRow(zone: z, hrMax: hrMax),
                      if (z < 5)
                        Divider(color: AppColors.border, height: 1, indent: 52),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                Strings.pick(
                  'Zones are estimated from your max heart rate. Update your '
                      'details in Personal info to refine them. Not medical advice.',
                  'Zone se procjenjuju iz vašeg maksimalnog pulsa. Ažurirajte '
                      'podatke u Osobnim podacima za precizniji izračun. Nije medicinski savjet.',
                ),
                style: AppTheme.caption(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  const _Stat({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: AppTheme.statNumber(fontSize: 22)),
          if (unit != null) Text(unit!, style: AppTheme.micro()),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.micro()),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  const _Group({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: AppTheme.micro().copyWith(letterSpacing: 1.4)),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(rows[i].$1, style: AppTheme.bodyLarge()),
                      ),
                      Text(rows[i].$2, style: AppTheme.caption()),
                    ],
                  ),
                ),
                if (i < rows.length - 1)
                  Divider(color: AppColors.border, height: 1, indent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final int zone;
  final int hrMax;
  const _ZoneRow({required this.zone, required this.hrMax});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.zoneColor(zone);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Z$zone · ${Strings.zoneName(zone)}',
              style: AppTheme.bodyLarge(),
            ),
          ),
          Text(HrZones.rangeText(zone, hrMax), style: AppTheme.caption()),
        ],
      ),
    );
  }
}
