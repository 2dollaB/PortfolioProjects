import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/theme.dart';
import '../services/tv_server.dart';

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
  final _nameController = TextEditingController(text: 'HIIT Session');

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
    setState(() {
      _ip = ip;
      _starting = false;
      _serverRunning = ip != null;
      if (ip == null) _error = 'Could not start server. Check WiFi connection.';
    });
  }

  Future<void> _stopSession() async {
    await widget.tvServer.stop();
    setState(() => _serverRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Session'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_serverRunning)
            TextButton.icon(
              onPressed: () async {
                await _stopSession();
              },
              icon: const Icon(Icons.stop, color: Colors.redAccent, size: 18),
              label: const Text('End', style: TextStyle(color: Colors.redAccent)),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.groups, size: 48, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'Host a Group Session',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Up to ${widget.tvServer.maxParticipants} athletes can join',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 32),

        // Session name
        Text('Session Name',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'e.g. HIIT Monday 19h',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 32),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
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
            label: Text(_starting ? 'Starting...' : 'Start Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
        // Session info badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 10, color: Color(0xFF22C55E)),
                  SizedBox(width: 8),
                  Text('Session Active', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.tvServer.sessionName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // QR Code for participants
        const Text('Scan to Join', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Athletes scan this QR code', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: QrImageView(
            data: 'beatsync://$_ip:${widget.tvServer.port}',
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),

        // Manual URL
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text('Or enter manually:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 4),
              SelectableText(
                '$_ip:${widget.tvServer.port}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.accentLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // TV URL
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tv, size: 18, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text('TV Dashboard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                url,
                style: TextStyle(fontSize: 14, color: AppTheme.accentLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

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
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }
}
