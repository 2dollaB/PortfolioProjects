# BeatSync — Handoff (Stage 2 wiring COMPLETE)

Last updated: 2026-06-12 (late evening — after 2m, BLE wiring). Read this first when resuming in a fresh session.

**Where we are in one line:** every mobile screen runs on real Firebase (auth, studios, workouts, trainer analytics/notes, full live-session loop incl. TV board) and BLE heart-rate is now code-complete (pairing screen + real HR into the workout screen); what's left is the hardware test pass, cloud session detail, the admin panel, and ship chores.

## What BeatSync is
Flutter app for real-time heart-rate monitoring during group fitness sessions in small studios. Cheaper alternative to MyZone/OrangeTheory. Solo dev project. Full plan: `IMPLEMENTATION_PLAN.md` (mobile app → Next.js admin panel → backend → deploy).

## Repo & git
- **Location:** `C:\dev\beatsync` (Flutter root).
- **Remote:** `github.com/2dollaB/PortfolioProjects` (user `TMinarik00` has push access).
- **⚠️ Push via the PowerShell tool, NOT bash** — the WSL/bash git credential helper fails here ("could not read Username"). PowerShell git uses the Windows credential manager and works.
- **main** is the integration branch; work happens on `feature/*` branches, fast-forward merged to main, then pushed. Each increment = its own commit + merge.
- Current `main` HEAD: `48955a3` + this handoff update. Everything is merged and pushed; no open feature branches.

## Firebase backend (provisioned & deployed)
- **Project:** `beatsync-prod` (project number `918880027506`).
- **Firestore:** `(default)` DB in `eur3`. Rules in `firestore.rules`, indexes in `firestore.indexes.json` — **deployed**. Deploy with `firebase deploy --only firestore --project beatsync-prod`.
- **Auth:** Email/Password enabled.
- **Web API key:** in `lib/firebase_options.dart` (public by design for Firebase web apps — protection is the security rules + auth, not key secrecy). Copy it from there for REST verification scripts; don't paste it into this file (GitGuardian flagged it here on 2026-06-12).
- **Collections:** `users/{uid}`, `studios/{id}`, `invite_codes/{code}`, `workouts/{id}` (with optional `sessionId`), `sessions/{id}` + `sessions/{id}/hr/{uid}` (live board, ~1 write/sec/athlete), `trainer_notes/{trainerUid}/members/{memberUid}`. Rules tested live incl. negative/cross-user cases (owner-only docs; scoped self-assert trainer reads of member profiles + workouts; owner-only session hosting; hr writes need membership + live status — Phase D moves these to custom claims).

## Current mode
- `lib/config/feature_flags.dart` → **`prototypeMode = false`** (production / real Firebase is the default boot path). Flip to `true` to get the polished mock demo (kept intact for client presentations).

## How to run
```powershell
cd C:\dev\beatsync
flutter run -d chrome --web-port 5599   # web works; Firebase works; BLE/HR is simulated
```
(A dev server may already be running on :5599 from the last session.) Real devices needed for BLE.

## Test accounts (real, in beatsync-prod)
- **Athlete:** `jan@gmail.com` (created via the app; password set by user).
- **Trainer:** `coach@beatsync.app` — owns studio **"Pulse Studio"**. Password + invite code are in **`HANDOFF.local.md`** (untracked). The old password was leaked in this file's git history and has been **rotated** — `beatsync123` is dead.

## Secrets (⚠️ this repo is PUBLIC)
Anything sensitive lives in `HANDOFF.local.md` (gitignored): coach password, studio invite code, Firebase CLI OAuth client pair for REST scripts. Never put passwords, tokens or invite codes in this file — it's committed and GitGuardian scans it.

