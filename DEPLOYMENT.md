# BeatSync — Deployment runbook

Step-by-step guide from a clean `main` checkout to test builds on both stores.
Written 2026-07-05. **No secrets in this file** (public repo) — passwords, keystore
credentials and test accounts live in `HANDOFF.local.md` (untracked).

---

## 0. One-time prerequisites (accounts & machines)

| What | Where | Cost | Lead time |
|---|---|---|---|
| Google Play Developer account | https://play.google.com/console/signup | $25 once | instant–few days (identity verification) |
| Apple Developer Program | https://developer.apple.com/programs/enroll | $99/year | 24–48 h |
| Mac (any — Mac mini works) with macOS 14+ | for iOS builds only | — | Xcode download ~1 h |
| Windows dev machine | Android builds (already set up) | — | — |

On the Mac (one-time):
```bash
# 1. Xcode from the App Store, then:
sudo xcode-select --install
sudo xcodebuild -license accept
# 2. Flutter SDK: https://docs.flutter.dev/get-started/install/macos
# 3. CocoaPods:
sudo gem install cocoapods
# 4. Verify:
flutter doctor
```

---

## 1. Versioning (both platforms)

Version lives in `pubspec.yaml` → `version: 1.0.0+1` (`name+buildNumber`).
**Bump the build number (+N) for every store upload**; bump the name (1.0.x)
for user-visible releases. Both stores reject re-uploads of the same build number.

---

## 2. Android — release build & Play internal testing

### 2.1 Signing (already configured)
- Keystore: `android/upload-keystore.jks` (gitignored). **BACK IT UP** — losing it
  means losing the Play upload key. Credentials: `HANDOFF.local.md`.
- Config: `android/key.properties` (gitignored). On a fresh machine, restore both
  files from backup; without them the build silently signs with debug keys.

### 2.2 Build
```powershell
cd C:\dev\beatsync
flutter pub get
flutter analyze                      # must be clean
flutter build appbundle --release    # → build\app\outputs\bundle\release\app-release.aab
```

### 2.3 Play Console (first upload)
1. Play Console → **Create app** — name "BeatSync", default language, App/Free.
2. **Testing → Internal testing → Create new release** → upload `app-release.aab`.
   Accept **Play App Signing** when offered (Google keeps the app signing key;
   our keystore stays the *upload* key).
3. Add tester emails (up to 100) under **Testers** → save → copy the opt-in link
   and send it to testers. Internal testing needs **no review** — live in minutes.
4. Before wider (closed/open) tracks Google requires the **store listing basics**:
   app description, icon, screenshots, privacy-policy URL (see §5), data-safety
   form (we collect: email, name, health data = heart rate; not shared; deletable
   in-app via Profile → Delete account).

### 2.4 Sideload fallback (no Play account yet)
```powershell
flutter build apk --release          # → build\app\outputs\flutter-apk\app-release.apk
```
Send the APK directly; testers enable "install unknown apps".

---

## 3. iOS — build on the Mac & TestFlight

### 3.1 First-time project setup (on the Mac)
```bash
git clone https://github.com/2dollaB/PortfolioProjects.git beatsync && cd beatsync
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace          # ALWAYS the .xcworkspace, never .xcodeproj
```
In Xcode → target **Runner** → **Signing & Capabilities**:
1. Sign in with the Apple Developer account (Xcode → Settings → Accounts).
2. Check **Automatically manage signing**, pick your **Team**.
3. Bundle id is already `com.beatsync.beatsync` (matches the registered Firebase iOS app).
4. `Info.plist` already has the Bluetooth usage string + `bluetooth-central`
   background mode — don't remove them, the app crashes on BLE use without the string.

### 3.2 Run on a physical iPhone (BLE needs real hardware)
```bash
flutter run --release -d <iphone-id>   # flutter devices to list
```
On the phone: Settings → General → VPN & Device Management → trust the developer cert.
Smoke test: login → pair strap (Profile → Connected devices) → workout → live session.

### 3.3 TestFlight upload
```bash
flutter build ipa --release            # → build/ios/archive + build/ios/ipa
```
Then either:
- **Xcode route**: `open build/ios/archive/Runner.xcarchive` → Distribute App →
  App Store Connect → Upload; or
- **CLI route**: upload `build/ios/ipa/*.ipa` with the **Transporter** app (Mac App Store).

In **App Store Connect** (appstoreconnect.apple.com):
1. My Apps → **+ New App** (first time): platform iOS, bundle id from the dropdown,
   SKU e.g. `beatsync-001`.
2. TestFlight tab → the build appears after ~15 min of processing.
3. **Internal testers** (your team, up to 100): available immediately, no review.
4. **External testers** (clients): create a group, add emails, submit for
   **Beta App Review** (usually 1–2 days, one-time per version). Export compliance:
   the app uses only standard HTTPS → answer "standard encryption, exempt".

### 3.4 App Store privacy questionnaire (needed before external TestFlight/App Store)
Declare: **Health & Fitness** (heart rate), **Contact info** (name, email),
**Identifiers** (user ID). Linked to identity: yes. Tracking: **no**.
Account deletion is in-app (Profile → Delete account) — reviewers check this.

---

## 4. Firebase deploys (backend)

Rules / indexes (whenever `firestore.rules` or `firestore.indexes.json` change):
```powershell
firebase deploy --only firestore --project beatsync-prod
```
Hosting (future TV link `beatsync.web.app/tv/{sessionId}`):
```powershell
flutter build web
firebase deploy --only hosting --project beatsync-prod
```
Crashlytics needs no deploy — dashboards appear in Firebase Console → Crashlytics
after the first release build runs on a device.

---

## 5. Pre-store checklist (before anything public)

- [ ] **Privacy policy + Terms on a public URL** — texts already exist in-app
      (`legal_doc_screen.dart`); host them (e.g. Firebase Hosting `/privacy`, `/terms`)
      and paste the URLs into both store listings.
- [ ] **Version label**: `main.dart`/settings footer still says "v1.0.0 (prototype)" — change before store review.
- [ ] **flutter_blue_plus license**: currently declares the non-commercial license.
      Fine for free testing; **before charging customers** buy the commercial license
      or pin to the last BSD release (1.35.x). See note in `ble_hr_service.dart`.
- [ ] **Keystore backed up** off-machine (see §2.1).
- [ ] Store assets: 512px icon, feature graphic (Play), 6.7"/6.5"/5.5" screenshots (Apple).
- [ ] Crashlytics dashboard checked after first tester sessions.

---

## 6. Related docs

- `HANDOFF.md` — project status source of truth (read first in any new session).
- `HANDOFF.local.md` (untracked) — all credentials: signing, test accounts, REST helpers.
- `SCREENS_MAP.md` — per-screen structural reference.
- Admin panel (separate private repo `C:\dev\beatsync-admin`) — its own
  `docs/HANDOFF.md` carries the cross-repo context; deploy target for it is Vercel (later).
