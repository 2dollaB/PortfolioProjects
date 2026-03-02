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
        title: const Text('TV Display'),
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
              icon: const Icon(Icons.stop, color: Colors.redAccent, size: 18),
              label: const Text('Stop', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _starting
              ? const Center(child: CircularProgressIndicator())
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
          const Icon(Icons.wifi_off, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() { _starting = true; _error = null; });
              _startServer();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildServerInfo(String url) {
    return Column(
      children: [
        const SizedBox(height: 16),

        // TV Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.accent.withValues(alpha: 0.15),
          ),
          child: const Icon(Icons.tv, size: 48, color: Colors.white),
        ),
        const SizedBox(height: 24),

        const Text(
          'TV Dashboard Ready',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Open this URL on your TV browser',
          style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 32),

        // URL Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                url,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentLight,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Same WiFi network required',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Instructions
        _buildStep('1', 'Make sure TV and phone are on the same WiFi'),
        _buildStep('2', 'Open the TV browser (Chrome, Samsung Internet, etc.)'),
        _buildStep('3', 'Enter the URL above'),
        _buildStep('4', 'Start a workout — you\'ll appear on TV automatically'),

        const Spacer(),

        // Status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 10, color: Color(0xFF22C55E)),
              SizedBox(width: 10),
              Text('Server running',
                  style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }
}
