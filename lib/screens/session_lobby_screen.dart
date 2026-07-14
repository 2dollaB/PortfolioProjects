import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../models/hr_data.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/ble_hr_service.dart';
import '../services/clock_sync.dart';
import '../services/session_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';
import '../widgets/mobile_frame.dart';
import 'workout_screen.dart';

/// Athlete waiting room (production group sessions).
///
/// On entry the athlete marks themselves "ready" so they appear on the
/// trainer's lobby board, then waits here until the trainer presses Start —
/// at which point they advance into the workout. Also reacts to being kicked
/// or to the session ending before it began.
class SessionLobbyScreen extends StatefulWidget {
  final UserProfile profile;
  final CloudSession session;
  const SessionLobbyScreen({
    super.key,
    required this.profile,
    required this.session,
  });

  @override
  State<SessionLobbyScreen> createState() => _SessionLobbyScreenState();
}

class _SessionLobbyScreenState extends State<SessionLobbyScreen> {
  late final Stream<CloudSession?> _stream;
  bool _navigated = false;

  // Real BPM ticks on the trainer's board the moment a paired strap is
  // connected — the athlete doesn't have to wait for Start to be seen as
  // more than "Ready". Falls back to the one-shot 0 ping if unpaired.
  final _useBle = !kIsWeb && BleHrService.instance.isConnected;
  HrData? _lastBle;
  StreamSubscription<HrData>? _bleSub;
  Timer? _hrTick;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.currentUid;
    if (uid != null) {
      if (_useBle) {
        _bleSub = BleHrService.instance.hrDataStream.listen((d) {
          if (mounted) setState(() => _lastBle = d);
        });
        _hrTick = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _publishHr(uid),
        );
      }
      // Mark "ready" presence (bpm 0) so the trainer sees us in the lobby
      // even before a strap is connected.
      _publishHr(uid);
      // Ahead of the Start-Training countdown, so it's accurate from the
      // first tick instead of correcting itself mid-count.
      unawaited(ClockSync.sync());
    }
    _stream = SessionRepository.watch(widget.session.id);
  }

  void _publishHr(String uid) {
    final bpm = _lastBle?.bpm ?? 0;
    SessionRepository.writeHr(
      sessionId: widget.session.id,
      uid: uid,
      name: widget.profile.name,
      bpm: bpm,
      avgBpm: bpm,
      zone: 0,
      hrMax: widget.profile.hrMax,
    ).catchError((_) {});
  }

  void _react(CloudSession? s) {
    if (_navigated || !mounted) return;
    // Null = stream still resolving or a transient read hiccup. Stay put in
    // the lobby rather than bouncing the athlete back (that looked like Join
    // doing nothing). Only an explicit kick or a real 'ended' leaves.
    if (s == null) return;
    final uid = AuthService.currentUid;
    if (uid != null && s.isKicked(uid)) {
      _navigated = true;
      _removePresence();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Strings.removedFromSession)));
      return;
    }
    if (s.status == 'ended') {
      _navigated = true;
      Navigator.of(context).pop();
      return;
    }
    // Trainer pressed Start → into the workout (synced from here on).
    if (s.isRunning) {
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutScreen(
            profile: widget.profile,
            inGroupSession: true,
            session: s,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _hrTick?.cancel();
    _bleSub?.cancel();
    super.dispose();
  }

  void _removePresence() {
    final uid = AuthService.currentUid;
    if (uid != null) {
      SessionRepository.removeHr(
        sessionId: widget.session.id,
        uid: uid,
      ).catchError((_) {});
    }
  }

  void _leave() {
    _navigated = true;
    _removePresence();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          child: StreamBuilder<CloudSession?>(
            stream: _stream,
            builder: (context, snap) {
              // Don't act on the initial (still-loading) null — only a real
              // emission tells us the session is gone/ended/running/kicked.
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final s = snap.data;
              // React to lifecycle changes after the frame (can't navigate mid-build).
              WidgetsBinding.instance.addPostFrameCallback((_) => _react(s));
              final session = s ?? widget.session;
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _leave,
                      ),
                    ),
                    const Spacer(),
                    const LogoHeartbeat(size: 40, showWordmark: false),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      Strings.waitingForTrainer,
                      style: AppTheme.h2(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      session.name,
                      style: AppTheme.bodyLarge(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    if (_useBle) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _MyHrCard(bpm: _lastBle?.bpm),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    if (snap.hasError)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          Strings.connectionIssue(snap.error ?? ''),
                          style: AppTheme.caption(color: AppColors.danger),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      StreamBuilder<List<SessionHrEntry>>(
                        stream: SessionRepository.watchHr(widget.session.id),
                        builder: (context, hrSnap) {
                          final n = hrSnap.data?.length ?? 1;
                          return Text(
                            n == 1
                                ? Strings.youreInTheRoom
                                : Strings.nInTheRoom(n),
                            style: AppTheme.caption(color: AppColors.success),
                          );
                        },
                      ),
                    const Spacer(),
                    BeatSecondaryButton(
                      label: Strings.leave,
                      icon: Icons.logout_rounded,
                      onPressed: _leave,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The athlete's own live heart rate while they wait in the lobby — a
/// reassuring "your strap is working" signal before the workout starts.
class _MyHrCard extends StatelessWidget {
  final int? bpm;
  const _MyHrCard({required this.bpm});

  @override
  Widget build(BuildContext context) {
    final hasReading = bpm != null && bpm! > 0;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.brandRed.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Strings.yourHeartRate,
            style: AppTheme.micro(
              color: AppColors.textSecondary,
            ).copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: AppColors.brandRed,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                hasReading ? '$bpm' : '––',
                style: AppTheme.statNumber(
                  fontSize: 44,
                  color: AppColors.brandRed,
                ),
              ),
              const SizedBox(width: 4),
              Text('bpm', style: AppTheme.caption()),
            ],
          ),
          if (!hasReading) ...[
            const SizedBox(height: 2),
            Text(
              Strings.waitingFirstBeat,
              style: AppTheme.caption(color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
