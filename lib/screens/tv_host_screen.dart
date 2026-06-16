import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../models/studio.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/session_repository.dart';
import '../services/session_store.dart';
import '../services/studio_repository.dart';
import '../services/uid_name_cache.dart';
import '../widgets/adaptive_grid.dart';
import '../widgets/floating_pills.dart';
import '../widgets/invite_sheet.dart';
import '../widgets/participant_card.dart';
import '../widgets/session_status_banner.dart';

/// TV display.
///
/// **Desktop / TV**: full-bleed adaptive grid with floating pills overlaid.
/// **Mobile (< 800px)**: native Column layout — header strip, scrollable grid,
/// footer with stats. No overlap.
///
/// Production (signed in, [studioId] set): streams the studio's live cloud
/// session + hr board, with an idle screen between sessions. Demo keeps the
/// local mock simulation.
class TvHostScreen extends StatefulWidget {
  final String? studioId;
  const TvHostScreen({super.key, this.studioId});

  @override
  State<TvHostScreen> createState() => _TvHostScreenState();
}

enum _SortMode { alphabet, intensity }

class _TvHostScreenState extends State<TvHostScreen> {
  Timer? _tick;
  final _stopwatch = Stopwatch();
  final _rng = math.Random();
  final Map<String, int> _liveBpm = {};
  SessionPhase _phase = SessionPhase.work;
  int _phaseRemainingSec = 45;
  int _round = 3;
  static const _totalRounds = 8;
  int _athleteCount = 10;
  _SortMode _sort = _SortMode.alphabet;

  Stream<CloudSession?>? _liveStream;
  Stream<List<SessionHrEntry>>? _hrStream;
  String? _hrSessionId;
  final _names = UidNameCache();
  Studio? _studio;

  bool get _production => _liveStream != null;

