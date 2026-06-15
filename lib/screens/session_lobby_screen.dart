import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/session_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/workout_type_sheet.dart';
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

  @override
  void initState() {
    super.initState();
    // Mark "ready" presence (bpm 0) so the trainer sees us in the lobby.
    final uid = AuthService.currentUid;
    if (uid != null) {
      SessionRepository.writeHr(
        sessionId: widget.session.id,
        uid: uid,
        bpm: 0,
        avgBpm: 0,
        zone: 0,
        hrMax: widget.profile.hrMax,
      ).catchError((_) {});
    }
    _stream = SessionRepository.watch(widget.session.id);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You were removed from the session.')),
      );
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
            workoutType: WorkoutType.values.firstWhere(
              (t) => t.name == s.type,
              orElse: () => WorkoutType.hiit,
            ),
          ),
        ),
      );
    }
  }

  void _removePresence() {
    final uid = AuthService.currentUid;
    if (uid != null) {
      SessionRepository.removeHr(sessionId: widget.session.id, uid: uid)
          .catchError((_) {});
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
        backgroundColor: AppColors.darkBgPrimary,
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
                      'Waiting for your trainer to start…',
                      style: AppTheme.h2(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${session.name} · ${session.typeLabel}',
                      style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (snap.hasError)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md),
                        child: Text(
                          'Connection issue: ${snap.error}',
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
                            n == 1 ? "You're in the room" : '$n in the room',
                            style: AppTheme.caption(color: AppColors.success),
                          );
                        },
                      ),
                    const Spacer(),
                    BeatSecondaryButton(
                      label: 'Leave',
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
