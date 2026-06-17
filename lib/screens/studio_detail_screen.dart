import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/studio.dart';
import '../services/auth_service.dart';
import '../services/studio_repository.dart';
import '../services/user_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/mobile_frame.dart';

/// Role-aware studio screen reached from Settings → My studio.
/// The owning trainer edits name/location/capacity; a member views the studio
/// and can leave it.
class StudioDetailScreen extends StatefulWidget {
  final String studioId;
  const StudioDetailScreen({super.key, required this.studioId});

  @override
  State<StudioDetailScreen> createState() => _StudioDetailScreenState();
}

class _StudioDetailScreenState extends State<StudioDetailScreen> {
  static const _capacityOptions = [10, 20, 30, 50];

  Studio? _studio;
  bool _loading = true;
  bool _busy = false;

  final _name = TextEditingController();
  final _location = TextEditingController();
  late int _maxMembers;

  bool get _isOwner =>
      _studio != null && _studio!.ownerUid == AuthService.currentUid;

  @override
  void initState() {
    super.initState();
    StudioRepository.load(widget.studioId).then((s) {
      if (!mounted) return;
      setState(() {
        _studio = s;
        _loading = false;
        if (s != null) {
          _name.text = s.name;
          _location.text = s.location ?? '';
          _maxMembers = s.maxMembers == 0 ? 30 : s.maxMembers;
        }
      });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.studioNameRequired)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await StudioRepository.update(
        studioId: widget.studioId,
        name: _name.text.trim(),
        location:
            _location.text.trim().isEmpty ? null : _location.text.trim(),
        maxMembers: _maxMembers,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.pick('Studio updated.', 'Studio ažuriran.'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.pick('Could not save: $e', 'Spremanje nije uspjelo: $e'))),
      );
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Strings.pick('Leave studio?', 'Napustiti studio?')),
        content: Text(
          Strings.pick(
            "You'll stop sharing workouts with ${_studio?.name ?? 'this studio'} "
                'and need an invite code to rejoin.',
            'Prestat ćete dijeliti treninge sa ${_studio?.name ?? 'ovim studijem'} '
                'i trebat će vam pozivni kod za ponovno pridruživanje.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(Strings.leave, style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final uid = AuthService.currentUid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await StudioRepository.leave(uid: uid, studioId: widget.studioId);
      await UserRepository.clearStudioId(uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.pick('You left the studio.', 'Napustili ste studio.'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.pick('Could not leave: $e', 'Napuštanje nije uspjelo: $e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: Text(Strings.myStudio)),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _studio == null
                  ? Center(
                      child: Text(Strings.couldNotLoadStudio,
                          style: AppTheme.bodyLarge(
                              color: AppColors.textSecondary)),
                    )
                  : _isOwner
                      ? _buildOwner()
                      : _buildMember(),
        ),
      ),
    );
  }

  // ── Trainer (owner) — editable ───────────────────────────────
  Widget _buildOwner() {
    final s = _studio!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
      ),
      children: [
        _inviteCard(s),
        const SizedBox(height: AppSpacing.lg),
        _label(Strings.studioName),
        TextField(
          controller: _name,
          decoration: InputDecoration(hintText: Strings.studioName),
        ),
        const SizedBox(height: AppSpacing.md),
        _label(Strings.locationOptional),
        TextField(
          controller: _location,
          decoration: InputDecoration(
              hintText: Strings.pick('City, country', 'Grad, država')),
        ),
        const SizedBox(height: AppSpacing.lg),
        _label(Strings.maxMembers),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final cap in {..._capacityOptions, _maxMembers}.toList()..sort())
              _CapacityChip(
                value: cap,
                selected: _maxMembers == cap,
                onTap: () => setState(() => _maxMembers = cap),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        BeatPrimaryButton(
          label: Strings.pick('Save changes', 'Spremi promjene'),
          icon: Icons.check_rounded,
          loading: _busy,
          onPressed: _save,
        ),
      ],
    );
  }

  // ── Member (athlete) — read-only + leave ─────────────────────
  Widget _buildMember() {
    final s = _studio!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
      ),
      children: [
        Text(s.name, style: AppTheme.h1()),
        if ((s.location ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.micro),
              Text(s.location!, style: AppTheme.bodyLarge(
                  color: AppColors.textSecondary)),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _infoRow(Strings.members, '${s.athleteUids.length}'),
        Divider(color: AppColors.border, height: 1),
        _infoRow(Strings.pick('Invite code', 'Pozivni kod'), s.inviteCode),
        const SizedBox(height: AppSpacing.xl),
        BeatSecondaryButton(
          label: Strings.pick('Leave studio', 'Napusti studio'),
          icon: Icons.logout_rounded,
          onPressed: _busy ? null : _leave,
        ),
      ],
    );
  }

  Widget _inviteCard(Studio s) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(Strings.inviteCode,
              style: AppTheme.micro().copyWith(letterSpacing: 1.6)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            s.inviteCode.split('').join(' '),
            style: AppTheme.statNumber(fontSize: 32, color: AppColors.brandRed)
                .copyWith(letterSpacing: 6),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: s.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(Strings.pick('Invite code copied.', 'Pozivni kod kopiran.'))),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(Strings.pick('Copy code', 'Kopiraj kod')),
          ),
          Text(Strings.pick('${s.athleteUids.length} members', '${s.athleteUids.length} članova'),
              style: AppTheme.caption()),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTheme.bodyLarge())),
            Text(value, style: AppTheme.caption()),
          ],
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          t.toUpperCase(),
          style: AppTheme.micro(color: AppColors.textSecondary)
              .copyWith(letterSpacing: 1.4),
        ),
      );
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
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandRed.withValues(alpha: 0.18)
                : AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            '${Strings.upToPrefix}$value',
            style: AppTheme.caption(
              color: selected ? AppColors.brandRed : AppColors.textSecondary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
