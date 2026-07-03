# BeatSync — Screens Map

Purpose: let a session get oriented on any screen **without reading the full file**. Read this instead of grepping `lib/screens/` cold. For symbol-level lookups (who calls X, what imports Y) use the indexed graph — see "Deeper dives" at the bottom.

Generated 2026-07-02 from commit `6415992c` by scanning all 35 files in `lib/screens/`. **This is a snapshot — re-verify against the file before relying on it for anything non-trivial**, and prefer [HANDOFF.md](HANDOFF.md) for current project status/milestones (this doc is structural, not a status tracker).

## App shell / navigation backbone

`main.dart` picks one of two flows via `FeatureFlags.prototypeMode`:
- **Prototype flow** (`prototypeMode = true`): Splash → Onboarding → Login/Register → RoleSelect → ProfileSetup wizard → `MainNavShell`. All local/mock, no Firebase reads.
- **Production flow** (`prototypeMode = false`, the default): `StreamBuilder<User?>` on `AuthService.authStateChanges()` →
  - signed out → `_AuthFlow` (Login ⇄ Register)
  - signed in, no `users/{uid}` doc yet → `_ProfileOnboarding` (RoleSelect → ProfileSetup wizard → persists profile [+ studio doc if trainer])
  - signed in, profile doc exists → `_ProfileGate` watches the live doc: `banned == true` → `_BannedScreen` (sign-out only); else → `MainNavShell`

