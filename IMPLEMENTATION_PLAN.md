# BeatSync — Deployment-Ready Implementation Plan

> Derived from `BeatSync_Admin_Panel_Plan.pdf` + current codebase scan (2026-06-11).
> Build order locked: **application first**, then admin panel. Admin panel is a **separate repo** (`C:\dev\beatsync-admin`), sharing only the Firebase backend.

## Current state (verified)

- Flutter app runs in **prototype/demo mode** (`FeatureFlags.prototypeMode = true`) on `MockData`. This is "the demo."
- **Zero Firebase integration today**: no `firebase_*` deps in `pubspec.yaml`, no `firebase_options.dart`, no `firebase.json`, no `functions/`. Storage is local (`shared_preferences` + `storage_service.dart`); sessions are local WebSocket (`tv_server.dart`, `session_client.dart`).
- `main.dart` already has a stubbed `_ProductionFlow` (returns `MockData`) — the integration seam.
- `UserProfile.id` is a millisecond timestamp string → becomes Firebase UID.
- `UserRole` on mobile = `{athlete, trainer}`. `ceo` exists only as a backend custom claim (panel-only).

The plan's premise — "wire the existing prototype to Firebase first, then build panels on the same backend" — is the right order **because the panel manages nothing until the app writes real data.**

---

## Stage 0 — Prerequisites (you, ~30 min)

- [ ] Create Firebase project in console (e.g. `beatsync-prod`). Enable: Authentication (Email/Password), Cloud Firestore, Hosting.
- [ ] Install tooling: `npm i -g firebase-tools`, `dart pub global activate flutterfire_cli`.
- [ ] `firebase login`.
- [ ] Decide a billing plan: Cloud Functions (Phase D) require **Blaze (pay-as-you-go)**. Free until then.

**Blocker note:** I cannot create the Firebase project or run `flutterfire configure` for you (needs your Google account/console). When we reach Stage 2, you run `flutterfire configure` and I wire the code around the generated `firebase_options.dart`.

---

## Stage 1 — Backend foundation (Firebase, schema, rules)

Goal: backend exists and is secured before any client touches it.

1. **Firestore schema** (already drafted in `CLAUDE.md` — finalize as the source of truth):
   ```
   users/{uid}                       name, email, role, hrMax, studioId?, createdAt
   studios/{studioId}                name, ownerUid, inviteCode, memberUids[], maxMembers, status
   sessions/{sessionId}              studioId, trainerUid, name, status, startedAt, endedAt?
   sessions/{sessionId}/hr/{uid}     bpm, zone, hrMax, lastUpdate   ← throttle 1 write/sec
   workouts/{workoutId}              userId, sessionId?, type, startTime, endTime, avgHr, maxHr, calories, trimp
   audit_log/{entryId}               actorUid, action, targetType, targetId, meta, createdAt   (Phase D)
   ```
2. **Files to create in repo root:**
   - `firebase.json` (Firestore + Hosting config)
   - `.firebaserc` (project alias)
   - `firestore.rules` (security rules — below)
   - `firestore.indexes.json` (composite indexes for filterable tables)
3. **Security rules (v1, app-only — tightened in Phase D):**
   - `users/{uid}`: read/write only if `request.auth.uid == uid`.
   - `studios/{sid}`: read if member or owner; write only by `ownerUid` (trainer).
   - `sessions/{sid}`: read if member of `studioId`; write by session's `trainerUid`.
   - `sessions/{sid}/hr/{uid}`: write only own subdoc while session `status == 'active'`.
   - `workouts/{wid}`: read/write only if `resource.data.userId == request.auth.uid`.
   - `audit_log`, CEO writes → denied to clients (Cloud Functions only).
4. **Deploy:** `firebase deploy --only firestore:rules,firestore:indexes`.

**Deliverable:** secured, empty Firestore + rules in version control.

---

## Stage 2 — Wire the Flutter demo to Firebase (Plan Phase 1)

Goal: the existing app authenticates and reads/writes real Firestore data. Keeps prototype mode available as an offline/demo fallback.

### 2.1 Dependencies & config
- [ ] Add to `pubspec.yaml`: `firebase_core`, `firebase_auth`, `cloud_firestore`. (Per CLAUDE.md anti-pattern rule — these are MVP-required, confirmed.)
- [ ] You run `flutterfire configure` → generates `lib/firebase_options.dart`.
- [ ] `main()`: `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` after `ensureInitialized()`.

### 2.2 Services (new, follow existing `static`/instance convention)
- [ ] `lib/services/auth_service.dart` — wraps `FirebaseAuth`: `signIn`, `register`, `signOut`, `authStateChanges` stream, `currentUid`.
- [ ] `lib/services/user_repository.dart` — `users/{uid}` CRUD; `UserProfile ⇄ Firestore`.
- [ ] `lib/services/studio_repository.dart` — create studio, join-by-invite-code, member list stream.
- [ ] `lib/services/cloud_session_service.dart` — host/join cloud sessions; throttled HR writes (1/sec) to `sessions/{id}/hr/{uid}`; real-time leaderboard stream. (Mirrors the local `session_client.dart`/`tv_server.dart` API so screens swap cleanly.)

### 2.3 Model change
- [ ] `lib/models/user_profile.dart`: add `email`, `studioId?`, `createdAt`; add `toFirestore()` / `fromFirestore(doc)` alongside existing `toJson`/`fromJson` (keep local JSON for offline). `id` now sourced from Firebase UID.

