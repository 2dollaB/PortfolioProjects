import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/tv_server.dart';

class TvHostScreen extends StatefulWidget {
  final TvServer tvServer;

  const TvHostScreen({super.key, required this.tvServer});

  @override
  State<TvHostScreen> createState() => _TvHostScreenState();
}

class _TvHostScreenState extends State<TvHostScreen> {
  String? _ip;
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    if (widget.tvServer.isRunning) {
      final ip = await TvServer.getLocalIp();
      setState(() {
        _ip = ip;
        _starting = false;
      });
      return;
    }

    final ip = await widget.tvServer.start();
    setState(() {
      _ip = ip;
      _starting = false;
      if (ip == null) _error = 'Could not start server. Check WiFi connection.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = _ip != null ? 'http://$_ip:${widget.tvServer.port}' : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('TV Display', style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.tvServer.isRunning)
            TextButton.icon(
              onPressed: () async {
                final nav = Navigator.of(context);
                await widget.tvServer.stop();
                if (mounted) nav.pop();
              },
              icon: Icon(Icons.stop, color: AppTheme.danger, size: 18),
              label: Text('Stop', style: AppTheme.body(color: AppTheme.danger, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _starting
              ? Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
              : _error != null
                  ? _buildError()
                  : _buildServerInfo(url!),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.danger.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.wifi_off, size: 56, color: AppTheme.danger),
          ),
          const SizedBox(height: 20),
          Text(_error!, style: AppTheme.body(fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() { _starting = true; _error = null; });
              _startServer();
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Retry', style: AppTheme.heading(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildServerInfo(String url) {
    return Column(
      children: [
        const SizedBox(height: 16),

        // TV Icon with glow
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppTheme.accent.withValues(alpha: 0.15),
                AppTheme.accent.withValues(alpha: 0.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.tv, size: 48, color: Colors.white),
        ),
        const SizedBox(height: 24),

        Text('TV Dashboard Ready', style: AppTheme.heading(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          'Open this URL on your TV browser',
          style: AppTheme.body(fontSize: 15),
        ),
        const SizedBox(height: 32),

        // URL Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.glowCard(color: AppTheme.accent),
          child: Column(
            children: [
              SelectableText(
                url,
                style: AppTheme.heading(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Text('Same WiFi network required',
                      style: AppTheme.mono(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Instructions
        _buildStep('1', 'Make sure TV and phone are on the same WiFi'),
        _buildStep('2', 'Open the TV browser (Chrome, Samsung Internet, etc.)'),
        _buildStep('3', 'Enter the URL above'),
        _buildStep('4', "Start a workout — you'll appear on TV automatically"),

        const Spacer(),

        // Status
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.success.withValues(alpha: 0.1),
                AppTheme.success.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 10, color: AppTheme.success),
              const SizedBox(width: 10),
              Text('Server running',
                  style: AppTheme.mono(color: AppTheme.success, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
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
