import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../services/session_store.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/workout_type_sheet.dart';
import 'session_detail_screen.dart';

/// Full session history with filters. Opened from trainer home → "See all".
class AllSessionsScreen extends StatefulWidget {
  const AllSessionsScreen({super.key});

  @override
  State<AllSessionsScreen> createState() => _AllSessionsScreenState();
}

class _AllSessionsScreenState extends State<AllSessionsScreen> {
  WorkoutType? _typeFilter;
  String _timeFilter = 'All';

  String _relativeDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${d.day}/${d.month}';
  }

  List<SessionRecord> _filter(List<SessionRecord> all) {
    final now = DateTime.now();
    return all.where((r) {
      if (_typeFilter != null && r.type != _typeFilter) return false;
      switch (_timeFilter) {
        case 'This week':
          return now.difference(r.startedAt).inDays <= 7;
        case 'This month':
          return now.difference(r.startedAt).inDays <= 31;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.darkBgPrimary,
        appBar: AppBar(
          title: const Text('All sessions'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<List<SessionRecord>>(
            valueListenable: SessionStore.instance.history,
            builder: (context, sessions, _) {
              final filtered = _filter(sessions);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xs,
                      AppSpacing.xl,
                      AppSpacing.xs,
                    ),
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final f in const ['All', 'This week', 'This month'])
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.xs),
                              child: _FilterChip(
                                label: f,
                                selected: _timeFilter == f,
                                onTap: () => setState(() => _timeFilter = f),
                              ),
                            ),
                          Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            color: AppColors.darkBorder,
                          ),
                          for (final t in WorkoutType.values)
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.xs),
                              child: _FilterChip(
                                label: t.displayName,
                                selected: _typeFilter == t,
                                onTap: () => setState(() =>
                                    _typeFilter = _typeFilter == t ? null : t),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Text(
                                'No sessions match your filters.',
                                style: AppTheme.caption(),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.xs,
                              AppSpacing.xl,
                              AppSpacing.xl,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.xs),
                            itemBuilder: (context, i) =>
                                _SessionRow(record: filtered[i], formatDate: _relativeDate),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandRed.withValues(alpha: 0.15)
                : AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.darkBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.caption(
              color: selected
                  ? AppColors.brandRed
                  : AppColors.darkTextSecondary,
            ).copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SessionRecord record;
  final String Function(DateTime) formatDate;
  const _SessionRow({required this.record, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(record: record),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(record.type.icon,
                    color: AppColors.brandRed, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.name,
                      style: AppTheme.bodyLarge(weight: FontWeight.w600)
                          .copyWith(fontSize: 15),
                    ),
                    Text(
                      '${formatDate(record.startedAt)} · ${record.athleteCount} athletes · ${record.durationLabel}',
                      style: AppTheme.caption(),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${record.groupTrimp}',
                      style: AppTheme.statNumber(fontSize: 18)),
                  Text('TRIMP', style: AppTheme.micro()),
                ],
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: AppColors.darkTextTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
