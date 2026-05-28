import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../services/mock_data.dart';
import '../widgets/adaptive_grid.dart';
import '../widgets/beat_button.dart';
import '../widgets/floating_pills.dart';
import '../widgets/participant_card.dart';
import '../widgets/session_status_banner.dart';

/// Trainer session control panel — full-bleed adaptive grid with floating
/// pills overlaid, plus Skip/End controls at the bottom.
class TrainerMonitorScreen extends StatefulWidget {
  const TrainerMonitorScreen({super.key});

  @override
  State<TrainerMonitorScreen> createState() => _TrainerMonitorScreenState();
}

class _TrainerMonitorScreenState extends State<TrainerMonitorScreen> {
  Timer? _tick;
  final _stopwatch = Stopwatch();
  final _rng = math.Random();
  final Map<String, int> _liveBpm = {};
  SessionPhase _phase = SessionPhase.work;
  int _phaseRemainingSec = 45;
  int _round = 3;
  final int _totalRounds = 8;
  String _sortBy = 'Rank';

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

  void _showQrModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _InviteSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hrMax = MockData.athleteProfile.hrMax;
    final participantsSorted = [...MockData.liveSession];
    if (_sortBy == 'BPM') {
      participantsSorted.sort(
          (a, b) => (_liveBpm[b.id] ?? 0).compareTo(_liveBpm[a.id] ?? 0));
    }
    final avgBpm = _liveBpm.isEmpty
        ? 0
        : _liveBpm.values.reduce((a, b) => a + b) ~/ _liveBpm.length;
    final inZ4Plus =
        _liveBpm.values.where((b) => b / hrMax >= 0.8).length;

    return Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Full-bleed adaptive grid (leave top/bottom margin for pills + controls) ──
            Positioned.fill(
              child: AdaptiveTileGrid(
                count: participantsSorted.length,
                padding: const EdgeInsets.fromLTRB(12, 76, 12, 84),
                gap: 8,
                tileBuilder: (context, i) {
                  final p = participantsSorted[i];
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

            // ── Top-left: back arrow + session title pill ──
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
                    sessionName: 'Friday HIIT 18:00',
                    subtitle:
                        '${participantsSorted.length} athletes · ${_formatDuration(_stopwatch.elapsed)}',
                  ),
                ],
              ),
            ),

            // ── Top-right: phase pill + QR + sort toggle ──
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                children: [
                  // Sort toggle inline pill
                  GlassPill(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in const ['Rank', 'BPM']) ...[
                          GestureDetector(
                            onTap: () => setState(() => _sortBy = s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _sortBy == s
                                    ? AppColors.brandRed.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                s,
                                style: AppTheme.caption(
                                  color: _sortBy == s
                                      ? AppColors.brandRed
                                      : AppColors.darkTextSecondary,
                                ).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          if (s != 'BPM') const SizedBox(width: 2),
                        ],
                      ],
                    ),
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

            // ── Bottom-right: group stats pill ──
            Positioned(
              bottom: 76,
              right: 16,
              child: GroupStatsPill(
                avgBpm: avgBpm,
                inZ4Plus: inZ4Plus,
                totalAthletes: participantsSorted.length,
                elapsed: _formatDuration(_stopwatch.elapsed),
              ),
            ),

            // ── Bottom: Skip / End controls ──
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Athletes join with this code',
            style: AppTheme.h2(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.darkBgPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 160,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '4 7 9 3 2 1',
                    style: AppTheme.statNumber(
                      fontSize: 32,
                      color: AppColors.darkBgPrimary,
                    ).copyWith(letterSpacing: 6, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BeatPrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
