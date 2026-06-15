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
import 'cloud_session_detail_screen.dart';
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
  int _phaseRemainingSec = 0;
  int _round = 1;
  bool _phaseDone = false; // all rounds finished — stop the interval timer
  bool _completing = false; // ending/navigating to results (once-only guard)
  _SortMode _sort = _SortMode.alphabet;
  int _athleteCount = 10;

  Stream<List<SessionHrEntry>>? _hrStream;
  final _names = UidNameCache();
  String? _inviteCode;

  /// Live session doc (production) — drives runState/elapsed. Starts from the
  /// constructor snapshot, then tracks the Firestore stream.
  CloudSession? _session;
  StreamSubscription<CloudSession?>? _sessionSub;

  /// Locally-hidden athletes (demo kick; production kicks remove themselves).
  final Set<String> _kicked = {};

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _session = s;
    if (s == null) {
      _seedBpm();
    } else {
      _hrStream = SessionRepository.watchHr(s.id);
      _sessionSub = SessionRepository.watch(s.id).listen((sess) {
        if (mounted && sess != null) setState(() => _session = sess);
      });
      StudioRepository.load(s.studioId).then((studio) {
        if (mounted && studio != null) {
          setState(() => _inviteCode = studio.inviteCode);
        }
      }).catchError((_) {});
    }
    _stopwatch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 800), (_) => _step());
  }

  /// Effective lifecycle state across both modes.
  String get _runState => widget.session == null
      ? (SessionStore.instance.live.value?.runState ?? 'running')
      : (_session?.runState ?? 'lobby');

  bool get _isRunning => _runState == 'running';

  // Interval-timer config — from the cloud session (production) or the demo
  // SessionStore. workSec == 0 means no interval timer was set.
  int get _cfgWork => widget.session == null
      ? (SessionStore.instance.live.value?.workSec ?? 0)
      : (_session?.workSec ?? 0);
  int get _cfgRest => widget.session == null
      ? (SessionStore.instance.live.value?.restSec ?? 0)
      : (_session?.restSec ?? 0);
  int get _cfgRounds => widget.session == null
      ? (SessionStore.instance.live.value?.rounds ?? 1)
      : (_session?.rounds ?? 1);
  bool get _hasIntervals => _cfgWork > 0;
  String get _roundLabel =>
      _phaseDone ? 'Complete' : 'Round $_round/$_cfgRounds';

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onStart() async {
    // Reset the interval timer to round 1 / work phase from the config.
    setState(() {
      _phase = SessionPhase.work;
      _round = 1;
      _phaseDone = false;
      _phaseRemainingSec = _cfgWork;
    });
    final s = widget.session;
    if (s == null) {
      SessionStore.instance.beginLive();
      setState(() {});
      return;
    }
    try {
      await SessionRepository.beginWorkout(s.id);
    } catch (_) {
      _snack('Could not start the workout. Try again.');
    }
  }

  Future<void> _onPause() async {
    final s = widget.session;
    if (s == null) {
      SessionStore.instance.pauseLive();
      setState(() {});
      return;
    }
    final sess = _session;
    if (sess == null) return;
    final acc = sess.accumulatedMs +
        (sess.runningSince == null
            ? 0
            : DateTime.now().difference(sess.runningSince!).inMilliseconds);
    try {
      await SessionRepository.pause(s.id, accumulatedMs: acc);
    } catch (_) {
      _snack('Could not pause. Try again.');
    }
  }

  Future<void> _onResume() async {
    final s = widget.session;
    if (s == null) {
      SessionStore.instance.resumeLive();
      setState(() {});
      return;
    }
    try {
      await SessionRepository.resume(s.id);
    } catch (_) {
      _snack('Could not resume. Try again.');
    }
  }

  Future<void> _onKick(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        title: Text('Remove $name?'),
        content: Text(
          "They'll be dropped from the session and can't rejoin it.",
          style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.brandRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _kicked.add(id));
    if (widget.session != null) {
      try {
        await SessionRepository.kick(widget.session!.id, id);
      } catch (_) {
        _snack('Could not remove athlete. Try again.');
      }
    }
  }

  /// Pause-aware workout clock from the (cloud or demo) session lifecycle —
  /// 00:00 in the lobby, frozen while paused, survives reopening the monitor.
  Duration get _elapsed => widget.session == null
      ? (SessionStore.instance.live.value?.liveElapsed ?? Duration.zero)
      : (_session?.liveElapsed ?? Duration.zero);


  void _seedBpm() {
    for (final p in MockData.liveSession) {
      _liveBpm.putIfAbsent(p.id, () => p.bpm);
    }
  }

  void _step() {
    if (!mounted) return;
    setState(() {
      // Lobby/paused: rebuild only to refresh the clock; don't advance the
      // interval phase or the demo BPM curve.
      if (!_isRunning) return;
      if (_hasIntervals && !_phaseDone) {
        if (_phaseRemainingSec > 0) {
          _phaseRemainingSec--;
        } else if (_phase == SessionPhase.work) {
          // Rest only sits *between* rounds. After the final round's work the
          // workout is complete — no trailing rest.
          if (_round >= _cfgRounds) {
            _phaseDone = true;
          } else if (_cfgRest > 0) {
            _phase = SessionPhase.rest;
            _phaseRemainingSec = _cfgRest;
          } else {
            // No rest configured → straight to the next round's work.
            _phase = SessionPhase.work;
            _phaseRemainingSec = _cfgWork;
            _round++;
          }
        } else {
          // Rest finished → next round's work.
          _phase = SessionPhase.work;
          _phaseRemainingSec = _cfgWork;
          _round++;
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
    // Interval block finished naturally → auto-end into the results screen.
    if (_phaseDone && !_completing) {
      _endAndShowResults();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sessionSub?.cancel();
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
          .where((a) => !_kicked.contains(a.id))
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
            .where((a) => !_kicked.contains(a.id))
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
        child: _runState == 'lobby'
            ? _buildLobby(context, sorted)
            : (isMobile
                ? _buildMobile(sorted, avgBpm, inZ4Plus)
                : _buildDesktop(sorted, avgBpm, inZ4Plus)),
      ),
    );
  }

  // ─────────── Lobby — waiting room before the workout starts ──────────
  Widget _buildLobby(BuildContext context, List<BoardAthlete> athletes) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.darkBgPrimary,
            border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
          ),
          child: Row(
            children: [
              GlassPill(
                padding: const EdgeInsets.all(8),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.darkTextPrimary, size: 20),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_sessionName,
                        style: AppTheme.bodyLarge(weight: FontWeight.w700)
                            .copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('Lobby · waiting to start', style: AppTheme.micro()),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              GlassPill(
                padding: const EdgeInsets.all(8),
                onTap: _showQrModal,
                child: const Icon(Icons.qr_code_rounded,
                    color: AppColors.darkTextPrimary, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xs,
          ),
          child: Row(
            children: [
              Text('In the room', style: AppTheme.h2()),
              const Spacer(),
              Text('${athletes.length}', style: AppTheme.statNumber(fontSize: 22)),
            ],
          ),
        ),
        Expanded(
          child: athletes.isEmpty
              ? Center(
                  child: Text(
                    'Waiting for athletes to join…\nShare the QR / invite code.',
                    style: AppTheme.caption(),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.md,
                  ),
                  itemCount: athletes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) =>
                      _LobbyRow(athlete: athletes[i], onKick: _onKick),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.darkBgPrimary,
            border: Border(top: BorderSide(color: AppColors.darkBorder)),
          ),
          child: BeatPrimaryButton(
            label: 'Start training',
            icon: Icons.play_arrow_rounded,
            onPressed: _onStart,
          ),
        ),
      ],
    );
  }

  /// Footer controls during a running/paused workout (shared by both layouts).
  Widget _footer() {
    final paused = _runState == 'paused';
    return Row(
      children: [
        // Skip the current work/rest phase (interval timer only).
        if (_isRunning && _hasIntervals && !_phaseDone) ...[
          Expanded(
            child: BeatSecondaryButton(
              label: 'Skip',
              icon: Icons.skip_next_rounded,
              onPressed: () => setState(() => _phaseRemainingSec = 0),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        // No Pause once the workout is complete — it's wrapping up to results.
        if (!_phaseDone) ...[
          Expanded(
            child: paused
                ? BeatPrimaryButton(
                    label: 'Resume',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _onResume,
                  )
                : BeatSecondaryButton(
                    label: 'Pause',
                    icon: Icons.pause_rounded,
                    onPressed: _onPause,
                  ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: BeatPrimaryButton(
            label: 'End',
            icon: Icons.stop_rounded,
            onPressed: _onEndSession,
          ),
        ),
      ],
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        title: const Text('End session?'),
        content: Text(
          'This ends the workout for everyone and shows the results.',
          style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.brandRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _endAndShowResults();
  }

  /// Ends the session and hands off to the results screen — used by both the
  /// manual End button and natural completion (all rounds finished). Replaces
  /// the dead monitor so the results screen's Back goes home.
  Future<void> _endAndShowResults() async {
    if (_completing) return;
    _completing = true;
    final s = widget.session;
    if (s == null) {
      final record = SessionStore.instance.endLive();
      if (!mounted) return;
      if (record != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(record: record),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
    try {
      await SessionRepository.end(s.id);
    } catch (_) {
      _completing = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not end the session. Try again.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CloudSessionDetailScreen(session: s),
      ),
    );
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
                  if (_hasIntervals) ...[
                    Expanded(
                      child: PhasePill(
                        phase: _phase,
                        remaining: Duration(seconds: _phaseRemainingSec),
                        roundLabel: _roundLabel,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ] else
                    const Spacer(),
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
              _footer(),
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
                    '${sorted.length} athletes · ${_formatDuration(_elapsed)}${_runState == 'paused' ? ' · Paused' : ''}',
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
              if (_hasIntervals) ...[
                const SizedBox(width: 8),
                PhasePill(
                  phase: _phase,
                  remaining: Duration(seconds: _phaseRemainingSec),
                  roundLabel: _roundLabel,
                ),
              ],
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
          child: _footer(),
        ),
      ],
    );
  }
}

/// One athlete row in the lobby — name, ready/BPM marker, and a kick button.
class _LobbyRow extends StatelessWidget {
  final BoardAthlete athlete;
  final Future<void> Function(String id, String name) onKick;
  const _LobbyRow({required this.athlete, required this.onKick});

  String get _initials {
    final n = athlete.name.trim();
    if (n.isEmpty) return '?';
    return n
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ready = athlete.bpm <= 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandRed.withValues(alpha: 0.18),
              border:
                  Border.all(color: AppColors.brandRed.withValues(alpha: 0.35)),
            ),
            child: Text(
              _initials,
              style: AppTheme.bodyLarge(color: AppColors.brandRed)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              athlete.name,
              style: AppTheme.bodyLarge(weight: FontWeight.w600)
                  .copyWith(fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            ready ? 'Ready' : '${athlete.bpm} bpm',
            style: AppTheme.caption(
              color: ready ? AppColors.success : AppColors.darkTextSecondary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_remove_alt_1_rounded, size: 20),
            color: AppColors.darkTextTertiary,
            tooltip: 'Remove',
            onPressed: () => onKick(athlete.id, athlete.name),
          ),
        ],
      ),
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

