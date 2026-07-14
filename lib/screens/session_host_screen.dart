import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../services/auth_service.dart';
import '../services/session_repository.dart';
import '../services/session_store.dart';
import '../widgets/beat_button.dart';
import '../widgets/interval_config.dart';
import 'trainer_monitor_screen.dart';

/// "Start session" — name + optional interval timer setup.
class SessionHostScreen extends StatefulWidget {
  /// Production: the trainer's studio to host the cloud session in.
  /// Null (prototype/demo) keeps the local in-memory session.
  final String? studioId;
  const SessionHostScreen({super.key, this.studioId});

  @override
  State<SessionHostScreen> createState() => _SessionHostScreenState();
}

class _SessionHostScreenState extends State<SessionHostScreen> {
  final _name = TextEditingController();
  bool _intervals = true;
  int _workSec = 45;
  int _restSec = 15;
  int _rounds = 8;
  bool _launching = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _launch() async {
    final name = _name.text.trim().isEmpty
        ? Strings.untitledSession
        : _name.text.trim();
    final studioId = widget.studioId;
    final uid = AuthService.currentUid;

    if (studioId == null || uid == null) {
      // Demo: persist in the in-memory store so trainer home + recent
      // sessions update when we come back.
      SessionStore.instance.startLive(
        name: name,
        workSec: _intervals ? _workSec : 0,
        restSec: _intervals ? _restSec : 0,
        rounds: _intervals ? _rounds : 1,
      );
      // push (not replace) so the monitor's lobby Back returns here to
      // reconfigure until the workout is actually started.
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TrainerMonitorScreen()));
      return;
    }

    setState(() => _launching = true);
    final w = _intervals ? _workSec : 0;
    final r = _intervals ? _restSec : 0;
    final rounds = _intervals ? _rounds : 1;
    final String sessionId;
    try {
      sessionId = await SessionRepository.start(
        studioId: studioId,
        trainerUid: uid,
        name: name,
        type: 'group',
        workSec: w,
        restSec: r,
        rounds: rounds,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _launching = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(Strings.couldNotStartSession)));
      return;
    }
    if (!mounted) return;
    // Await the push so we can clear the loading state when the trainer comes
    // back from the lobby to reconfigure — otherwise Launch spins forever.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainerMonitorScreen(
          session: CloudSession(
            id: sessionId,
            studioId: studioId,
            trainerUid: uid,
            name: name,
            type: 'group',
            status: 'live',
            startedAt: DateTime.now(),
            workSec: w,
            restSec: r,
            rounds: rounds,
          ),
        ),
      ),
    );
    if (mounted) setState(() => _launching = false);
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text(Strings.startSessionTitle),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    _label(Strings.sessionNameLabel),
                    TextField(
                      controller: _name,
                      decoration: InputDecoration(
                        hintText: Strings.untitledSessionHint,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Intervals toggle
                    IntervalConfig(
                      enabled: _intervals,
                      workSec: _workSec,
                      restSec: _restSec,
                      rounds: _rounds,
                      onEnabledChanged: (v) => setState(() => _intervals = v),
                      onWorkChanged: (v) => setState(() => _workSec = v),
                      onRestChanged: (v) => setState(() => _restSec = v),
                      onRoundsChanged: (v) => setState(() => _rounds = v),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.bgTertiary,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              Strings.qrJoinHint,
                              style: AppTheme.caption(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: BeatPrimaryButton(
                  label: Strings.launchSession,
                  icon: Icons.play_arrow_rounded,
                  loading: _launching,
                  onPressed: _launch,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(
      t.toUpperCase(),
      style: AppTheme.micro(
        color: AppColors.textSecondary,
      ).copyWith(letterSpacing: 1.4),
    ),
  );
}