`main_nav_shell.dart` (`MainNavShell`) is the role-aware bottom-nav shell, **each tab has its own nested `Navigator`** (pushed screens stay inside that tab's stack, bottom nav stays visible):
- **Athlete tabs:** Home (`home_screen.dart`) · History (`workout_history_screen.dart`) · Profile (`settings_screen.dart`)
- **Trainer tabs:** Home (`trainer_home_screen.dart`) · Members (`member_list_screen.dart`) · Analytics (`studio_analytics_screen.dart`) · TV (`tv_host_screen.dart`)

## Feature flags (`lib/config/feature_flags.dart`)

All `false` in MVP — flip to re-enable post-launch. `trends`, `hrv`, `audioCues`, `healthSync`, `rpeAndMood`, `activityCalendar`, `backupImport`, `personalRecords`, `paywall`. `prototypeMode` toggles the whole demo-vs-production flow (see above).

## ⚠️ Dead/orphaned screens (not referenced from anywhere)

| File | Per HANDOFF.md? | Confirmed by |
|---|---|---|
| `profile_edit_screen.dart` | Yes, documented | grep: only self-reference |
| `trends_screen.dart` | Yes, documented (also gated by `FeatureFlags.trends`) | grep: only self-reference |
| `studio_creation_screen.dart` | **No — undocumented finding from this scan** | grep: only self-reference. Trainers actually create their studio via the `ProfileSetupScreen` wizard (`StudioRepository.create` call in `main.dart`'s `_ProfileOnboarding._persist`), not this screen. |

If any of these are ever wired up or deleted, update this table and HANDOFF.md.

## Screens

### Auth / Onboarding

| File | Role | Purpose | Reached from → navigates to | Key deps | Notes |
|---|---|---|---|---|---|
| splash_screen.dart | Shared | Brand splash with fade-out, warms cache on app start | n/a | n/a | Driven by main.dart's flow selection |
| login_screen.dart | Auth | Email/password login with mock & Firebase auth hooks | AuthFlow → MainNavShell or RegisterScreen | AuthService, UserRepository | Mock creds: athlete@beatsync.ba/test123, trainer@beatsync.ba/test123 |
| register_screen.dart | Auth | Account creation form (name/email/password) | AuthFlow → RoleSelectScreen | AuthService | Prototype-only social buttons; no Firebase check in mock mode |
| role_select_screen.dart | Auth | Athlete vs Trainer role picker | RegisterScreen / ProfileOnboarding → ProfileSetupScreen | n/a | Role persists through wizard |
| profile_setup_screen.dart | Shared | Multi-step onboarding wizard: personal/fitness/strap/studio | RoleSelectScreen → MainNavShell | AuthService, StorageService, UserRepository, StudioRepository | Athlete = 3 pages, Trainer = 5 (+studio form). **Trainer studio creation happens here**, not in studio_creation_screen.dart |
| onboarding_tutorial_screen.dart | Shared | Two-slide tutorial: HR strap + zones intro | Splash (first launch) → LoginScreen | SharedPreferences | Skippable; seen-flag is local-only |
| studio_creation_screen.dart | Trainer | Studio form (name/location/capacity) + success page | **n/a — orphaned, see Dead screens above** | n/a | Not called from anywhere |

### Athlete home & studio

| File | Role | Purpose | Reached from → navigates to | Key deps | Notes |
|---|---|---|---|---|---|
| home_screen.dart | Athlete | Greeting, hero "Start Workout" card, weekly stats, recent workouts | MainNavShell (Home tab) → WorkoutScreen / History / Settings | AuthService, WorkoutRepository, MockData, HrZones | `enableStudioJoin` flag controls the join-studio CTA |
| join_studio_screen.dart | Athlete | Modal: 6-digit invite code entry, resolves & self-joins studio | HomeScreen CTA → pops back to Home | AuthService, StudioRepository, UserRepository | Production-only; writes `user.studioId` |
| edit_profile_screen.dart | Athlete | Personal info editor: name/age/sex/weight/height/fitness/resting-HR | SettingsScreen → pops back | AuthService, UserRepository | Production persists via Firestore |
| settings_screen.dart | Shared | Profile card + stats + grouped settings (account/app/studio/support) | MainNavShell (Profile tab, athlete) or pushed (trainer) → EditProfile / JoinStudio / StudioDetail / Subscription / HelpFaq / LegalDoc / HealthData / DevicePairing | AuthService, StudioRepository, WorkoutRepository, BleHrService | Role-aware; theme/lang setters call into `BeatSyncAppState` |
| studio_detail_screen.dart | Shared | Role-aware: trainer edits name/location/capacity; athlete views/leaves | SettingsScreen → pops back | StudioRepository, UserRepository | `isSelfLeave` rule (Stage 3); split render paths `_buildOwner`/`_buildMember` |
| subscription_screen.dart | Shared | Placeholder "coming soon" stub for billing | SettingsScreen | none | No logic — do not add RevenueCat/paywall code here per CLAUDE.md |
| help_faq_screen.dart | Shared | Static FAQ (6 Q&As: studios, straps, zones, live sessions, data) | SettingsScreen | none | i18n via `Strings.pick` |
| legal_doc_screen.dart | Shared | Scrollable Privacy Policy / Terms of Service reader | SettingsScreen | none | Named constructors `.privacy()` / `.terms()`; i18n via `Strings.pick` |
| health_data_screen.dart | Athlete | Read-only HR zones + body metrics derived from profile | SettingsScreen → pops back | UserProfile, HrZones | Zone ranges computed from `hrMax` |
| device_pairing_screen.dart | Athlete | BLE HR sensor discovery, pairing, live HR display | Home/Settings → pops back | BleHrService, flutter_blue_plus, permission_handler | Needs Android 12+ Bluetooth runtime perms |

### Workout / session (athlete side)

| File | Role | Purpose | Reached from → navigates to | Key deps | Notes |
|---|---|---|---|---|---|
| join_session_screen.dart | Athlete | Find & join the studio's live session (or QR in demo) | Home → SessionLobbyScreen / WorkoutScreen | SessionRepository, CloudSession, AuthService | Kicked athletes bounce back to this screen |
| session_lobby_screen.dart | Athlete | Waiting room before trainer starts the group session | JoinSessionScreen → WorkoutScreen | SessionRepository, CloudSession, AuthService | Marks athlete "ready" (bpm=0) on the live board |
| workout_screen.dart | Shared | Live immersive workout: BPM, zones, stats, leaderboard | Home (solo) / SessionLobby (group) → WorkoutSummaryScreen | BleHrService, SessionRepository, WorkoutRepository, FeatureFlags | Group = trainer-controlled pause; solo = self-controlled. Real BLE or simulated curve, never blended |
| workout_summary_screen.dart | Athlete | Post-workout results: avg/max HR, zone distribution | WorkoutScreen → Home | none (UI-only) | "Back to home" always shown |
| workout_history_screen.dart | Athlete | Filterable list of past workouts (time + type) | MainNavShell (History tab) | WorkoutRepository, MockData, AuthService | Streams real workouts when signed in |
| trends_screen.dart | Athlete | ACWR gauge, weekly TRIMP/HR charts, zone distribution | **n/a — orphaned + feature-flagged off**, see Dead screens above | StorageService, TrainingLoadService, HrZones, fl_chart | Re-enable via `FeatureFlags.trends` if ever revived |

### Trainer side

| File | Role | Purpose | Reached from → navigates to | Key deps | Notes |
|---|---|---|---|---|---|
| trainer_home_screen.dart | Trainer | Home tab: live session hero, studio stats, recent sessions | MainNavShell (Home tab) → SessionHostScreen / TrainerMonitorScreen | SessionRepository, StudioRepository, WorkoutRepository | Stats memoized on `studioId` (`_StudioStatsLoader`), refresh on restart/studio change |
| session_host_screen.dart | Trainer | Start a session: name, workout type, interval config | TrainerHomeScreen → TrainerMonitorScreen | SessionRepository, SessionStore | `start()` ends any existing live session for the studio first |
| trainer_monitor_screen.dart | Trainer | Live control panel: Start/Pause/Resume/Skip/Kick/End, interval timer | SessionHostScreen → CloudSessionDetailScreen (on end) | SessionRepository, SessionStore, UidNameCache | Lobby → running → paused states; interval countdown is monitor-local, not synced |
| member_list_screen.dart | Trainer | List studio members with activity, search, filter | MainNavShell (Members tab) → MemberDetailScreen | StudioRepository, UserRepository, WorkoutRepository | Fan-out load per member's workouts for activity subtitle |
| member_detail_screen.dart | Trainer | Member profile: attendance heatmap, TRIMP trend, trainer notes | MemberListScreen → pops back | TrainerNotesRepository, WorkoutRepository | 12-week heatmap, 8-week TRIMP trend; notes keyed per trainer+member |
| studio_analytics_screen.dart | Trainer | Studio-wide 8-week stats: sessions, hours, top athletes | MainNavShell (Analytics tab) | StudioRepository, UserRepository, WorkoutRepository | Aggregates last 8 weeks across all members |
| tv_host_screen.dart | Shared | TV/shareable-link display: idle splash → live board + QR | MainNavShell (TV tab, trainer) / shareable link | SessionRepository, SessionStore, UidNameCache | Independent local phase-sim, cosmetic only; sorts A-Z/BPM |
| all_sessions_screen.dart | Trainer | Full session history with time/type filters | TrainerHomeScreen → SessionDetailScreen | SessionStore, SessionRecord, WorkoutType | **Demo/local mode only** — no Firestore read path |
| session_detail_screen.dart | Trainer | Post-session analytics: group stats, zones, per-athlete results | AllSessionsScreen → pops back | SessionStore, SessionRecord | Demo path; cloud equivalent is CloudSessionDetailScreen |
| cloud_session_detail_screen.dart | Trainer | Analytics for an ended **cloud** session, loads linked workouts | TrainerHomeScreen / TrainerMonitorScreen (on end) → adapts into SessionDetailScreen UI | WorkoutRepository, UserRepository, CloudSession, WorkoutSummary | Reads via `workouts where sessionId == X` (decision: richer than board snapshots, keeps early leavers) |

## Deeper dives

The codebase is also indexed in **graphify** (2441 nodes, 3368 edges, 111 communities, built at commit `6415992c`, output in [graphify-out/](graphify-out/)). Use it instead of grepping cold for:
- `graphify query "<term>"` — find where a symbol/concept lives
- `graphify explain <node>` — what a file/symbol connects to
- `graphify affected <file>` — blast radius of a change before editing
- `graphify update .` — refresh the graph after code changes (free, no LLM cost — run this before trusting the graph if commits have landed since `6415992c`)

For project status/milestones/known issues (not structure), [HANDOFF.md](HANDOFF.md) is the source of truth — this doc doesn't replace it. For code conventions (theming, i18n, static repos, MVP gating), see [CLAUDE.md](CLAUDE.md).
