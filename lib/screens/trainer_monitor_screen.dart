import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../services/mock_data.dart';
import '../services/session_repository.dart';
import '../services/session_store.dart';
import '../services/studio_repository.dart';
import '../services/uid_name_cache.dart';
import '../widgets/adaptive_grid.dart';
import '../widgets/beat_button.dart';
import '../widgets/floating_pills.dart';
import '../widgets/invite_sheet.dart';
import '../widgets/participant_card.dart';
import '../widgets/session_status_banner.dart';
import 'session_detail_screen.dart';

/// Trainer session control panel — full-bleed adaptive grid with floating
/// pills overlaid, plus Skip/End controls at the bottom.
class TrainerMonitorScreen extends StatefulWidget {
  /// Production: the live cloud session to monitor (HR board streams from
  /// Firestore). Null (prototype/demo) runs the local mock simulation.
  final CloudSession? session;
  const TrainerMonitorScreen({super.key, this.session});

  @override
  State<TrainerMonitorScreen> createState() => _TrainerMonitorScreenState();
}

enum _SortMode { alphabet, intensity }

class _TrainerMonitorScreenState extends State<TrainerMonitorScreen> {
  Timer? _tick;
  final _stopwatch = Stopwatch();
  final _rng = math.Random();
  final Map<String, int> _liveBpm = {};
  SessionPhase _phase = SessionPhase.work;
  int _phaseRemainingSec = 45;
  int _round = 3;
  final int _totalRounds = 8;
  _SortMode _sort = _SortMode.alphabet;
  int _athleteCount = 10;

