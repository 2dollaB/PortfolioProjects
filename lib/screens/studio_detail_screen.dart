import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
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
        const SnackBar(content: Text('Studio name is required.')),
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
        const SnackBar(content: Text('Studio updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave studio?'),
        content: Text(
          "You'll stop sharing workouts with ${_studio?.name ?? 'this studio'} "
          'and need an invite code to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Leave', style: TextStyle(color: AppColors.danger)),
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
        const SnackBar(content: Text('You left the studio.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not leave: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: const Text('My studio')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _studio == null
                  ? Center(
                      child: Text("Couldn't load this studio.",
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
        _label('Studio name'),
        TextField(
          controller: _name,
          decoration: const InputDecoration(hintText: 'Studio name'),
        ),
        const SizedBox(height: AppSpacing.md),
        _label('Location (optional)'),
        TextField(
          controller: _location,
          decoration: const InputDecoration(hintText: 'City, country'),
        ),
        const SizedBox(height: AppSpacing.lg),
        _label('Maximum members'),
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
          label: 'Save changes',
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
        _infoRow('Members', '${s.athleteUids.length}'),
        Divider(color: AppColors.border, height: 1),
        _infoRow('Invite code', s.inviteCode),
        const SizedBox(height: AppSpacing.xl),
        BeatSecondaryButton(
          label: 'Leave studio',
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
          Text('INVITE CODE',
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
                const SnackBar(content: Text('Invite code copied.')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy code'),
          ),
          Text('${s.athleteUids.length} members',
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
            'Up to $value',
            style: AppTheme.caption(
              color: selected ? AppColors.brandRed : AppColors.textSecondary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
