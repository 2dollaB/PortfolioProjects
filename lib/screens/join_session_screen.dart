import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../config/theme.dart';
import '../services/session_client.dart';

class JoinSessionScreen extends StatefulWidget {
  final SessionClient sessionClient;

  const JoinSessionScreen({super.key, required this.sessionClient});

  @override
  State<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends State<JoinSessionScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connectManual() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8080;

    if (ip.isEmpty) {
      setState(() => _error = 'Enter the hub IP address');
      return;
    }

    await _doConnect(ip, port);
  }

  Future<void> _doConnect(String ip, int port) async {
    setState(() { _connecting = true; _error = null; });

    final success = await widget.sessionClient.connect(ip, port);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _connecting = false;
          _error = 'Could not connect to $ip:$port. Make sure you are on the same WiFi.';
        });
      }
    }
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_connecting) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final raw = barcode.rawValue!;
    // Expected format: beatsync://192.168.x.x:8080
    if (raw.startsWith('beatsync://')) {
      final parts = raw.replaceFirst('beatsync://', '').split(':');
      if (parts.length == 2) {
        final ip = parts[0];
        final port = int.tryParse(parts[1]) ?? 8080;
        setState(() => _scanning = false);
        _doConnect(ip, port);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Session', style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
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
                  child: const Icon(Icons.qr_code_scanner, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('Join a Group Session', style: AppTheme.heading(fontSize: 22)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text("Scan the QR code on the trainer's phone",
                    style: AppTheme.body(fontSize: 14)),
              ),
              const SizedBox(height: 24),

              // QR Scanner button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _connecting ? null : () => setState(() => _scanning = !_scanning),
                  icon: Icon(_scanning ? Icons.close : Icons.qr_code_scanner),
                  label: Text(_scanning ? 'Close Scanner' : 'Scan QR Code',
                      style: AppTheme.heading(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              if (_scanning) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 250,
                    child: MobileScanner(
                      onDetect: _onQrDetected,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // OR divider
              Row(
                children: [
                  Expanded(child: Divider(color: AppTheme.surfaceLight)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: AppTheme.mono(color: AppTheme.textMuted, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: AppTheme.surfaceLight)),
                ],
              ),
              const SizedBox(height: 24),

              // Manual entry
              Text('Enter manually',
                  style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ipController,
                      style: AppTheme.body(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '192.168.1.5',
                        hintStyle: AppTheme.body(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(':', style: AppTheme.body(color: AppTheme.textMuted, fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _portController,
                      style: AppTheme.body(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '8080',
                        hintStyle: AppTheme.body(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _connecting ? null : _connectManual,
                  icon: _connecting
                      ? SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                      : Icon(Icons.link, color: AppTheme.accent),
                  label: Text(_connecting ? 'Connecting...' : 'Connect',
                      style: AppTheme.body(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.accent)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!,
                          style: AppTheme.body(color: AppTheme.danger, fontSize: 13))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