### 2.4 App flow wiring (`main.dart`)
- [ ] Flip `FeatureFlags.prototypeMode = false` (keep prototype path intact for demos).
- [ ] Replace `_ProductionFlow` body with an **AuthGate**: listen to `authService.authStateChanges`.
  - signed-out → `LoginScreen` (wire `onSignedIn`/`onCreateAccount` to `AuthService`).
  - signed-in, no profile doc → `ProfileSetupScreen` → write `users/{uid}`.
  - signed-in + profile → `MainNavShell(profile)`.
- [ ] `LoginScreen`/`RegisterScreen`: replace mock matching with real `AuthService` calls; surface auth errors.

### 2.5 Feature screens onto cloud
- [ ] Studio creation (`studio_creation_screen.dart`) → `studio_repository.createStudio`.
- [ ] Join (`join_session_screen.dart`) → invite-code lookup.
- [ ] Trainer monitor (`trainer_monitor_screen.dart`) → cloud leaderboard stream.
- [ ] Workout save (`workout_summary_screen.dart`) → `workouts/{id}`.
- [ ] Keep local `TvServer` as offline fallback (CLAUDE.md decision — do not remove).

**Deliverable:** real user signs up on a device, creates a studio, runs a session, data lands in Firestore. This is the prerequisite for the entire admin panel.

---

## Stage 3 — Next.js admin panel scaffold (Plan Phase A)

New repo `C:\dev\beatsync-admin`. Duration ~1 day. Goal: clickable shell with auth, no real data yet.

- [ ] `npx create-next-app@latest` (Next.js 15, App Router, TS, Tailwind). Add shadcn/ui, TanStack Query, TanStack Table, React Hook Form + Zod, Recharts, papaparse, Lucide.
- [ ] Port BeatSync design tokens (brand red, dark theme, HR zone colors from `lib/config/app_colors.dart` + `hr_zones.dart`) into `tailwind.config`.
- [ ] Firebase JS SDK config + Auth provider context; `.env.local` for keys.
- [ ] `/login` — brand-red logo, email/password, matches Flutter login visual language.
- [ ] Role-based route-guard middleware reading custom claims (`role`, `studioId`) from the ID token.
- [ ] Two route trees: `/studio/*` (trainer) + `/admin/*` (ceo), each with sidebar + top bar layout.
- [ ] Shared scaffold components: `DataTable`, `PageShell`, `EmptyState`, `LoadingSkeleton`, `ConfirmDialog`, `Toast`.

**Deliverable:** log in as trainer or CEO, land on the correct empty dashboard.

---

## Stage 4 — Trainer panel (Plan Phase B) · ~1.5–2 days

Dashboard · Members table · Member detail · Invite (modal + link + QR + CSV) · Sessions list · Session detail (+PDF export) · Session scheduler · Studio settings · Billing scaffold (usage bar only, no Stripe) · Account settings.

**Deliverable:** functional trainer panel on real Firestore data — shippable to first paying studio.

---

## Stage 5 — CEO panel (Plan Phase C) · ~1–1.5 days

MVP subset: Dashboard (KPIs) · Studios table + detail (suspend/restore/comp/note) · Users table + detail (ban/restore/reset/impersonate) · Team management · Audit log. **Skip** platform analytics, communications, deep billing.

**Deliverable:** platform-wide visibility across every studio.

---

## Stage 6 — Backend tie-in (Plan Phase D) · runs alongside Stages 4–5

- [ ] **Custom claims** via Admin SDK: `{ role: 'athlete'|'trainer'|'ceo', studioId? }`.
- [ ] **Cloud Functions** (`functions/`, TypeScript): `inviteAthleteToStudio`, `suspendStudio` (CEO), `impersonateUser` (CEO, short-lived token), `logAdminAction` (all destructive actions → `audit_log`).
- [ ] **Tighten security rules:** CEO reads everything; all CEO/admin writes routed through Functions only (auditable). Athlete/trainer scopes per Stage 1.
- [ ] Composite indexes for every filterable table.
- [ ] Generate TS types from the finalized schema.

**Deliverable:** the panel does things, securely and auditably.

---

## Stage 7 — Deployment readiness checklist

- [ ] Firestore rules + indexes deployed; rules unit-tested (emulator).
- [ ] Admin panel deployed (Vercel or Firebase Hosting) at `admin.beatsync.app`.
- [ ] TV view on Firebase Hosting at `beatsync.web.app/tv/{sessionId}`.
- [ ] Flutter: `flutter build apk --release` + iOS build; Crashlytics + Analytics added.
- [ ] Privacy policy + ToS published (store requirement).
- [ ] TestFlight + Play Internal Testing.
- [ ] First trainer manually onboarded via console (studio doc) — can run classes on day 1 without the panel.

---

## Timeline (from the plan, ~5 working days for the panels)

| Day | Work |
|---|---|
| Pre | Stage 0 + Stage 1 (Firebase foundation, rules) |
| 1–2 | **Stage 2** — wire Flutter to Firebase (the gating prerequisite) |
| 3 | Stage 3 (panel scaffold) + start Stage 6 (data model/claims) |
| 4 | Stage 4 parts 1–5 (dashboard, members, invites, sessions) |
| 5 | Stage 4 parts 6–10 (session detail, scheduler, settings, billing, account) |
| 6 | Stage 5 parts 1–5 (CEO dashboard, studios, users, impersonate) |
| 7 | Stage 5 parts 6–8 (team, audit, config) + Stage 6 wrap-up (rules, indexes) |

## Open decisions to confirm before coding
1. Firebase project name + region (affects `flutterfire configure`).
2. Panel hosting: **Vercel** (best Next.js DX) vs **Firebase Hosting** (one console). Plan-doc implies Firebase; Vercel is smoother for App Router.
3. Keep `prototypeMode` demo path permanently as offline fallback? (Recommend yes.)
