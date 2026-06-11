import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../services/mock_data.dart';
import '../widgets/beat_button.dart';
import 'member_detail_screen.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final _search = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showInviteSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invite an athlete',
                style: AppTheme.h2(), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Share this code or QR â€” they enter it in the app.',
              style: AppTheme.caption(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.darkBgPrimary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.brandRed.withValues(alpha: 0.3)),
              ),
              child: Text(
                'PULSE-9214',
                textAlign: TextAlign.center,
                style: AppTheme.statNumber(
                  fontSize: 28,
                  color: AppColors.brandRed,
                ).copyWith(letterSpacing: 4, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            BeatPrimaryButton(
              label: 'Share invite',
              icon: Icons.share_rounded,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = MockData.studioMembers.where((m) {
      final q = _search.text.toLowerCase();
      return q.isEmpty || m.name.toLowerCase().contains(q);
    }).toList();
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showInviteSheet,
        backgroundColor: AppColors.brandRed,
        icon: const Icon(Icons.person_add_alt_rounded, color: Colors.white),
        label: const Text('Invite', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Text('Members', style: AppTheme.h1().copyWith(fontSize: 26)),
                  const Spacer(),
                  Text('${MockData.studioMembers.length}',
                      style: AppTheme.statNumber(fontSize: 26)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.md,
              ),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search by name',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                children: [
                  for (final f in const ['All', 'Active today', 'Inactive'])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: _FilterChip(
                        label: f,
                        selected: f == _filter,
                        onTap: () => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, 100,
                ),
                itemCount: members.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) => _MemberRow(member: members[i]),
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandRed.withValues(alpha: 0.15)
                : AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.darkBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.caption(
              color: selected ? AppColors.brandRed : AppColors.darkTextSecondary,
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

class _MemberRow extends StatelessWidget {
  final MockMember member;
  const _MemberRow({required this.member});

  String get _initials {
    final parts = member.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final active = member.lastSeen.contains('Active');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MemberDetailScreen(member: member),
          ),
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandRed.withValues(alpha: 0.18),
                      border: Border.all(
                        color: AppColors.brandRed.withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials,
                      style: AppTheme.bodyLarge(color: AppColors.brandRed)
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  if (active)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.darkBgSecondary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name,
                        style: AppTheme.bodyLarge(weight: FontWeight.w600)
                            .copyWith(fontSize: 15)),
                    Text(
                      '${member.sessions} sessions · ${member.lastSeen}',
                      style: AppTheme.caption(
                        color: active
                            ? AppColors.success
                            : AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: AppColors.darkTextTertiary),
            ],
          ),
        ),
      ),
    );
  }
}