## ✅ Done (all merged to main, verified)
| Increment | What |
|---|---|
| Stage 0/1 | Firebase project, config, rules, indexes |
| 1a | `Firebase.initializeApp` + `AuthService` + `UserRepository` |
| 1b | Production **AuthGate**: login → register → onboarding → `users/{uid}` (+ studio doc for trainers) |
| 2a | Studio join-by-code data layer + `invite_codes` lookup + rules |
| 2b | Athlete **JoinStudioScreen** + home "Join a studio" CTA |
| 2d-i | Edit-profile → Firestore (`EditProfileScreen`) |
| 2d-ii/iii | **Workout save** → Firestore (`WorkoutRepository.save`) incl. zone distribution |
| 2d-iv | **History screen** reads real workouts (`WorkoutSummary` + `WorkoutRepository.watchRecent`) |
| cutover | `prototypeMode = false` |
| 2d-v | **Home screen** real data (hero last-session, "This week" stats, recent list); mock adapter shared via `MockData.recentSummaries()` |
| 2e | **Trainer home + member list** real data (`Studio` model, `StudioRepository.watch`, `UserRepository.loadMany`, real invite code in `InviteSheet`) + **rules**: studio owner may read member `users/{uid}` profiles (live-verified pos+neg) |
| 2f | **Member detail** real data (stats/heatmap/TRIMP trend from member workouts) + **rules**: trainer may read member workouts (live-verified incl. the app's query) |
| 2g | **Studio analytics** computed from members' workouts (`WorkoutRepository.fetchRecent`, 8-week aggregations) |
| 2h | **Settings screen** real data (studio name, role badge, workout stats) + **trainer notes persisted** (`trainer_notes` collection + rules, live-verified) |
| 2i | **Cloud sessions data layer**: `CloudSession`/`SessionHrEntry` + `SessionRepository` (start/end/watchLive/watchRecent/writeHr/watchHr); session rules tightened (owner-only create, hr writes need membership + live status), 13 live assertions pass |
| 2j | **Trainer side of live sessions wired**: host screen creates real sessions, monitor streams the hr board (names, per-athlete hrMax, real QR code, cloud end), trainer home hero + recent list watch the cloud. Demo simulation intact. |
| 2k | **Athlete side wired — live-session loop closed**: join screen watches the studio's live session (one-tap join, no code needed), workout screen publishes hr ~1/sec (paused-aware, removeHr on leave), workouts saved with `sessionId`. **Needs the two-browser end-to-end test (coach hosts, athlete joins).** |
| 2l | **TV host screen** streams the cloud session (idle splash → live board, real studio name + invite QR); `BoardAthlete` + `UidNameCache` extracted, monitor refactored onto them |
| 2m | **BLE wiring code-complete**: `BleHrService.instance` singleton + `initBle()`/`initForegroundTask()` at startup (mobile prod only); new `DevicePairingScreen` (runtime BLUETOOTH_SCAN/CONNECT permissions, radar-pulse scan list, connect, live-BPM/battery/signal card); workout screen consumes `hrDataStream` when a strap is connected at start (last reading held through dropouts — never blends fake data), simulated curve stays the no-strap/web fallback; sensor chip = real device + battery when connected, "Simulated" for signed-in users without a strap, mock H10 chip in the demo; settings "Connected devices" row is live in production. Gated on analyze + `flutter build web`. **Untested on hardware.** |

**Verification approach:** every increment gated on `flutter analyze` + **live REST tests** against beatsync-prod (sign-up via Identity Toolkit, write/read Firestore through the security rules, incl. negative tests). Flutter **web UI can't be auto-verified** (canvas rendering) — UI is analyze-verified; the user confirms visuals on device/Chrome.

## ⬜ Not done yet
- **BLE hardware test** — the whole BLE path (2m) is analyze/build-verified only. Needs the user's phone + a strap or a watch in HR-broadcast mode (Garmin/Polar/Coros/Samsung…; Apple Watch can't broadcast): pair via Settings → Connected devices, start a workout, confirm real BPM replaces the curve and the chip shows the device + battery. iOS `Info.plist` has no `NSBluetoothAlwaysUsageDescription` yet (Android-first; add before any iOS run).
- **Cloud session detail** — ended cloud sessions aren't tappable (per-athlete post-session summary needs an hr-history or results doc; decide the model first). Trainer-home "Active today"/"Sessions / wk" chips and member-list activity filters could now be computed from cloud sessions too.
- **Device test pass** — end-to-end on a real phone (+strap): BLE, Android build, foreground service, background throttling.
- **Next.js admin panel** (trainer + CEO) — Stages 3–5, **0% started**; own repo, shares beatsync-prod. Needs repo-location/stack decisions from the user first.
- **Cloud Functions + custom claims + tightened rules** — Stage 6 (needs Blaze plan). Replaces the self-assert rules and their extra `get()` read costs.
- **Deploy** — hosting (TV link), Crashlytics/Analytics, store submission, privacy/ToS — Stage 7.

