import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/studio.dart';
import '../services/auth_service.dart';
import '../services/studio_repository.dart';
import '../services/user_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';
import '../widgets/mobile_frame.dart';

/// Athlete joins a studio with the 6-digit invite code from their trainer.
/// Production-only: resolves the code, self-joins the studio, sets studioId.
/// The users/{uid} snapshot stream then refreshes home (the CTA disappears).
class JoinStudioScreen extends StatefulWidget {
  const JoinStudioScreen({super.key});

  @override
  State<JoinStudioScreen> createState() => _JoinStudioScreenState();
}

class _JoinStudioScreenState extends State<JoinStudioScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = Strings.enterCodeError);
      return;
    }
    await _joinWithCode(code);
  }

  /// Opens the camera, extracts the 6-digit code from a scanned QR and joins.
  Future<void> _scan() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (raw == null || !mounted) return;
    final match = RegExp(r'\d{6}').firstMatch(raw);
    if (match == null) {
      setState(() => _error = Strings.qrNotAStudioCode);
      return;
    }
    final code = match.group(0)!;
    _code.text = code;
    await _joinWithCode(code);
  }

  /// Shared join path used by both manual entry and QR scan.
  Future<void> _joinWithCode(String code) async {
    final uid = AuthService.currentUid;
    if (uid == null) {
      setState(() => _error = Strings.notSignedIn);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final studioId = await StudioRepository.resolveStudioId(code);
      if (studioId == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = Strings.codeNoMatch;
        });
        return;
      }
      try {
        await StudioRepository.join(uid: uid, studioId: studioId);
      } on FirebaseException catch (e) {
        // An earlier join that died before setStudioId leaves the account a
        // member without a studioId; the self-join rule then denies the
        // no-op re-join. If we can read the studio and we're in it, carry on
        // to setStudioId instead of dead-ending on permission-denied.
        if (e.code != 'permission-denied') rethrow;
        Studio? s;
        try {
          s = await StudioRepository.load(studioId);
        } catch (_) {}
        if (s == null || !s.memberUids.contains(uid)) rethrow;
      }
      await UserRepository.setStudioId(uid, studioId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Strings.joinedStudio),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = Strings.couldNotJoin(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text(Strings.joinAStudio),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                const Center(child: LogoHeartbeat(size: 28, showWordmark: false)),
                const SizedBox(height: AppSpacing.xl),
                Text(Strings.enterStudioCode, style: AppTheme.h2()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Strings.studioCodeSubtitle,
                  style: AppTheme.bodyLarge(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _code,
                  textAlign: TextAlign.center,
                  style: AppTheme.statNumber(fontSize: 28)
                      .copyWith(letterSpacing: 8),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onSubmitted: (_) => _join(),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: AppTheme.caption(color: AppColors.danger)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                BeatPrimaryButton(
                  label: Strings.joinStudioBtn,
                  icon: Icons.login_rounded,
                  loading: _loading,
                  onPressed: _join,
                ),
                const SizedBox(height: AppSpacing.sm),
                BeatSecondaryButton(
                  label: Strings.scanToJoin,
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: _loading ? null : _scan,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen camera scanner. Pops with the first barcode's raw value.
class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
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
        title: Text(Strings.scanToJoin),
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