  @override
  void initState() {
    super.initState();
    final sid = widget.studioId;
    if (AuthService.currentUid != null && sid != null) {
      _liveStream = SessionRepository.watchLive(sid);
      StudioRepository.load(sid).then((s) {
        if (mounted && s != null) setState(() => _studio = s);
      }).catchError((_) {});
    } else {
      for (final p in MockData.liveSession) {
        _liveBpm[p.id] = p.bpm;
      }
    }
    _stopwatch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 800), (_) => _step());
  }

  void _step() {
    if (!mounted) return;
    if (_production) {
      setState(() {}); // refresh the elapsed clock; data comes from streams
      return;
    }
    setState(() {
      // Demo lobby/paused: freeze the interval phase + mock BPM curve.
      final ls = SessionStore.instance.live.value;
      if (ls != null && !ls.isRunning) return;
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
      for (final p in MockData.liveSession) {
        final target = _phase == SessionPhase.work ? p.bpm : p.bpm - 25;
        final cur = _liveBpm[p.id] ?? p.bpm;
        final delta = target - cur;
        _liveBpm[p.id] = (cur + delta * 0.25 + (_rng.nextDouble() - 0.5) * 6)
            .round()
            .clamp(70, 195);
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

  /// Effective lifecycle state — cloud session in production, SessionStore in
  /// demo (defaults to running when there's no demo session in play).
  String _runStateFor(CloudSession? live) {
    if (live != null) return live.runState;
    return SessionStore.instance.live.value?.runState ?? 'running';
  }

  Duration _elapsedFor(CloudSession? live) {
    if (live != null) return live.liveElapsed;
    return SessionStore.instance.live.value?.liveElapsed ?? _stopwatch.elapsed;
  }

  Stream<List<SessionHrEntry>> _hrFor(String sessionId) {
    if (_hrSessionId != sessionId) {
      _hrSessionId = sessionId;
      _hrStream = SessionRepository.watchHr(sessionId);
    }
    return _hrStream!;
  }

  void _showQr() {
    if (!_production) {
      InviteSheet.show(context);
      return;
    }
    final code = _studio?.inviteCode;
    if (code == null) return; // studio doc still loading
    InviteSheet.show(context, code: code);
  }

  @override
  Widget build(BuildContext context) {
    final liveStream = _liveStream;
    if (liveStream == null) {
      final hrMax = MockData.athleteProfile.hrMax;
      if (_runStateFor(null) == 'lobby') return _lobby(context, null);
      final athletes = MockData.liveOf(_athleteCount)
          .map((p) => BoardAthlete(
                id: p.id,
                name: p.name,
                bpm: _liveBpm[p.id] ?? p.bpm,
                avgBpm: p.avgBpm,
                hrMax: hrMax,
              ))
          .toList();
      return _buildBoard(context, null, athletes);
    }
    return StreamBuilder<CloudSession?>(
      stream: liveStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.bgPrimary,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final live = snap.data;
        if (live == null) return _idle(context);
        if (live.isLobby) return _lobby(context, live);
        return StreamBuilder<List<SessionHrEntry>>(
          stream: _hrFor(live.id),
          builder: (context, hrSnap) {
            final entries = hrSnap.data ?? const <SessionHrEntry>[];
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
            return _buildBoard(context, live, athletes);
          },
        );
      },
    );
  }

  /// Production between sessions — calm studio splash for the wall screen.
  Widget _idle(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _studio?.name ?? 'BeatSync',
                style: AppTheme.h1().copyWith(fontSize: 36),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No live session right now — the board lights up when one starts.',
                style: AppTheme.caption(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(
    BuildContext context,
    CloudSession? live,
    List<BoardAthlete> athletes,
  ) {
    // Use the mobile/column layout up to 800px so tablets get clean stacking
    // rather than overlapping floating pills. Only true desktop / TV-cast use
    // cases (≥ 800) keep the floating-pills-over-grid look.
    final isMobile = MediaQuery.of(context).size.width < 800;
    final list = [...athletes];
    if (_sort == _SortMode.alphabet) {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else {
      list.sort((a, b) => b.bpm.compareTo(a.bpm));
    }

    final avgHr = list.isEmpty
        ? 0
        : (list.map((a) => a.bpm).reduce((a, b) => a + b) / list.length)
            .round();
    final inZ4Plus =
        list.where((a) => a.hrMax > 0 && a.bpm / a.hrMax >= 0.8).length;

    final title = live?.name ?? 'Friday HIIT 18:00';
    final studioName =
        live == null ? MockData.studioName : (_studio?.name ?? '');
    final subtitle = '$studioName · ${list.length} athletes';
    final elapsed = _formatDuration(_elapsedFor(live));
    final paused = _runStateFor(live) == 'paused';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            isMobile
                ? _buildMobile(list, avgHr, inZ4Plus, title, subtitle, elapsed)
                : _buildDesktop(list, avgHr, inZ4Plus, title, subtitle, elapsed),
            if (paused)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause_circle_filled_rounded,
                          color: AppColors.warning, size: 72),
                      const SizedBox(height: AppSpacing.md),
                      Text('PAUSED',
                          style: AppTheme.h1(color: AppColors.warning)
                              .copyWith(fontSize: 40, letterSpacing: 4)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Pre-start splash for the wall screen — invites athletes to join.
  Widget _lobby(BuildContext context, CloudSession? live) {
    final title = live?.name ?? 'Friday HIIT 18:00';
    final studioName =
        live == null ? MockData.studioName : (_studio?.name ?? '');
    final code = _production ? _studio?.inviteCode : null;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(studioName.toUpperCase(),
                  style: AppTheme.micro(color: AppColors.textSecondary)
                      .copyWith(letterSpacing: 2)),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: AppTheme.h1().copyWith(fontSize: 44)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: AppColors.brandRed, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('STARTING SOON',
                      style: AppTheme.micro(color: AppColors.brandRed).copyWith(
                          letterSpacing: 2, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Get into position — scan the code to join',
                  style: AppTheme.bodyLarge(color: AppColors.textSecondary)),
              if (code != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: AppColors.brandRed.withValues(alpha: 0.3)),
                  ),
                  child: Text(code,
                      style: AppTheme.statNumber(
                              fontSize: 40, color: AppColors.brandRed)
                          .copyWith(letterSpacing: 8)),
                ),
              ],
              if (live != null) ...[
                const SizedBox(height: AppSpacing.lg),
                StreamBuilder<List<SessionHrEntry>>(
                  stream: _hrFor(live.id),
                  builder: (context, snap) {
                    final n = snap.data?.length ?? 0;
                    return Text(
                      n == 0 ? 'Waiting for athletes…' : '$n in the room',
                      style: AppTheme.caption(color: AppColors.success),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Live grid, or a waiting hint while the cloud session has no athletes.
  Widget _grid(List<BoardAthlete> list, EdgeInsets padding) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'Waiting for athletes to join…',
          style: AppTheme.caption(),
        ),
      );
    }
    return ResponsiveParticipantGrid(
      count: list.length,
      padding: padding,
      gap: 8,
      tileBuilder: (context, i) {
        final a = list[i];
        return ParticipantCard(
          name: a.name,
          bpm: a.bpm,
          avgBpm: a.avgBpm,
          hrMax: a.hrMax,
        );
      },
    );
  }

  // ─────────── Mobile layout ───────────
  Widget _buildMobile(
    List<BoardAthlete> list,
    int avgHr,
    int inZ4Plus,
    String title,
    String subtitle,
    String elapsed,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgPrimary,
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SessionTitlePill(
                      sessionName: title,
                      subtitle: subtitle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  GlassPill(
                    padding: const EdgeInsets.all(8),
                    onTap: _showQr,
                    child: Icon(
                      Icons.qr_code_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GlassPill(
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  // Interval phases live on the trainer's device — the cloud
                  // session doesn't carry them (yet), so demo only.
                  if (!_production)
                    Expanded(
                      child: PhasePill(
                        phase: _phase,
                        remaining: Duration(seconds: _phaseRemainingSec),
                        roundLabel: 'Round $_round/$_totalRounds',
                      ),
                    )
                  else
                    const Spacer(),
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
          child: _grid(list, const EdgeInsets.all(AppSpacing.xs)),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.bgPrimary,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Center(
            child: GroupStatsPill(
              avgBpm: avgHr,
              inZ4Plus: inZ4Plus,
              totalAthletes: list.length,
              elapsed: elapsed,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────── Desktop / TV layout (floating pills over full-bleed grid) ───
  Widget _buildDesktop(
    List<BoardAthlete> list,
    int avgHr,
    int inZ4Plus,
    String title,
    String subtitle,
    String elapsed,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: _grid(list, const EdgeInsets.fromLTRB(12, 76, 12, 76)),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: SessionTitlePill(
            sessionName: title,
            subtitle: subtitle,
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
                      onTap: () =>
                          setState(() => _sort = _SortMode.intensity),
                    ),
                  ],
                ),
              ),
              // Demo-only knobs — production data comes from the streams.
              if (!_production) ...[
                const SizedBox(width: 8),
                AthleteCountPill(
                  value: _athleteCount,
                  onChanged: (v) => setState(() => _athleteCount = v),
                ),
                const SizedBox(width: 8),
                PhasePill(
                  phase: _phase,
                  remaining: Duration(seconds: _phaseRemainingSec),
                  roundLabel: 'Round $_round/$_totalRounds',
                ),
              ],
              const SizedBox(width: 8),
              GlassPill(
                padding: const EdgeInsets.all(8),
                onTap: _showQr,
                child: Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              GlassPill(
                padding: const EdgeInsets.all(8),
                onTap: () => Navigator.of(context).pop(),
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: GroupStatsPill(
            avgBpm: avgHr,
            inZ4Plus: inZ4Plus,
            totalAthletes: list.length,
            elapsed: elapsed,
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
                : AppColors.textSecondary,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}
