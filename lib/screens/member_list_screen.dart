import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/studio.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/studio_repository.dart';
import '../services/user_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/home_header.dart';
import '../widgets/invite_sheet.dart';
import 'member_detail_screen.dart';

class MemberListScreen extends StatefulWidget {
  /// Production: the signed-in trainer's studio to list members from.
  /// Null (prototype/demo) keeps the mock member list.
  final String? studioId;
  const MemberListScreen({super.key, this.studioId});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final _search = TextEditingController();
  String _filter = 'All';

  Stream<Studio?>? _studioStream;

  // Memoized so search-field setStates don't refetch; refreshed on uid change.
  Future<List<UserProfile>>? _membersFuture;
  List<String>? _memberUids;

  @override
  void initState() {
    super.initState();
    final sid = widget.studioId;
    if (AuthService.currentUid != null && sid != null) {
      _studioStream = StudioRepository.watch(sid);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<UserProfile>> _membersFor(List<String> uids) {
    if (_membersFuture == null || !listEquals(_memberUids, uids)) {
      _memberUids = List.of(uids);
      _membersFuture = UserRepository.loadMany(uids);
    }
    return _membersFuture!;
  }

  bool _matchesSearch(String name) {
    final q = _search.text.toLowerCase();
    return q.isEmpty || name.toLowerCase().contains(q);
  }

  void _showDemoInviteSheet() {
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
              'Share this code or QR — they enter it in the app.',
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
    final stream = _studioStream;
    if (stream == null) return _buildDemo(context);
    return StreamBuilder<Studio?>(
      stream: stream,
      builder: (context, snap) {
        final studio = snap.data;
        if (snap.hasError) {
          return _scaffold(
            context,
            count: '–',
            onInvite: null,
            body: Center(
              child: Text('Could not load your studio.',
                  style: AppTheme.caption()),
            ),
          );
        }
        if (studio == null) {
          return _scaffold(
            context,
            count: '–',
            onInvite: null,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return FutureBuilder<List<UserProfile>>(
          future: _membersFor(studio.athleteUids),
          builder: (context, msnap) {
            final members = msnap.data;
            Widget body;
            if (msnap.hasError) {
              body = Center(
                child: Text('Could not load members.',
                    style: AppTheme.caption()),
              );
            } else if (members == null) {
              body = const Center(child: CircularProgressIndicator());
            } else if (members.isEmpty) {
              body = Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    'No members yet.\nShare your invite code — athletes join with it.',
                    style: AppTheme.caption(),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            } else {
              final filtered =
                  members.where((m) => _matchesSearch(m.name)).toList();
              body = ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, 100,
                ),
                itemCount: filtered.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                // Per-member stats + detail need member workout reads — Phase D.
                itemBuilder: (context, i) => _MemberRow(
                  name: filtered[i].name,
                  subtitle: filtered[i].email,
                ),
              );
            }
            return _scaffold(
              context,
              count: members == null ? '–' : '${members.length}',
              onInvite: () =>
                  InviteSheet.show(context, code: studio.inviteCode),
              body: body,
            );
          },
        );
      },
    );
  }

  Widget _buildDemo(BuildContext context) {
    final members =
        MockData.studioMembers.where((m) => _matchesSearch(m.name)).toList();
    return _scaffold(
      context,
      count: '${MockData.studioMembers.length}',
      onInvite: _showDemoInviteSheet,
      showActivityFilters: true,
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, 100,
        ),
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, i) {
          final m = members[i];
          return _MemberRow(
            name: m.name,
            subtitle: '${m.sessions} sessions · ${m.lastSeen}',
            active: m.lastSeen.contains('Active'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MemberDetailScreen(member: m),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Shared chrome: title + count, search box, [body] below. The demo adds
  /// its activity filter chips; production hides them (no lastSeen data yet).
  Widget _scaffold(
    BuildContext context, {
    required String count,
    required VoidCallback? onInvite,
    bool showActivityFilters = false,
    required Widget body,
  }) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.darkBgPrimary,
        floatingActionButton: onInvite == null
            ? null
            : FloatingActionButton.extended(
                onPressed: onInvite,
                backgroundColor: AppColors.brandRed,
                icon: const Icon(Icons.person_add_alt_rounded,
                    color: Colors.white),
                label:
                    const Text('Invite', style: TextStyle(color: Colors.white)),
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
                    Text(count, style: AppTheme.statNumber(fontSize: 26)),
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
              if (showActivityFilters)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
              Expanded(child: body),
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
  final String name;
  final String subtitle;
  final bool active;

  /// Null disables navigation (production member detail arrives in Phase D).
  final VoidCallback? onTap;

  const _MemberRow({
    required this.name,
    required this.subtitle,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                      HomeHeader.initialsOf(name),
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
                    Text(name,
                        style: AppTheme.bodyLarge(weight: FontWeight.w600)
                            .copyWith(fontSize: 15)),
                    Text(
                      subtitle,
                      style: AppTheme.caption(
                        color: active
                            ? AppColors.success
                            : AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: AppColors.darkTextTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