  Stream<List<SessionHrEntry>>? _hrStream;
  final _names = UidNameCache();
  String? _inviteCode;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    if (s == null) {
      _seedBpm();
    } else {
      _hrStream = SessionRepository.watchHr(s.id);
      StudioRepository.load(s.studioId).then((studio) {
        if (mounted && studio != null) {
          setState(() => _inviteCode = studio.inviteCode);
        }
      }).catchError((_) {});
    }
    _stopwatch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 800), (_) => _step());
  }

  /// Production sessions measure from the cloud start time so reopening the
  /// monitor doesn't reset the clock.
  Duration get _elapsed => widget.session == null
      ? _stopwatch.elapsed
      : DateTime.now().difference(widget.session!.startedAt);


  void _seedBpm() {
    for (final p in MockData.liveSession) {
      _liveBpm.putIfAbsent(p.id, () => p.bpm);
    }
  }

  void _step() {
    if (!mounted) return;
    setState(() {
      if (_phaseRemainingSec > 0) {
        _phaseRemainingSec--;
      } else {
        if (_phase == SessionPhase.work) {
          _phase = SessionPhase.rest;
          _phaseRemainingSec = 20;
        } else {
          _phase = SessionPhase.work;
          _phaseRemainingSec = 45;
          _round = math.min(_round + 1, _totalRounds);
        }
      }
      if (widget.session == null) {
        // Demo only — production BPM comes from the hr stream.
        for (final p in MockData.liveSession) {
          final target = _phase == SessionPhase.work ? p.bpm : p.bpm - 25;
          final cur = _liveBpm[p.id] ?? p.bpm;
          final delta = target - cur;
          _liveBpm[p.id] = (cur + delta * 0.25 + (_rng.nextDouble() - 0.5) * 6)
              .round()
              .clamp(70, 195);
        }
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  void _showQrModal() {
    if (widget.session == null) {
      InviteSheet.show(context);
      return;
    }
    final code = _inviteCode;
    if (code == null) return; // studio doc still loading
    InviteSheet.show(context, code: code);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _hrStream;
    if (stream == null) {
      final hrMax = MockData.athleteProfile.hrMax;
      final athletes = MockData.liveOf(_athleteCount)
          .map((p) => BoardAthlete(
                id: p.id,
                name: p.name,
                bpm: _liveBpm[p.id] ?? p.bpm,
                avgBpm: p.avgBpm,
                hrMax: hrMax,
              ))
          .toList();
      return _buildScaffold(context, athletes);
    }
    return StreamBuilder<List<SessionHrEntry>>(
      stream: stream,
      builder: (context, snap) {
        final entries = snap.data ?? const <SessionHrEntry>[];
        _names.ensure(entries.map((e) => e.uid), () {
          if (mounted) setState(() {});
        });
        final athletes = entries
            .map((e) => BoardAthlete(
                  id: e.uid,
                  name: _names.nameFor(e.uid),
                  bpm: e.bpm,
                  avgBpm: e.avgBpm,
                  hrMax: e.hrMax > 0 ? e.hrMax : 190,
                ))
            .toList();
        return _buildScaffold(context, athletes);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, List<BoardAthlete> athletes) {
    // Use the mobile/column layout up to 800px so tablets get clean stacking
    // rather than overlapping floating pills. Only true desktop / TV-cast use
    // cases (≥ 800) keep the floating-pills-over-grid look.
    final isMobile = MediaQuery.of(context).size.width < 800;
    final sorted = [...athletes];
    if (_sort == _SortMode.alphabet) {
      sorted.sort((a, b) => a.name.compareTo(b.name));
    } else {
      sorted.sort((a, b) => b.bpm.compareTo(a.bpm));
    }

    final avgBpm = sorted.isEmpty
        ? 0
        : sorted.map((a) => a.bpm).reduce((a, b) => a + b) ~/ sorted.length;
    final inZ4Plus =
        sorted.where((a) => a.hrMax > 0 && a.bpm / a.hrMax >= 0.8).length;

    return Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      body: SafeArea(
        child: isMobile
            ? _buildMobile(sorted, avgBpm, inZ4Plus)
            : _buildDesktop(sorted, avgBpm, inZ4Plus),
      ),
    );
  }

  String get _sessionName => widget.session?.name ?? 'Friday HIIT 18:00';

  /// Shared by both layouts: live grid, or a waiting hint while the cloud
  /// session has no athletes yet.
  Widget _grid(List<BoardAthlete> sorted, EdgeInsets padding) {
    if (sorted.isEmpty) {
      return Center(
        child: Text(
          'Waiting for athletes to join…\nShare the QR / invite code.',
          style: AppTheme.caption(),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ResponsiveParticipantGrid(
      count: sorted.length,
      padding: padding,
      gap: 8,
      tileBuilder: (context, i) {
        final a = sorted[i];
        return ParticipantCard(
          name: a.name,
          bpm: a.bpm,
          avgBpm: a.avgBpm,
          hrMax: a.hrMax,
        );
      },
    );
  }

  Future<void> _onEndSession() async {
    final s = widget.session;
    if (s == null) {
      final record = SessionStore.instance.endLive();
      Navigator.of(context).pop();
      if (record != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(record: record),
          ),
        );
      }
      return;
    }
    try {
      await SessionRepository.end(s.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not end the session. Try again.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ─────────── Mobile layout — header / scrollable grid / footer ───────
  Widget _buildMobile(
    List<BoardAthlete> sorted,
    int avgBpm,
    int inZ4Plus,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs,
          ),
          decoration: const BoxDecoration(
            color: AppColors.darkBgPrimary,
            border: Border(
              bottom: BorderSide(color: AppColors.darkBorder),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GlassPill(
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.darkTextPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: SessionTitlePill(
                      sessionName: _sessionName,
                      subtitle:
                          '${sorted.length} athletes · ${_formatDuration(_elapsed)}',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  GlassPill(
                    padding: const EdgeInsets.all(8),
                    onTap: _showQrModal,
                    child: const Icon(
                      Icons.qr_code_rounded,
                      color: AppColors.darkTextPrimary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: PhasePill(
                      phase: _phase,
                      remaining: Duration(seconds: _phaseRemainingSec),
                      roundLabel: 'Round $_round/$_totalRounds',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  GlassPill(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SortChip(
                          label: 'A-Z',
                          selected: _sort == _SortMode.alphabet,
                          onTap: () =>
                              setState(() => _sort = _SortMode.alphabet),
                        ),
                        const SizedBox(width: 2),
                        _SortChip(
                          label: 'BPM',
                          selected: _sort == _SortMode.intensity,
                          onTap: () =>
                              setState(() => _sort = _SortMode.intensity),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _grid(sorted, const EdgeInsets.all(AppSpacing.xs)),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: const BoxDecoration(
            color: AppColors.darkBgPrimary,
            border: Border(top: BorderSide(color: AppColors.darkBorder)),
          ),
          child: Column(
            children: [
              Center(
                child: GroupStatsPill(
                  avgBpm: avgBpm,
                  inZ4Plus: inZ4Plus,
                  totalAthletes: sorted.length,
                  elapsed: _formatDuration(_elapsed),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: BeatSecondaryButton(
                      label: 'Skip',
                      icon: Icons.skip_next_rounded,
                      onPressed: () => setState(() => _phaseRemainingSec = 0),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 3,
                    child: BeatPrimaryButton(
                      label: 'End session',
                      icon: Icons.stop_rounded,
                      onPressed: _onEndSession,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────── Desktop layout — floating pills over full-bleed grid ───
  Widget _buildDesktop(
    List<BoardAthlete> sorted,
    int avgBpm,
    int inZ4Plus,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: _grid(sorted, const EdgeInsets.fromLTRB(12, 76, 12, 84)),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Row(
            children: [
              GlassPill(
                padding: const EdgeInsets.all(8),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.darkTextPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              SessionTitlePill(
                sessionName: _sessionName,
                subtitle:
                    '${sorted.length} athletes · ${_formatDuration(_elapsed)}',
              ),
            ],
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            children: [
              GlassPill(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SortChip(
                      label: 'A-Z',
                      selected: _sort == _SortMode.alphabet,
                      onTap: () => setState(() => _sort = _SortMode.alphabet),
                    ),
                    const SizedBox(width: 2),
                    _SortChip(
                      label: 'Intensity',
                      selected: _sort == _SortMode.intensity,
                      onTap: () => setState(() => _sort = _SortMode.intensity),
                    ),
                  ],
                ),
              ),
              // Demo-only knob — production count comes from the hr stream.
              if (widget.session == null) ...[
                const SizedBox(width: 8),
                AthleteCountPill(
                  value: _athleteCount,
                  onChanged: (v) => setState(() => _athleteCount = v),
                ),
              ],
              const SizedBox(width: 8),
              PhasePill(
                phase: _phase,
                remaining: Duration(seconds: _phaseRemainingSec),
                roundLabel: 'Round $_round/$_totalRounds',
              ),
              const SizedBox(width: 8),
              GlassPill(
                padding: const EdgeInsets.all(8),
                onTap: _showQrModal,
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.darkTextPrimary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 76,
          right: 16,
          child: GroupStatsPill(
            avgBpm: avgBpm,
            inZ4Plus: inZ4Plus,
            totalAthletes: sorted.length,
            elapsed: _formatDuration(_elapsed),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: BeatSecondaryButton(
                  label: 'Skip',
                  icon: Icons.skip_next_rounded,
                  onPressed: () => setState(() => _phaseRemainingSec = 0),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 3,
                child: BeatPrimaryButton(
                  label: 'End session',
                  icon: Icons.stop_rounded,
                  onPressed: _onEndSession,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandRed.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTheme.caption(
            color: selected
                ? AppColors.brandRed
                : AppColors.darkTextSecondary,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

