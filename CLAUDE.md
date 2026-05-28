# BeatSync — Project Context

## What this is

Flutter app for real-time group fitness HR monitoring. Target market: small fitness studios (CrossFit boxes, gyms) up to 30 athletes per session. Cheaper alternative to MyZone / OrangeTheory. Solo developer project, MVP in progress.

Plan document: `../BeatSync_Development_Plan.docx` (in beatsync/ parent folder).

## MVP scope

Cloud-first studio experience. Everything else is feature-flagged off until post-launch.

### In MVP
- BLE HR monitoring via `flutter_blue_plus`
- Firebase Auth (email/password only — no Google/Apple in MVP)
- Studio model: trainer creates a studio, athletes join via 6-digit invite code
- Cloud group sessions via Cloud Firestore real-time listeners
- TV dashboard as shareable link via Firebase Hosting
- Basic per-user workout saving to Firestore

### Feature-flagged off (re-enable post-launch via `lib/config/feature_flags.dart`)
- `TrendsScreen` (ACWR, weekly TRIMP, 8-week zone distribution)
- `HrvChart` (RMSSD/SDNN)
- `AudioCueService` (TTS announcements)
- `HealthSyncService` (Apple Health / Google Health Connect)
- RPE + mood tracking in workout summary
- Activity calendar heatmap
- Backup/import JSON
- Personal records

## Tech stack — decided

| Area | Choice | Rationale |
|---|---|---|
| Frontend | Flutter (Dart 3.11+) | already committed |
| State mgmt | StatefulWidget + StreamController | Riverpod migration deferred to post-MVP — current code works |
| BLE | `flutter_blue_plus` | already integrated, has Garmin workaround |
| Backend | Firebase Auth + Cloud Firestore + Hosting | plan-doc decision, fastest solo-dev path |
| Local fallback | Built-in `TvServer` (HttpServer + WebSocket) | kept as offline mode when Firestore unreachable |
| Payments | NONE in MVP | launch free, add RevenueCat once first studio adopts |
| Analytics | Firebase Analytics + Crashlytics | added late in launch phase |

## Folder layout

```
lib/
├── main.dart              # App bootstrap, theme, navigation root
├── config/                # theme.dart, hr_zones.dart, feature_flags.dart
├── models/                # Plain Dart data classes (UserProfile, Workout, …)
├── screens/               # All screens — flat folder, no subfolders
├── services/              # Business logic, IO, BLE, storage, network
└── widgets/               # Reusable UI components
```

## Code conventions observed in this codebase

- Section comments like `// 8.3 — Training Load Service` map to plan-doc sections. **Keep this pattern when adding code that traces back to a plan section.**
- Services are `static` classes when stateless (e.g., `StorageService`, `AudioCueService`, `HealthSyncService`). Instance-based when they own connections (e.g., `TvServer`, `BleHrService`).
- Theming exclusively through `AppTheme.heading()`, `AppTheme.body()`, `AppTheme.mono()`. **Never hardcode `TextStyle`.**
- HR zone colors through `HrZones.colors[1..5]`. **Never hardcode zone color hexes.**
- Models implement `toJson()` and `fromJson()` for local persistence.
- `UserProfile.id` is a millisecond timestamp string (legacy from pre-Firebase era — will become Firebase UID in MVP).
- Comments are minimal. Don't add narration like "// Loop through items".

## Commands

```bash
flutter pub get                    # install deps
flutter run                        # dev run on connected device
flutter build apk --release        # release APK → build/app/outputs/flutter-apk/
flutter analyze                    # static analysis
dart format lib/                   # format all dart files
flutter pub outdated               # show outdated deps
```

## Hardware notes

- **BLE features require a physical device.** Emulator BLE does not work.
- Tested HR straps that pair cleanly: Polar H10, Wahoo TICKR, generic Bluetooth straps with 0x180D service UUID.
- Garmin HRM-Pro has non-standard notification flags — workaround already in `BleHrService`. Don't remove.

## Anti-patterns to avoid

- Don't add Riverpod. Refactor request must be explicit.
- Don't re-enable feature-flagged screens without flipping the flag in `feature_flags.dart`.
- Don't add RevenueCat, paywall, or subscription code in MVP phase.
- Don't migrate to Supabase or other backend.
- Don't introduce new pubspec packages without confirming it's needed for MVP.
- Don't add `setState` calls in `build()` or in synchronous code paths during `initState`.
- Don't write multi-paragraph docstrings. One line max per comment, only when the why is non-obvious.
- Don't run `flutter pub upgrade --major-versions` without a feature branch and explicit confirmation.

## Firestore schema (MVP)

```
users/{uid}                        name, email, role, hrMax, studioId?, createdAt
studios/{studioId}                 name, ownerUid, inviteCode, memberUids[], maxMembers
sessions/{sessionId}               studioId, trainerUid, name, status, startedAt, endedAt?
sessions/{sessionId}/hr/{uid}      bpm, zone, hrMax, lastUpdate     ← throttled 1 write / sec
workouts/{workoutId}               userId, sessionId?, type, startTime, endTime, avgHr, maxHr, calories, trimp
```

Security rules: user can read/write only own `users/{uid}`. Studio members can read studio. Trainer of a studio can write `sessions` under that studio. Athletes write only their own `hr/{uid}` subdoc during active session.

## Status of MVP milestones

- [ ] Feature-flag system in `lib/config/feature_flags.dart`
- [ ] Bottom nav reduced to 2 tabs (Home + Settings)
- [ ] Firebase project created + FlutterFire CLI configured
- [ ] AuthGate + email/password login screen
- [ ] `users/{uid}` Firestore migration of UserProfile
- [ ] Studio creation flow
- [ ] Invite code + join flow
- [ ] Cloud session host + join
- [ ] In-app live leaderboard for trainer
- [ ] Firebase Hosting TV view at `beatsync.web.app/tv/{sessionId}`
- [ ] Empty states + loading skeletons
- [ ] Crashlytics + Analytics
- [ ] Privacy policy + ToS published
- [ ] TestFlight + Play Internal Testing
- [ ] Store submission
