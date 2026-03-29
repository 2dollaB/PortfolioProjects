import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/theme.dart';
import '../models/group_session.dart';
import '../services/storage_service.dart';
import '../services/tv_server.dart';
import 'trainer_monitor_screen.dart';

class SessionHostScreen extends StatefulWidget {
  final TvServer tvServer;

  const SessionHostScreen({super.key, required this.tvServer});

  @override
  State<SessionHostScreen> createState() => _SessionHostScreenState();
}

class _SessionHostScreenState extends State<SessionHostScreen> {
  String? _ip;
  bool _starting = false;
  bool _serverRunning = false;
  String? _error;
  DateTime? _sessionStartTime;
  final _nameController = TextEditingController(text: 'HIIT Session');
  String? _sessionPin; // 10.4 — Session PIN

  @override
  void initState() {
    super.initState();
    if (widget.tvServer.isRunning) {
      _serverRunning = true;
      _loadIp();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadIp() async {
    final ip = await TvServer.getLocalIp();
    setState(() => _ip = ip);
  }

  Future<void> _startSession() async {
    setState(() { _starting = true; _error = null; });
    widget.tvServer.sessionName = _nameController.text.isEmpty
        ? 'BeatSync Session'
        : _nameController.text;

    final ip = await widget.tvServer.start();
    final now = DateTime.now();
    setState(() {
      _ip = ip;
      _starting = false;
      _serverRunning = ip != null;
      if (ip != null) {
        _sessionStartTime = now;
        _sessionPin = (1000 + Random().nextInt(9000)).toString(); // 10.4
      }
      if (ip == null) _error = 'Could not start server. Check WiFi connection.';
    });
  }

  Future<void> _stopSession() async {
    // 5.4 — save group session before stopping
    final states = widget.tvServer.userStates;
    if (states.isNotEmpty && _sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      final participants = states.values.map((u) => GroupParticipant(
        userId: u.userId,
        name: u.name,
        avgBpm: u.bpm,
        maxBpm: u.bpm,
        hrMax: u.hrMax,
        timeInZoneSeconds: const {},
      )).toList();
      final gs = GroupSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sessionName: widget.tvServer.sessionName,
        startTime: _sessionStartTime!,
        duration: duration,
        participants: participants,
      );
      await StorageService.saveGroupSession(gs);
    }
    await widget.tvServer.stop();
    setState(() { _serverRunning = false; _sessionStartTime = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Session', style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_serverRunning)
            TextButton.icon(
              onPressed: () async {
                await _stopSession();
              },
              icon: Icon(Icons.stop, color: AppTheme.danger, size: 18),
              label: Text('End', style: AppTheme.body(color: AppTheme.danger, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _serverRunning ? _buildSessionActive() : _buildSessionSetup(),
        ),
      ),
    );
  }

  // ─── SETUP VIEW ───────────────────────────────

  Widget _buildSessionSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.15),
                  AppTheme.accent.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: const Icon(Icons.groups, size: 48, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Center(child: Text('Host a Group Session', style: AppTheme.heading(fontSize: 24))),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Up to ${widget.tvServer.maxParticipants} athletes can join',
            style: AppTheme.body(fontSize: 14),
          ),
        ),
        const SizedBox(height: 32),

        // Session name
        Text('Session Name', style: AppTheme.body(
            color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: AppTheme.body(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'e.g. HIIT Monday 19h',
            hintStyle: AppTheme.body(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 32),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!,
                    style: AppTheme.body(color: AppTheme.danger, fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Start button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _starting ? null : _startSession,
            icon: _starting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow),
            label: Text(_starting ? 'Starting...' : 'Start Session',
                style: AppTheme.heading(fontSize: 18, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── ACTIVE SESSION VIEW ──────────────────────

  Widget _buildSessionActive() {
    final url = 'http://$_ip:${widget.tvServer.port}';

    return Column(
      children: [
        // Active badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.success.withValues(alpha: 0.1),
                AppTheme.success.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 10, color: AppTheme.success),
                  const SizedBox(width: 8),
                  Text('Session Active',
                      style: AppTheme.mono(color: AppTheme.success, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.tvServer.sessionName,
                style: AppTheme.heading(fontSize: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // QR Code
        Text('Scan to Join', style: AppTheme.heading(fontSize: 16)),
        const SizedBox(height: 4),
        Text('Athletes scan this QR code',
            style: AppTheme.body(fontSize: 13, color: AppTheme.textMuted)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: QrImageView(
            data: 'beatsync://$_ip:${widget.tvServer.port}',
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // 10.4 — Session PIN
        if (_sessionPin != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accent.withValues(alpha: 0.15), AppTheme.accentDark.withValues(alpha: 0.1)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text('PIN: ', style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted)),
                Text(_sessionPin!, style: AppTheme.heading(fontSize: 22, color: AppTheme.accent, letterSpacing: 4)),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Manual URL
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.boldCard(borderRadius: 12),
          child: Column(
            children: [
              Text('Or enter manually:',
                  style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 4),
              SelectableText(
                '$_ip:${widget.tvServer.port}',
                style: AppTheme.mono(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.accentLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // TV URL
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.glowCard(color: AppTheme.accent, borderRadius: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tv, size: 18, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text('TV Dashboard',
                      style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                url,
                style: AppTheme.body(fontSize: 14, color: AppTheme.accentLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Trainer Monitor button (5.1)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TrainerMonitorScreen(tvServer: widget.tvServer),
              ),
            ),
            icon: Icon(Icons.monitor_heart, color: AppTheme.accent, size: 18),
            label: Text('Open Trainer Monitor',
                style: AppTheme.body(color: AppTheme.accent, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Instructions
        _buildStep('1', 'Athletes: open BeatSync → "Join Session"'),
        _buildStep('2', 'Scan QR code or enter IP manually'),
        _buildStep('3', 'Connect HR monitor & start workout'),
        _buildStep('4', 'TV: open URL above in browser'),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.2),
                  AppTheme.accent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(number,
                  style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentLight)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTheme.body(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
