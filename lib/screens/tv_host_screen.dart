import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../services/mock_data.dart';
import '../widgets/adaptive_grid.dart';
import '../widgets/floating_pills.dart';
import '../widgets/invite_sheet.dart';
import '../widgets/participant_card.dart';
import '../widgets/session_status_banner.dart';

/// TV display.
///
/// **Desktop / TV**: full-bleed adaptive grid with floating pills overlaid.
/// **Mobile (< 500px)**: native Column layout — header strip, scrollable grid,
/// footer with stats. No overlap.
class TvHostScreen extends StatefulWidget {
  const TvHostScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    for (final p in MockData.liveSession) {
      _liveBpm[p.id] = p.bpm;
    }
    _stopwatch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 800), (_) => _step());
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

  @override
  Widget build(BuildContext context) {
    // Use the mobile/column layout up to 800px so tablets get clean stacking
    // rather than overlapping floating pills. Only true desktop / TV-cast use
    // cases (≥ 800) keep the floating-pills-over-grid look.
    final isMobile = MediaQuery.of(context).size.width < 800;
    final hrMax = MockData.athleteProfile.hrMax;
    final list = [...MockData.liveOf(_athleteCount)];
    if (_sort == _SortMode.alphabet) {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else {
      list.sort(
          (a, b) => (_liveBpm[b.id] ?? 0).compareTo(_liveBpm[a.id] ?? 0));
    }

    final avgHr = list.isEmpty
        ? 0
        : (list
                    .map((p) => _liveBpm[p.id] ?? p.bpm)
                    .reduce((a, b) => a + b) /
                list.length)
            .round();
    final inZ4Plus = list
        .where((p) => (_liveBpm[p.id] ?? p.bpm) / hrMax >= 0.8)
        .length;

    return Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      body: SafeArea(
        child: isMobile
            ? _buildMobile(list, hrMax, avgHr, inZ4Plus)
            : _buildDesktop(list, hrMax, avgHr, inZ4Plus),
      ),
    );
  }

  // ─────────── Mobile layout ───────────
  Widget _buildMobile(
    List<MockParticipant> list,
    int hrMax,
    int avgHr,
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
                  Expanded(
                    child: SessionTitlePill(
                      sessionName: 'Friday HIIT 18:00',
                      subtitle: '${MockData.studioName} · ${list.length} athletes',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  GlassPill(
                    padding: const EdgeInsets.all(8),
                    onTap: () => InviteSheet.show(context),
                    child: const Icon(
                      Icons.qr_code_rounded,
                      color: AppColors.darkTextPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GlassPill(
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close_rounded,
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
          child: ResponsiveParticipantGrid(
            count: list.length,
            padding: const EdgeInsets.all(AppSpacing.xs),
            gap: 8,
            tileBuilder: (context, i) {
              final p = list[i];
              return ParticipantCard(
                name: p.name,
                bpm: _liveBpm[p.id] ?? p.bpm,
                avgBpm: p.avgBpm,
                hrMax: hrMax,
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: const BoxDecoration(
            color: AppColors.darkBgPrimary,
            border: Border(top: BorderSide(color: AppColors.darkBorder)),
          ),
          child: Center(
            child: GroupStatsPill(
              avgBpm: avgHr,
              inZ4Plus: inZ4Plus,
              totalAthletes: list.length,
              elapsed: _formatDuration(_stopwatch.elapsed),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────── Desktop / TV layout (floating pills over full-bleed grid) ───
  Widget _buildDesktop(
    List<MockParticipant> list,
    int hrMax,
    int avgHr,
    int inZ4Plus,
  ) {
    return Stack(
      children: [
        Positioned.fill(
          child: ResponsiveParticipantGrid(
            count: list.length,
            padding: const EdgeInsets.fromLTRB(12, 76, 12, 76),
            gap: 8,
            tileBuilder: (context, i) {
              final p = list[i];
              return ParticipantCard(
                name: p.name,
                bpm: _liveBpm[p.id] ?? p.bpm,
                avgBpm: p.avgBpm,
                hrMax: hrMax,
              );
            },
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: SessionTitlePill(
            sessionName: 'Friday HIIT 18:00',
            subtitle: '${MockData.studioName} · ${list.length} athletes',
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
              const SizedBox(width: 8),
              GlassPill(
                padding: const EdgeInsets.all(8),
                onTap: () => InviteSheet.show(context),
                child: const Icon(
                  Icons.qr_code_rounded,
                  color: AppColors.darkTextPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              GlassPill(
                padding: const EdgeInsets.all(8),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.darkTextPrimary,
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
            elapsed: _formatDuration(_stopwatch.elapsed),
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
