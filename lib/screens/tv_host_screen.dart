import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/mock_data.dart';
import '../widgets/adaptive_grid.dart';
import '../widgets/floating_pills.dart';
import '../widgets/participant_card.dart';
import '../widgets/session_status_banner.dart';

/// TV display — full-bleed adaptive grid with floating pills overlaid.
/// Designed to be cast onto a TV in the studio.
class TvHostScreen extends StatefulWidget {
  const TvHostScreen({super.key});

  @override
  State<TvHostScreen> createState() => _TvHostScreenState();
}

class _TvHostScreenState extends State<TvHostScreen> {
  Timer? _tick;
  final _stopwatch = Stopwatch();
  final _rng = math.Random();
  final Map<String, int> _liveBpm = {};
  SessionPhase _phase = SessionPhase.work;
  int _phaseRemainingSec = 45;
  int _round = 3;
  static const _totalRounds = 8;

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
    final hrMax = MockData.athleteProfile.hrMax;
    final ranked = [...MockData.liveSession];
    ranked.sort(
        (a, b) => (_liveBpm[b.id] ?? 0).compareTo(_liveBpm[a.id] ?? 0));

    final avgHr = _liveBpm.isEmpty
        ? 0
        : (_liveBpm.values.reduce((a, b) => a + b) / _liveBpm.length).round();
    final inZ4Plus =
        _liveBpm.values.where((b) => b / hrMax >= 0.8).length;

    return Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Full-bleed adaptive grid ──
            Positioned.fill(
              child: AdaptiveTileGrid(
                count: ranked.length,
                padding: const EdgeInsets.fromLTRB(12, 76, 12, 76),
                gap: 8,
                tileBuilder: (context, i) {
                  final p = ranked[i];
                  return ParticipantCard(
                    name: p.name,
                    bpm: _liveBpm[p.id] ?? p.bpm,
                    avgBpm: p.avgBpm,
                    hrMax: hrMax,
                    rank: i + 1,
                  );
                },
              ),
            ),

            // ── Top-left: session title pill ──
            Positioned(
              top: 16,
              left: 16,
              child: SessionTitlePill(
                sessionName: 'Friday HIIT 18:00',
                subtitle:
                    '${MockData.studioName} · ${ranked.length} athletes',
              ),
            ),

            // ── Top-right: phase + timer + close ──
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  PhasePill(
                    phase: _phase,
                    remaining: Duration(seconds: _phaseRemainingSec),
                    roundLabel: 'Round $_round/$_totalRounds',
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

            // ── Bottom-right: group stats pill ──
            Positioned(
              bottom: 16,
              right: 16,
              child: GroupStatsPill(
                avgBpm: avgHr,
                inZ4Plus: inZ4Plus,
                totalAthletes: ranked.length,
                elapsed: _formatDuration(_stopwatch.elapsed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
