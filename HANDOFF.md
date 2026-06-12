# BeatSync — Handoff (Stage 2 in progress)

Last updated: 2026-06-12 (evening — after 2d-v through 2i). Read this first when resuming in a fresh session.

## What BeatSync is
Flutter app for real-time heart-rate monitoring during group fitness sessions in small studios. Cheaper alternative to MyZone/OrangeTheory. Solo dev project. Full plan: `IMPLEMENTATION_PLAN.md` (mobile app → Next.js admin panel → backend → deploy).

## Repo & git
- **Location:** `C:\dev\beatsync` (Flutter root).
- **Remote:** `github.com/2dollaB/PortfolioProjects` (user `TMinarik00` has push access).
- **⚠️ Push via the PowerShell tool, NOT bash** — the WSL/bash git credential helper fails here ("could not read Username"). PowerShell git uses the Windows credential manager and works.
- **main** is the integration branch; work happens on `feature/*` branches, fast-forward merged to main, then pushed. Each increment = its own commit + merge.
- Current `main` HEAD: `12b5581` (Stage 2i) + this handoff update.

## Firebase backend (provisioned & deployed)
- **Project:** `beatsync-prod` (project number `918880027506`).
- **Firestore:** `(default)` DB in `eur3`. Rules in `firestore.rules`, indexes in `firestore.indexes.json` — **deployed**. Deploy with `firebase deploy --only firestore --project beatsync-prod`.
- **Auth:** Email/Password enabled.
- **Web API key:** `AIzaSyDg9ZvT3haD97oEA5QtqDOeFFecGx4-5WE` (for REST verification scripts).
- **Collections:** `users/{uid}`, `studios/{id}`, `invite_codes/{code}`, `workouts/{id}`, `trainer_notes/{trainerUid}/members/{memberUid}` (see `CLAUDE.md` for the schema). Rules tested live incl. negative/cross-user cases.

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
- **Trainer:** `coach@beatsync.app` / `beatsync123` — owns studio **"Pulse Studio"**, **invite code `653572`** (seeded for testing the athlete join flow).

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
| 2i | **Cloud sessions data layer**: `CloudSession`/`SessionHrEntry` + `SessionRepository` (start/end/watchLive/watchRecent/writeHr/watchHr); session rules tightened (owner-only create, hr writes need membership + live status), 13 live assertions pass. **No UI yet.** |

**Verification approach:** every increment gated on `flutter analyze` + **live REST tests** against beatsync-prod (sign-up via Identity Toolkit, write/read Firestore through the security rules, incl. negative tests). Flutter **web UI can't be auto-verified** (canvas rendering) — UI is analyze-verified; the user confirms visuals on device/Chrome.

## ⬜ Not done yet (still mock or unbuilt)
- **Trainer screens, remaining** — `tv_host`, `trainer_monitor` need live sessions. Member-list activity filters ("Active today"/"Inactive") and trainer-home "Active today"/"Sessions / wk" chips need live sessions too. Trainer notes on member detail are local-only (needs a `trainer_notes` collection).
- `join_session_screen` (live-session join) → mock; needs cloud live sessions.
- **Cloud live sessions** (host/join/HR leaderboard) — not built; **BLE-hardware-dependent, must be tested on a phone+strap**.
- **Production cutover testing** — end-to-end on a real device.
- **Next.js admin panel** (trainer + CEO) — Stages 3–5, **0% started**.
- **Cloud Functions + custom claims + tightened rules** — Stage 6 (needs Blaze plan).
- **Deploy** — hosting, store submission, privacy/ToS — Stage 7.

**Overall: ~40% of the full plan.** The hardest/riskiest part (secure auth + cloud data model) is done and proven.

## Key code patterns (follow these)
- **Prototype-preserving wiring:** new Firebase behavior is *additive* via optional callbacks; the demo path is unchanged. The production signal is **`AuthService.currentUid != null`** (no signed-in user = prototype).
- **Repos are static classes:** `AuthService`, `UserRepository`, `StudioRepository`, `WorkoutRepository`. Read model: `WorkoutSummary` (`fromDoc` + display getters).
- **Reactive UI:** the AuthGate streams `UserRepository.watch(uid)`; screens get live profile updates (e.g., joining a studio auto-hides the CTA). Use `watchRecent`/`snapshots()` for lists.
- Theming via `AppTheme.*` / `AppColors.*` / `HrZones` — never hardcode styles/zone colors (see `CLAUDE.md`).

## Verification helper (REST, owner-token)
The Firebase CLI refresh token lives at `C:\Users\tinmi\.config\configstore\firebase-tools.json`. Exchange it for an access token (client_id `563584335869-...apps.googleusercontent.com`, secret `j9iVZfS8kkCEFUPaAeJV0sAi`, grant_type refresh_token) to hit Google REST APIs (Firestore admin, Identity Toolkit) bypassing rules — used for seeding/cleanup. For *rules* tests, sign up a throwaway user and use their idToken (respects rules). Clean up test users/docs after (force-delete enabled accounts via `accounts:batchDelete` with `force:true`).

## Environment / tooling
- `flutter` 3.44, `dart` 3.12, `firebase-tools` 15.20, `flutterfire` 1.4 (at `C:\Users\tinmi\AppData\Local\Pub\Cache\bin`). PowerShell execution policy: `RemoteSigned` (CurrentUser).
- **Skills active:** superpowers (14 skills in `~/.claude/skills/` — installed manually since `/plugin` is unavailable in this environment; loads on session start) + Karpathy guidelines (`~/.claude/CLAUDE.md`). Follow brainstorm → design → implement → verify.

## Suggested next steps
1. **Wire live-session UI to SessionRepository** (data layer done in 2i): session_host_screen → `start()`, trainer_monitor/tv_host → `watchLive` + `watchHr`, join_session_screen + workout_screen → `writeHr` (simulated HR works on web; BLE needs a device). Mind the existing local `SessionStore`/`TvServer` offline path — keep it as the fallback.
2. **Device test pass** — BLE strap, Android build, foreground service.
3. Start the **Next.js admin panel** (biggest remaining chunk; own repo, shares beatsync-prod).
