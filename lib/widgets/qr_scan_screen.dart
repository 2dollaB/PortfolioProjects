import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';

/// Full-screen camera scanner. Pops with the first barcode's raw value, or
/// null if the user backs out. Shared by studio-join and session-join.
class QrScanScreen extends StatefulWidget {
  final String title;
  const QrScanScreen({super.key, required this.title});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  Strings.cameraPermissionNeeded,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyLarge(color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.xxl,
            child: Text(
              Strings.pointAtQr,
              textAlign: TextAlign.center,
              style: AppTheme.bodyLarge(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
