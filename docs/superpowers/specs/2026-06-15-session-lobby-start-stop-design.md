# Session Lobby + Start / Pause / Resume — Design

Date: 2026-06-15
Status: Approved (build on `feature/session-lobby-start-stop`, leave unmerged for review)

## Problem

Today, launching a group session immediately creates a **live** session and drops the trainer
into a running monitor with the clock already counting; athletes who join start their workout
instantly. There is no time for everyone to get into position. The trainer needs a **lobby**
(waiting room) where athletes gather, can be removed, and the workout only begins when the
trainer presses **Start** — with **Pause/Resume** and the existing **End**.

## Decisions (from brainstorming)

1. **Athletes wait too.** A joined athlete sees "Waiting for trainer to start…" and does NOT run
   their timer / HR / calorie / TRIMP tracking until Start. They appear in the trainer's lobby
   via a lightweight "ready" presence marker.
2. **Controls:** Start + Pause/Resume + End (pause freezes everyone; athletes see "Paused").
3. **Kick + block rejoin (this session).** Removed athlete drops to the join screen with a
   "removed by trainer" note and cannot rejoin this session.
4. **Both modes:** full feature in real (cloud) mode + mirrored in demo/presentation mode.

## Approach

Single source of truth on the `sessions/{id}` document. Keep `status: live|ended` for
**permission** (join + HR-write rules unchanged; the session is joinable from creation) and add
an orthogonal `runState: lobby|running|paused` for **lifecycle**. Every client (trainer monitor,
athlete, TV) streams the one doc and computes elapsed locally. No new index; the only rule change
is one line to enforce the kick.

### Data model — added to `sessions/{id}`
| field | type | meaning |
|---|---|---|
| `runState` | string | `lobby` → `running` → `paused` (toggles between the last two) |
| `workoutStartedAt` | Timestamp? | set on first Start; null in lobby |
| `runningSince` | Timestamp? | start of current running segment; null when paused/lobby |
| `accumulatedMs` | int | elapsed before the current running segment (pause math); default 0 |
| `kickedUids` | array<string> | removed athletes; default [] |

Unchanged: `status` (live/ended), `startedAt` (= creation time — keeps recent-list ordering and
the existing `studioId+startedAt` index), `studioId`, `trainerUid`, `name`, `type`, `endedAt`.

### Timer math (identical on every client)
- running → `accumulatedMs + (now − runningSince)`
- paused / lobby → `accumulatedMs` (0 in lobby)
- Pause writes `accumulatedMs += (now − runningSince)`, `runningSince = null`, `runState = paused`.
- Resume writes `runningSince = serverTimestamp`, `runState = running`.

(Server timestamps + local `now()` introduce sub-second skew between clients — acceptable for a
fitness clock.)

## Components / data flow

### SessionRepository (new/changed methods)
- `start(...)` — create doc: `status:'live'`, `runState:'lobby'`, `startedAt:serverTs`,
  `workoutStartedAt:null`, `runningSince:null`, `accumulatedMs:0`, `kickedUids:[]`.
- `beginWorkout(id)` — `runState:'running'`, `workoutStartedAt:serverTs`, `runningSince:serverTs`,
  `accumulatedMs:0`.
- `pause(id, accumulatedMs)` — `runState:'paused'`, `accumulatedMs:<computed>`, `runningSince:null`.
- `resume(id)` — `runState:'running'`, `runningSince:serverTs`.
- `kick(id, uid)` — `kickedUids: arrayUnion(uid)`.
- `watch(id)` — stream the session doc as `CloudSession`.
- Presence reuses `writeHr` with `bpm:0` + a `ready:true` marker before Start; real HR after.
- `end(id)` — unchanged (status:'ended', endedAt) + clear `runningSince`.

### CloudSession model
Add the five fields + getters: `isLobby`, `isRunning`, `isPaused`, `elapsed` (per timer math),
`isKicked(uid)`.

### Trainer — `trainer_monitor_screen.dart`
Streams the session doc (for `runState`) alongside the HR board.
- **Lobby:** joined-athlete list (from the HR board presence), a **kick** button per row, clock
  `00:00`, big **Start training** button.
- **Running:** the board (as today) + **Pause** + **End**.
- **Paused:** board dimmed + **Resume** + **End**.
- Elapsed shown from the session clock. `session_host_screen.dart` creates the session in lobby
  and opens the monitor in lobby state.

### Athlete — new `session_lobby_screen.dart` + `workout_screen.dart`
- Join → write "ready" presence → **SessionLobbyScreen** ("Waiting for trainer to start…", joined
  count, Leave). Streams the session.
- `runState==running` → `pushReplacement` → **WorkoutScreen** (timer + tracking begin, elapsed
  synced to session clock).
- WorkoutScreen streams the session and reacts: **paused** → freeze tracking + "Paused" overlay;
  **resumed** → continue; **kicked** (uid in kickedUids) → remove own HR, pop to join with note;
  **ended** → summary (as today).
- `join_session_screen.dart` routes to the lobby and refuses entry if the athlete is in
  `kickedUids`.

### TV — `tv_host_screen.dart`
`lobby` → "Starting soon — join now" splash + QR; `running` → board; `paused` → dimmed "Paused".

### Demo — `session_store.dart`
Mirror the lifecycle (lobby/running/paused) with mock athletes trickling into the lobby and
Start/Pause/Resume working locally, so presentations show the feature.

## Security rules

One change: in `canWriteHr`, add `&& !(request.auth.uid in session.kickedUids)` so a kicked
athlete's HR writes are rejected server-side (defence in depth on top of the client block).
Host's `kickedUids` update is already allowed (host owns session updates). No other rule changes.

## Error handling

- All writes wrapped; transient failures non-fatal (Firestore offline queue). Athlete HR/leave
  failures are already swallowed (`.catchError`).
- Pause/Resume race (double tap): idempotent enough — recompute from current doc.
- If the session ends while an athlete is in the lobby: stream flips, athlete returns to join.

## Verification

Project discipline (no unit tests; analyze + live REST):
- `flutter analyze` clean; `flutter build web` OK.
- Live REST against beatsync-prod: new session writes (lobby create, begin, pause, resume, kick),
  and the kick rule **positive** (member can write HR) + **negative** (kicked uid denied).
- Manual two-window check by the user (coach hosts → lobby → athlete joins → appears → Start →
  both run → Pause/Resume → kick → athlete drops & blocked → End).
- Branch left **unmerged**.

## Files touched
`lib/models/cloud_session.dart`, `lib/services/session_repository.dart`,
`lib/services/session_store.dart`, `lib/screens/session_host_screen.dart`,
`lib/screens/trainer_monitor_screen.dart`, `lib/screens/workout_screen.dart`,
`lib/screens/join_session_screen.dart`, `lib/screens/session_lobby_screen.dart` (new),
`lib/screens/tv_host_screen.dart`, `firestore.rules`.
</content>