**Overall: ~60% of the full plan; the mobile app is 100% code-complete** (BLE wired but hardware-untested). The riskiest software part (auth + cloud data model + live sessions, all rules-verified) is done and proven.

## Key code patterns (follow these)
- **Prototype-preserving wiring:** every screen keeps the polished mock path; production is selected by **`AuthService.currentUid != null`** (plus a non-null `studioId`/`profile`/`session` param where screens need one — mock profiles have `studioId == null`, so demo falls out naturally).
- **Repos are static classes:** `AuthService`, `UserRepository`, `StudioRepository`, `WorkoutRepository`, `SessionRepository`, `TrainerNotesRepository`. Read models in `models/`: `WorkoutSummary`, `Studio`, `CloudSession`/`SessionHrEntry`/`BoardAthlete` (`fromDoc` + display getters). `UidNameCache` resolves uids → names on live boards.
- **Reactive UI:** the AuthGate streams `UserRepository.watch(uid)`; screens use `watch*`/`snapshots()` streams created per the existing pattern (in build/initState, memoized where rebuilds are frequent — see member list's `_membersFor` and TV's `_hrFor`).
- Theming via `AppTheme.*` / `AppColors.*` / `HrZones` — never hardcode styles/zone colors (see `CLAUDE.md`).
- **Commit style:** `Stage 2 (2x): <what>` + a body explaining rules changes and how they were live-verified; handoff updated and pushed after each merge.

## Verification helper (REST, owner-token)
The Firebase CLI refresh token lives at `C:\Users\tinmi\.config\configstore\firebase-tools.json`. Exchange it for an access token using the Firebase CLI's OAuth client (id + secret in `HANDOFF.local.md`; grant_type refresh_token) to hit Google REST APIs (Firestore admin, Identity Toolkit) bypassing rules — used for seeding/cleanup. For *rules* tests, sign up a throwaway user and use their idToken (respects rules). Clean up test users/docs after (force-delete enabled accounts via `accounts:batchDelete` with `force:true`).

## Environment / tooling
- `flutter` 3.44, `dart` 3.12, `firebase-tools` 15.20, `flutterfire` 1.4 (at `C:\Users\tinmi\AppData\Local\Pub\Cache\bin`). PowerShell execution policy: `RemoteSigned` (CurrentUser).
- **Skills active:** superpowers (14 skills in `~/.claude/skills/` — installed manually since `/plugin` is unavailable in this environment; loads on session start) + Karpathy guidelines (`~/.claude/CLAUDE.md`). Follow brainstorm → design → implement → verify.

## Suggested next steps (in order)
1. **Two-/three-window end-to-end test** (user, not yet done): coach@beatsync.app hosts on :5599 → jan@gmail.com joins in an incognito window → monitor + TV boards move ~1/sec; leaving removes the tile; ending the session flips the athlete's writes to silent failures and the TV back to idle. Note: the :5599 dev server still serves the pre-2m build; after a rebuild/restart the athlete's workout chip reads "Simulated" (grey) instead of the old fake "H10 · 9x%" — that's the new honest production chip, not a bug.
2. **BLE hardware test** (user's phone + strap/watch): `flutter run` on Android, pair via Settings → Connected devices, verify live BPM in a workout. First Android build of the project — expect possible Gradle/SDK chores.
3. Cloud session detail screen (decide the post-session results model first: write per-athlete results into the session doc at end vs. query workouts by `sessionId` — the linkage already exists).
4. Start the **Next.js admin panel** (ask the user where the repo lives + confirm stack before scaffolding).
