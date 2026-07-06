# QR Code Join — Implementation Plan

Status: **planned, not built.** The QR visuals currently in the app are
placeholders (a static `Icons.qr_code_2_rounded` in `InviteSheet`, and a
decorative scanner frame in `JoinSessionScreen._ScannerStage`). The packages
`qr_flutter` and `mobile_scanner` are already in `pubspec.yaml` but unused.

## Key architectural note

In production, **joining a session does not use a QR code at all**. Once an
athlete is a studio member, `JoinSessionScreen` watches the studio's live
session via `SessionRepository.watchLive(studioId)` and joins in one tap. The
QR/scanner is leftover from the demo flow.

The thing a QR code should actually encode is the **studio invite code** — i.e.
onboarding an athlete into a studio, which today is a manual 6-digit entry in
`JoinStudioScreen`. So this plan makes QR = "scan to join the studio", not "scan
to join a session".

## Decision to confirm before building

**What does the QR encode?**
- **(a) Raw 6-digit code** — simplest, MVP-friendly. Scanner reads the digits
  and runs the existing join flow. *Recommended for MVP.*
- (b) Deep link `https://beatsync.web.app/join?code=479321` — nicer (tappable
  from anywhere) but needs Android App Links + iOS Universal Links setup.

This plan assumes **(a)** unless changed.

## Scope

### 1. Real QR generation (trainer side)
- File: `lib/widgets/invite_sheet.dart`
- Replace the placeholder `Container` + `Icon(Icons.qr_code_2_rounded)` with
  `QrImageView(data: code, size: 180, ...)` from `qr_flutter`.
- Remove the hardcoded default `code = '479321'`; require a real invite code
  (the trainer already resolves it as `_inviteCode` in `TrainerMonitorScreen` /
  `TvHostScreen`). Make `code` a required parameter.
- Keep the 6-digit text under the QR as a manual fallback.

### 2. Real scanning (athlete side)
- File: `lib/screens/join_studio_screen.dart` (this is where a code is actually
  consumed — not the session screen).
- Add a "Scan QR" affordance that opens a `MobileScanner` view from
  `mobile_scanner`.
- On `onDetect`, extract the barcode's raw value, pull the 6-digit code, and run
  the **existing** `resolveStudioId` + `join` + `setStudioId` logic. Extract that
  logic into a shared method so it is not duplicated between manual entry and
  scan.
- Guard against multiple rapid detections (debounce / stop after first hit).

### 3. Decommission the fake session scanner
- File: `lib/screens/join_session_screen.dart`
- The demo `_ScannerStage` and its `_CornerBracketsPainter` are placeholders. In
  production the join is automatic, so either remove the demo scanner or make it
  clearly demo-only. No real scanning belongs here.

### 4. Camera permission
- iOS: add `NSCameraUsageDescription` to `ios/Runner/Info.plist`.
- Android: add `<uses-permission android:name="android.permission.CAMERA"/>` to
  the manifest.
- `mobile_scanner` requests the runtime prompt itself; `permission_handler` is
  already a dependency if a pre-check is wanted (mirrors the BLE permission flow
  in `DevicePairingScreen._ensurePermissions`).

## Strings (bilingual, via `Strings._pick`)
- `scanToJoin` — "Scan to join" / "Skeniraj za pridruživanje"
- `pointAtQr` — "Point your camera at the studio QR code" / "Usmjeri kameru na QR kod studija"
- `cameraPermissionNeeded` — camera-denied message
- Reuse existing `orEnterCode`, `joinStudioBtn`, `enterStudioCode`.

## Verification
- Trainer opens invite sheet → a **real, scannable** QR renders (test by
  scanning with a phone camera; it should show the 6-digit code / link).
- Athlete taps "Scan QR" → camera opens → scanning the trainer's QR joins the
  studio and lands on home with the studio set.
- Manual 6-digit entry still works unchanged.
- `flutter analyze` clean; test on a physical device (camera does not work on
  emulator, same as BLE).

## Out of scope / later
- Deep-link option (b) and App/Universal Links.
- QR for anything session-level (not needed given auto-join).
