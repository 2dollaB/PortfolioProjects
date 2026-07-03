# BeatSync — Handoff (Stage 3 polish + light mode + full Croatian i18n COMPLETE; merged to main)

Last updated: 2026-07-02 (added Stage 6 admin-claim rules + ban enforcement below; prose above this line still describes the 2026-06-16 state and hasn't been rewritten). Read this first when resuming in a fresh session.

**Where we are in one line:** every mobile screen runs on real Firebase (auth, studios, workouts, trainer analytics/notes, full live-session loop incl. a pre-start **lobby** with Start/Pause/Resume + kick + an interval timer, TV board, trainer-home/member-list activity stats), BLE heart-rate is code-complete, sessions auto-end into a results screen, the **Settings screen is fully polished — working light mode app-wide, no dead rows, viewable/changeable studio**, and there's a **working Appearance (light/dark/system) + Language (English/Hrvatski) switcher with the whole app translated**; the app now also **enforces admin bans and grants the admin panel cross-studio rules access** (Stage 6, see below); **next up is Stage 4 (Next.js admin panel)** — its own build-out, not this repo — plus the live-session + BLE-hardware test passes and ship chores.

## ✅ Stage 6 (partial) — admin claim + ban enforcement (2026-06-2x, commits `e5a0f43`, `ab470b3`, `6415992`) — merged to main
Groundwork for the separate `beatsync-admin` panel; **this repo (mobile) only holds the enforcement/rules side, not the admin UI**:
1. **`isCeo()` → `isAdmin()` custom claim** (`firestore.rules`): a user carrying the `admin` custom claim (set out-of-band via Cloud Functions/Admin SDK, not in this repo) gets cross-studio **read** access (`users`, `studios`, `sessions`, `workouts`) plus **destructive writes** — delete/edit any studio, and (via the `users/{uid}` write rule) ban users. Regular per-user/per-studio rules are unchanged for non-admins.
2. **Client-side ban enforcement** (`lib/main.dart`, `lib/models/user_profile.dart`): `UserProfile.banned` (bool, default false, read-only client-side — "Set by the admin panel; never written back"). `_ProfileGate` in `main.dart` watches the live `users/{uid}` doc; if `banned == true` it renders `_BannedScreen` (blocks all app access, sign-out only) instead of `MainNavShell` — flips in real time if an admin bans a signed-in user mid-session.
3. **Not done yet in this repo:** no UI anywhere to *set* `banned` or the `admin` claim — that's the admin panel's job (separate repo, 0% started, see "▶ NEXT TASK"). No Cloud Functions in this repo for claim assignment.

**Verified:** not explicitly noted in commit history — flutter analyze presumed clean (repo convention) but no test-pass entry was recorded for this batch; **worth a quick live check** (sign in as a normal user, flip `banned` via the Firebase console, confirm `_BannedScreen` appears) before relying on it.

## ✅ Stage 3 DONE (2026-06-16) — on branch `feature/profile-settings` (see "Repo & git")
Scope agreed with the user, then built in one pass:
1. **Full light mode** — flipping Appearance relights the whole app. Mechanism: `AppColors` keeps the raw `dark*`/`light*` palettes and now exposes a **mutable `brightness` flag + semantic getters** (`bgPrimary`/`bgSecondary`/`bgTertiary`/`border`/`textPrimary`/`textSecondary`/`textTertiary`). All ~396 screen refs were swept `AppColors.darkX` → `AppColors.X`; `AppTheme.*()` text helpers now default their color to the semantic getters (so their 346 call sites needed no edits). `main.dart` `setThemeMode` persists `theme_mode` + sets `AppColors.brightness` (resolving `system` via platform brightness); the `!kIsWeb` persistence gate was removed so the choice **persists on web** too. Theme `ThemeData` (dark/light) still use explicit `dark*`/`light*`.
2. **No dead rows** — **Notifications & Units removed**; Appearance (Light/Dark/System sheet) + Language (English/Hrvatski — **now functional, see i18n section**) wired; Health data → read-only summary; Subscription → "coming soon"; Help & FAQ, Privacy Policy, Terms of Service → real screens. New files: `subscription_screen.dart`, `legal_doc_screen.dart` (drafted Privacy + ToS copy), `help_faq_screen.dart`, `health_data_screen.dart`.
3. **Studio viewable + changeable** (`studio_detail_screen.dart`, role-aware): trainer edits name/location/capacity (owner update — no new rule) + shows/copies invite code; athlete views info and can **leave** (then rejoin by code via existing `JoinStudioScreen`). New `StudioRepository.update`/`leave`, `UserRepository.clearStudioId`, `Studio.location` field. **New rule `isSelfLeave()`** (mirror of `isSelfJoin`) added to `studios` update + **deployed to beatsync-prod**.

**Verified:** `flutter analyze` clean + `flutter build web` OK + **live REST rule tests all pass** (self-join still allowed; self-leave allowed; athlete can't remove the owner or other members; non-member can't leave; trainer owner-edit allowed; throwaway studio + users cleaned up — Pulse Studio untouched). ⚠️ **Light/dark visuals not yet eyeballed by the user** (Flutter web is canvas-rendered; DOM preview tools can't drive it — confirm on Chrome: Settings → Appearance → Light, check a few screens, reload to confirm it persists).

## ✅ i18n (Croatian) COMPLETE (2026-06-16) — `feature/i18n-croatian` + `feature/i18n-complete`, merged to main
User asked for English + Hrvatski, **fully**. Approach (agreed): **lightweight string provider**, not flutter_localizations/ARB.
- **Infra:** `lib/config/strings.dart` — `enum AppLang { en, hr }`, a global `Strings.lang`, and one getter per UI string resolving via `_pick(en, hr)` (en/hr side by side). Also a public `Strings.pick(en, hr)` for long screen-specific prose (legal text, FAQ) kept inline, and enum/zone/type helpers (`sexName`, `fitnessName`, `fitnessDesc`, `zoneName`, `workoutTypeLabel/Desc`). Mirrors the theme system. `main.dart` loads/persists `app_lang` (alongside `theme_mode`); `BeatSyncAppState.setLang()` flips `Strings.lang` + `setState` + persists.
- **Switcher:** Settings → Language sheet lists EN/HR, checks current, persists; trailing shows current. Appearance sheet = Light/Dark/System.
- **⚠️ CRITICAL FIX (commit `cac9774`):** `BeatSyncApp.appKey` (a `GlobalKey<BeatSyncAppState>`) was attached to the inner **`MaterialApp`** instead of the `BeatSyncApp` widget, so `appKey.currentState` was always **null** — meaning **both** the theme AND language toggles were silent no-ops. The key now lives on the `BeatSyncApp` instance passed to `runApp`. Light/dark + language work (user-confirmed on web).
- **Coverage: every reachable screen + widget is translated** — auth funnel, profile-setup, studio-creation, settings + all its sub-screens (health data, subscription, help/FAQ, **Privacy + ToS prose**, studio detail, edit profile, device pairing), athlete core (home/history/workout/summary/join/lobby), and the full trainer side (home, member list, member detail, analytics, all-sessions, session detail, session host, **live monitor**, **TV board**) + shared widgets (floating pills, session banner, bpm display, invite sheet, activity calendar, hrv chart).
- **Intentionally left English:** units/acronyms (`bpm`, `TRIMP`, `RMSSD`, `SDNN`, `ms`, `Z4+`), the `BeatSync` brand, and demo placeholder values (e.g. the prototype's seeded session name / demo emails).
- **⚠️ Pre-existing dead screens NOT translated (orphans, not referenced anywhere — left untouched per "don't touch dead code"):** `lib/screens/profile_edit_screen.dart` and `lib/screens/trends_screen.dart`. If they're ever wired up, translate them with the same `Strings`/`Strings.pick` pattern (or delete them if confirmed dead).
- **To add a language later:** extend `AppLang` + every `_pick`/`pick` call gets a 3rd arg (or switch them to a map). For a new string: add `Strings.x => _pick('English','Hrvatski')` and use it; `flutter analyze` flags any `const` widget that now holds a getter (drop the `const`).

## ▶ NEXT TASK — Mobile upgrade + bug-fix pass (2026-07-03 onward)
**Starting now, before Stage 4.** Use [SCREENS_MAP.md](SCREENS_MAP.md) to find the right screen fast instead of grepping cold, and the **graphify** index (`graphify-out/`, tag `beatsync`) for dependency/blast-radius questions — see the "Deeper dives" section at the bottom of SCREENS_MAP.md. Re-run `graphify update .` first if commits have landed since `6415992c` (free, no LLM cost). **A OnePlus Nord CE 5G (Android 13, adb id `7a9eb93e`) is set up over USB debugging and has BeatSync installed** (`flutter run -d 7a9eb93e` to relaunch a dev session) — use it for real-device verification of these, not just `flutter analyze`.

### Bug list (reported 2026-07-03, unworked — pick these off one at a time, check them off / add notes as you go)
1. **Invite code doesn't fit on one line on most phones** — overflows/wraps. Likely `InviteSheet` widget or `studio_detail_screen.dart` (owner invite-code display).
2. **Placeholders should be formal, not joke/mock data** — some input fields show informal placeholder text; audit and replace with neutral examples. Likely spread across onboarding/profile forms (`profile_setup_screen.dart`, `edit_profile_screen.dart`) — needs a sweep, not a single file.
3. **Pause button overflow when trainer starts a session** — `A RenderFlex overflowed by 11 pixels on the right` (confirmed live in the device log during this session's install). `trainer_monitor_screen.dart`, running-state control row.
4. **Session creation: work/rest seconds wrap to 2 lines** — looks bad. `session_host_screen.dart`, interval config (work/rest/rounds) input.
5. **Feature request: tooltip explaining the Tanaka formula** — wherever `hrMax` is calculated/shown from age (Tanaka method), add an info tooltip explaining it. Check `profile_setup_screen.dart` / `edit_profile_screen.dart` / `health_data_screen.dart` for where the formula surfaces.
6. **Crash on notification-permission grant** (reported by the user's brother) — app crashes when the OS notification-permission dialog is accepted (tap Allow). Likely `flutter_local_notifications` / `foreground_service.dart` init path on Android. **High priority — crash, not cosmetic.**
7. **Personal Info → Save Changes does nothing** — no navigation back, no persisted change. `edit_profile_screen.dart`.
8. **Health Data: 3 stat containers have mismatched height** — the "Age" box is 1 word/1 line, the other two wrap to 2 lines, so they're visually uneven; make all 3 equal height. `health_data_screen.dart`.
9. **My Studio → Save Changes spins but doesn't navigate back** — the save itself works, but after it completes the screen should pop back instead of just stopping the spinner. `studio_detail_screen.dart`.
10. **Workout lost if the app process is killed mid-session** — started a workout, killed the app, the in-progress workout was gone (no recovery/persistence). `workout_screen.dart` — needs some form of local state recovery.
11. **History screen: filter chips touch the divider below them**, and **the divider between the time filters (All/This week/This month) and the type filters (HIIT/CARDIO/STRENGTH/CYCLING/YOGA) isn't centered** — spacing/layout cleanup. `workout_history_screen.dart`.
12. **Studio join doesn't reflect immediately after joining as an athlete** — joined a studio, got returned to Home, but the UI didn't show membership until logout→login; a second join attempt (because the user thought the first didn't work) then errored. Likely a stale stream/cache issue — `home_screen.dart` / `join_studio_screen.dart` not picking up the new `studioId` on the live `UserRepository.watch` stream, or `UserRepository`/`StudioRepository` write-then-read race. **User has a screenshot of the second-attempt error — ask them for it, wasn't attached.**

Known-but-unverified items worth checking during this pass (not "bugs" exactly, just unconfirmed since they landed): the Stage 6 ban-enforcement live check (see above), the athlete live-session loop end-to-end (see "Not done yet"), and the two newly-confirmed orphaned screens (`studio_creation_screen.dart`, plus the pre-existing `profile_edit_screen.dart`/`trends_screen.dart` — candidates for deletion if nobody plans to wire them up).

### Stage 4: Next.js admin panel (after this pass)
Separate private repo `C:\dev\beatsync-admin`; bridge handoff already at `C:\dev\beatsync-admin\docs\HANDOFF.md` (read it first; repo not yet scaffolded). The mobile app is feature-complete (light mode + full EN/HR i18n + Stage 6 rules groundwork done); remaining mobile work besides the bug-fix pass is the live-session + BLE-hardware test passes and ship chores.

## What BeatSync is
Flutter app for real-time heart-rate monitoring during group fitness sessions in small studios. Cheaper alternative to MyZone/OrangeTheory. Solo dev project. Full plan: `IMPLEMENTATION_PLAN.md` (mobile app → Next.js admin panel → backend → deploy).

## Repo & git
- **Location:** `C:\dev\beatsync` (Flutter root).
- **Remote:** `github.com/2dollaB/PortfolioProjects` (user `TMinarik00` has push access).
- **⚠️ Push via the PowerShell tool, NOT bash** — the WSL/bash git credential helper fails here ("could not read Username"). PowerShell git uses the Windows credential manager and works.
- **main** is the integration branch; work happens on `feature/*` branches, fast-forward merged to main, then pushed. Each increment = its own commit + merge.
- Current `main` HEAD: `6415992` + this handoff update — **Stage 3 + full Croatian i18n + Stage 6 admin-claim rules/ban enforcement are merged to main and pushed.** Branches `feature/profile-settings`, `feature/i18n-croatian`, `feature/i18n-complete` are all fast-forward-merged (deleted). No open feature branches.
- **Also see [SCREENS_MAP.md](SCREENS_MAP.md)** (2026-07-02) — structural per-screen reference (purpose/nav/deps/dead-code) for all 35 files in `lib/screens/`, and the repo is indexed in **graphify** (`graphify-out/`, tag `beatsync`) for symbol/dependency queries. Both are structural snapshots, not status — this file (HANDOFF.md) stays the status source of truth.

## Firebase backend (provisioned & deployed)
- **Project:** `beatsync-prod` (project number `918880027506`).
- **Firestore:** `(default)` DB in `eur3`. Rules in `firestore.rules`, indexes in `firestore.indexes.json` — **deployed**. Deploy with `firebase deploy --only firestore --project beatsync-prod`.
- **Auth:** Email/Password enabled.
- **Web API key:** in `lib/firebase_options.dart` (public by design for Firebase web apps — protection is the security rules + auth, not key secrecy). Copy it from there for REST verification scripts; don't paste it into this file (GitGuardian flagged it here on 2026-06-12).
- **Collections:** `users/{uid}`, `studios/{id}`, `invite_codes/{code}`, `workouts/{id}` (with optional `sessionId`), `sessions/{id}` + `sessions/{id}/hr/{uid}` (live board, ~1 write/sec/athlete), `trainer_notes/{trainerUid}/members/{memberUid}`. Rules tested live incl. negative/cross-user cases (owner-only docs; scoped self-assert trainer reads of member profiles + workouts; owner-only session hosting; hr writes need membership + live status — Phase D moves these to custom claims). Athletes may **self-join and self-leave** a studio's `memberUids` (`isSelfJoin`/`isSelfLeave`) and nothing else; everything else on the studio doc stays owner-only (REST-verified incl. negative cases).

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
| 2n | **Cloud session detail**: ended sessions on trainer home are tappable → `CloudSessionDetailScreen` loads `workouts where sessionId == X` (decision: read results from workouts via the existing linkage — richer than board snapshots, keeps early leavers, zero extra writes), resolves names, adapts into `SessionRecord` and reuses the demo `SessionDetailScreen`. New rule `isHostOfWorkoutSession()` deployed + live-verified (coach query OK incl. the app's exact query; stranger denied on query and direct get). `WorkoutSummary.userId` + `WorkoutRepository.fetchBySession`. No composite index needed. |
| 2p | **Session lobby + Start/Pause/Resume + kick** (spec: `docs/superpowers/specs/2026-06-15-session-lobby-start-stop-design.md`): launching a session opens a **lobby** (joinable, clock at 0) instead of starting immediately. New `sessions/{id}` lifecycle fields — `runState` (lobby\|running\|paused), `workoutStartedAt`, `runningSince`, `accumulatedMs` (pause-aware clock), `kickedUids`, plus interval config `workSec`/`restSec`/`rounds`. SessionRepository: `beginWorkout`/`pause`/`resume`/`kick`/`watch`; `start()` enforces one live session per studio (ends leftovers first). Trainer monitor: lobby (joined list + kick + Start) → running (Skip/Pause/Resume/End); interval timer uses the configured work/rest/rounds, rest only **between** rounds, stops at "Complete" and **auto-ends into results**. Athlete: new `SessionLobbyScreen` (ready presence + waiting) → workout streams the session and reacts to pause/resume/kick/end; join never silent-bounces. TV: lobby splash + PAUSED overlay. Results screen has **Back to home**. Demo mirrored via SessionStore. **Rules**: `canWriteHr` also rejects kicked uids; hr delete split to self-only (kicked athlete can still drop their tile). Verified: analyze + build-web; live REST kick rule (pos/neg/self-delete) + trainer lifecycle writes (create/begin/pause/resume/kick/end) all pass as coach. ⚠️ Athlete join→lobby→workout loop not yet visually confirmed end-to-end by the user. |
| 2o | **Cloud-derived studio activity**: trainer-home "Active today" (distinct athletes with a saved workout in a session that started today, via `fetchBySession`) + "Sessions / wk" (sessions started in last 7 days) chips, computed in `_StudioStatsLoader`; new `SessionRepository.fetchSince(studioId, since)` (covered by the existing studioId+startedAt index — owner-token probe confirmed no FAILED_PRECONDITION). Member list: per-member activity from each member's workouts (analytics fan-out pattern) → "N sessions · last seen X" subtitle, active dot, and All/Active today/Inactive filters now live in production (`_MemberActivity`). Monitor: ending a cloud session `pushReplacement`s `CloudSessionDetailScreen` (Back→home). Demo paths untouched. Analyze + build-web gated. |
| 2m | **BLE wiring code-complete**: `BleHrService.instance` singleton + `initBle()`/`initForegroundTask()` at startup (mobile prod only); new `DevicePairingScreen` (runtime BLUETOOTH_SCAN/CONNECT permissions, radar-pulse scan list, connect, live-BPM/battery/signal card); workout screen consumes `hrDataStream` when a strap is connected at start (last reading held through dropouts — never blends fake data), simulated curve stays the no-strap/web fallback; sensor chip = real device + battery when connected, "Simulated" for signed-in users without a strap, mock H10 chip in the demo; settings "Connected devices" row is live in production. Gated on analyze + `flutter build web`. **Untested on hardware.** |
| 3 | **Settings polish + full light mode + studio view/leave/edit** (branch `feature/profile-settings`): see "✅ Stage 3 DONE" above. New rule `isSelfLeave` deployed + REST-verified; analyze + build-web gated. i18n deferred. |

**Verification approach:** every increment gated on `flutter analyze` + **live REST tests** against beatsync-prod (sign-up via Identity Toolkit, write/read Firestore through the security rules, incl. negative tests). Flutter **web UI can't be auto-verified** (canvas rendering) — UI is analyze-verified; the user confirms visuals on device/Chrome.

## ⬜ Not done yet
- **Visually confirm the athlete live-session loop (2p)** — trainer-side lobby/Start/Pause/Resume/End/auto-end were tested; the **athlete** join → waiting room → workout (HR + "View whole studio") → trainer pause/kick/end has NOT been visually confirmed end-to-end by the user. Code is in and hardened against the silent-bounce, but eyeball it in a real 2-window run (see Suggested next steps #1 for the dev-server gotchas).
- **BLE hardware test** — the whole BLE path (2m) is analyze/build-verified only. Needs the user's phone + a strap or a watch in HR-broadcast mode (Garmin/Polar/Coros/Samsung…; Apple Watch can't broadcast): pair via Settings → Connected devices, start a workout, confirm real BPM replaces the curve and the chip shows the device + battery. iOS `Info.plist` has no `NSBluetoothAlwaysUsageDescription` yet (Android-first; add before any iOS run).
- **Device test pass** — end-to-end on a real phone (+strap): BLE, Android build, foreground service, background throttling.
- **Next.js admin panel** (trainer + CEO) — Stages 3–5, **0% started**; own **private** repo at `C:\dev\beatsync-admin`, shares beatsync-prod. **Bridge handoff written → `C:\dev\beatsync-admin\docs\HANDOFF.md`** (read it first; repo not yet scaffolded). Decisions locked: separate private GitHub repo, local-dev-only for now (Vercel recommended later), stack per `IMPLEMENTATION_PLAN.md` Stage 3.
- **Cloud Functions for claim assignment** — Stage 6 remainder. The `admin` custom-claim **rules** are in (see "Stage 6" above), but nothing in this repo *sets* the claim or the `banned` flag yet — that's a Cloud Function + the admin panel's job. Self-assert rules (`isSelfJoin`/`isSelfLeave` etc.) and their extra `get()` read costs are still in place, not yet replaced.
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
0. **Mobile upgrade + bug-fix pass** (the immediate next task; see "▶ NEXT TASK" near the top) — get the bug list from the user at the start of the next session and work it, logging progress here as it lands.
1. **Stage 6 live check**: sign in as a normal user, flip `banned` on their `users/{uid}` doc via the Firebase console, confirm `_BannedScreen` appears and blocks access in real time.
2. **Two-window end-to-end live-session test** (user, see "Not done yet"): trainer (coach@beatsync.app) Launch → **Lobby**; athlete joins → **waiting room** → trainer **Start** → both run; try **Pause/Resume**, **Skip**, **Remove (kick)**, and let the interval finish → **auto-ends into results**. **Dev-server gotchas learned in 2p:** (a) run `flutter run -d web-server --web-port <fresh-port>` — the **web-server** device survives closing a browser tab (the `-d chrome` device dies when the tab closes); (b) Flutter web's **service worker caches aggressively** — after a rebuild either hard-reload (Empty Cache and Hard Reload) or, simplest, **bump to a fresh port** (new origin = zero cache); (c) Firebase **auth is shared across all tabs of one Chrome profile**, so test the two roles in a normal window + an **Incognito** window (not two tabs).
3. **BLE hardware test** (user's phone + strap/watch): `flutter run` on Android, pair via Settings → Connected devices, verify live BPM in a workout. First Android build of the project — expect possible Gradle/SDK chores.
4. **Stage 4 — Next.js admin panel** (separate private repo `C:\dev\beatsync-admin`; bridge handoff already at `C:\dev\beatsync-admin\docs\HANDOFF.md`).

**2p notes:** session lifecycle is one source of truth on `sessions/{id}` (`runState` + pause-aware clock `accumulatedMs`/`runningSince`); the interval phase countdown is **trainer-monitor-local** (not synced to athletes/TV — the TV has its own independent phase sim, still cosmetic). `start()` ends any existing live session for the studio first (one-live invariant). Spec: `docs/superpowers/specs/2026-06-15-session-lobby-start-stop-design.md`.

**2o note:** the trainer-home chips load once and are memoized on `studioId` (`_StudioStatsLoader`), like the analytics screen — they reflect state at first home load and refresh on app restart / studio change, not after you end a session in the same session. Acceptable for a landing stat; revisit if it feels stale in the live test.
