/// BeatSync localization — lightweight string catalogue (English + Croatian).
///
/// Mirrors the theme system: a global [Strings.lang] flag is flipped by
/// `BeatSyncAppState.setLang` (which persists it and rebuilds the app), and
/// every UI string is a getter that resolves against it via [_pick]. English
/// and Croatian sit side by side so they're easy to review.
///
/// Add new strings in the section for the screen that uses them.
library;

import '../models/user_profile.dart';

enum AppLang {
  en,
  hr;

  String get code => name;

  /// Native label shown in the language picker.
  String get label => switch (this) {
        AppLang.en => 'English',
        AppLang.hr => 'Hrvatski',
      };
}

class Strings {
  Strings._();

  /// Current language — set at startup from prefs and by the Settings picker.
  static AppLang lang = AppLang.en;

  static String _pick(String en, String hr) => lang == AppLang.hr ? hr : en;

  /// Public inline picker — for screen-specific copy (legal text, FAQ) that
  /// isn't worth a named catalogue entry. Resolves against [lang].
  static String pick(String en, String hr) => _pick(en, hr);

  // ── Enum display (Sex / FitnessLevel) ────────────────────────
  static String sexName(Sex s) => switch (s) {
        Sex.male => _pick('Male', 'Muško'),
        Sex.female => _pick('Female', 'Žensko'),
        Sex.other => _pick('Other', 'Ostalo'),
      };
  static String fitnessName(FitnessLevel l) => switch (l) {
        FitnessLevel.beginner => _pick('Beginner', 'Početnik'),
        FitnessLevel.casual => _pick('Casual', 'Rekreativac'),
        FitnessLevel.advanced => _pick('Advanced', 'Napredni'),
      };
  static String fitnessDesc(FitnessLevel l) => switch (l) {
        FitnessLevel.beginner =>
          _pick('New to regular exercise', 'Novi u redovitom vježbanju'),
        FitnessLevel.casual =>
          _pick('Exercise 2-3 times/week', 'Vježbam 2-3 puta tjedno'),
        FitnessLevel.advanced =>
          _pick('Train 5+ times/week', 'Treniram 5+ puta tjedno'),
      };

  // ── Common / actions ─────────────────────────────────────────
  static String get cancel => _pick('Cancel', 'Odustani');
  static String get save => _pick('Save', 'Spremi');
  static String get done => _pick('Done', 'Gotovo');
  static String get retry => _pick('Retry', 'Pokušaj ponovno');
  static String get back => _pick('Back', 'Natrag');
  static String get none => _pick('None', 'Nema');
  static String get comingSoon => _pick('Coming soon', 'Uskoro');
  static String get backToHome => _pick('Back to home', 'Natrag na početnu');

  // ── Auth / onboarding ────────────────────────────────────────
  static String get welcomeBack => _pick('Welcome back', 'Dobrodošli natrag');
  static String get loginSubtitle => _pick(
      'Sign in to keep your training history in sync.',
      'Prijavite se kako bi vaša povijest treninga ostala sinkronizirana.');
  static String get email => _pick('Email', 'E-pošta');
  static String get password => _pick('Password', 'Lozinka');
  static String get forgotPassword =>
      _pick('Forgot password?', 'Zaboravljena lozinka?');
  static String get signIn => _pick('Sign in', 'Prijava');
  static String get continueWithGoogle =>
      _pick('Continue with Google', 'Nastavi s Googleom');
  static String get noAccount =>
      _pick("Don't have an account?", 'Nemate račun?');
  static String get haveAccount =>
      _pick('Already have an account?', 'Već imate račun?');
  static String get signUp => _pick('Sign up', 'Registracija');
  static String get logIn => _pick('Log in', 'Prijava');
  static String get or => _pick('OR', 'ILI');
  static String get demoAccounts => _pick('DEMO ACCOUNTS', 'DEMO RAČUNI');
  static String get emailRequired =>
      _pick('Email is required', 'E-pošta je obavezna');
  static String get emailInvalid =>
      _pick('Enter a valid email address', 'Unesite ispravnu e-poštu');
  static String get passwordRequired =>
      _pick('Password is required', 'Lozinka je obavezna');
  static String get passwordTooShort => _pick(
      'Password must be at least 6 characters',
      'Lozinka mora imati barem 6 znakova');
  static String get invalidCredentials =>
      _pick('Invalid credentials', 'Neispravni podaci za prijavu');

  // Register
  static String get createAccount => _pick('Create account', 'Stvori račun');
  static String get createYourAccount =>
      _pick('Create your account', 'Stvorite svoj račun');
  static String get registerTagline =>
      _pick('Two minutes — then you can train.',
          'Dvije minute — i možete trenirati.');
  static String get name => _pick('Name', 'Ime');
  static String get confirmPasswordRequired =>
      _pick('Please confirm your password', 'Potvrdite svoju lozinku');
  static String get bySigningUp => _pick(
      'By signing up you agree to our Terms & Privacy Policy.',
      'Registracijom prihvaćate naše Uvjete i Pravila privatnosti.');
  static String get backToLogin =>
      _pick('Back to login', 'Natrag na prijavu');
  static String get registerSubtitle => _pick(
      'Start tracking your heart rate in group sessions.',
      'Počnite pratiti svoj puls na grupnim treninzima.');
  static String get fullName => _pick('Full name', 'Ime i prezime');
  static String get nameRequired =>
      _pick('Name is required', 'Ime je obavezno');
  static String get confirmPassword =>
      _pick('Confirm password', 'Potvrdi lozinku');
  static String get passwordsDontMatch =>
      _pick("Passwords don't match", 'Lozinke se ne podudaraju');

  // Role select
  static String get pickYourRole =>
      _pick('Pick your role', 'Odaberite svoju ulogu');
  static String get roleTailor => _pick(
      "We'll tailor the experience for how you train.",
      'Prilagodit ćemo iskustvo načinu na koji trenirate.');
  static String get imAthlete => _pick("I'm an athlete", 'Ja sam sportaš');
  static String get athleteCardDesc => _pick(
      'Connect your HR strap, join sessions, track your training history.',
      'Povežite mjerač pulsa, pridružite se treninzima i pratite svoju povijest.');
  static String get imTrainer => _pick("I'm a trainer", 'Ja sam trener');
  static String get trainerCardDesc => _pick(
      'Run a studio, host live sessions, see every athlete in real time.',
      'Vodite studio, organizirajte treninge uživo i pratite svakog sportaša u stvarnom vremenu.');
  static String get continueLabel => _pick('Continue', 'Nastavi');

  // Splash + onboarding
  static String get trainTogether =>
      _pick('TRAIN TOGETHER', 'TRENIRAJTE ZAJEDNO');
  static String get skip => _pick('Skip', 'Preskoči');
  static String get next => _pick('Next', 'Dalje');
  static String get getStarted => _pick('Get started', 'Započni');
  static String get onbConnectTitle =>
      _pick('Connect your strap', 'Povežite svoj mjerač');
  static String get onbConnectBody => _pick(
      'BeatSync pairs with any Bluetooth heart-rate strap — Polar, Wahoo, Garmin, generic. Your BPM is live the moment you walk into the gym.',
      'BeatSync se povezuje s bilo kojim Bluetooth mjeračem pulsa — Polar, Wahoo, Garmin ili generički. Vaš puls je vidljiv čim uđete u teretanu.');
  static String get onbNotCompTitle =>
      _pick('Not a competition', 'Nije natjecanje');
  static String get onbNotCompBody => _pick(
      'BeatSync is a heart-rate monitoring tool for trainers. Train together, see the studio in real time — no podium, no ranking pressure.',
      'BeatSync je alat za praćenje pulsa za trenere. Trenirajte zajedno i pratite studio uživo — bez postolja i pritiska rangiranja.');

  // ── Profile-setup wizard ─────────────────────────────────────
  static String get ageRange =>
      _pick('Age must be between 13 and 100', 'Dob mora biti između 13 i 100');
  static String get weightRange => _pick('Weight must be between 30 and 250 kg',
      'Težina mora biti između 30 i 250 kg');
  static String get heightRange => _pick(
      'Height must be between 100 and 230 cm',
      'Visina mora biti između 100 i 230 cm');
  static String get restingHrRange => _pick(
      'Resting HR must be between 30 and 120 bpm',
      'Puls u mirovanju mora biti između 30 i 120 bpm');
  static String get studioNameRequired =>
      _pick('Studio name is required', 'Naziv studija je obavezan');
  static String setupFailed(Object e) =>
      _pick('Could not finish setup: $e', 'Postavljanje nije uspjelo: $e');

  static String get enterYourStudio =>
      _pick('Enter your studio', 'Uđite u svoj studio');
  static String get startTraining =>
      _pick('Start training', 'Započni trening');
  static String get createStudio => _pick('Create studio', 'Stvori studio');
  static String get skipForNow => _pick('Skip for now', 'Preskoči za sada');

  static String get personalProfileOverline =>
      _pick('Personal profile', 'Osobni profil');
  static String get buildYourRhythm =>
      _pick("Let's build your rhythm", 'Izgradimo vaš ritam');
  static String get personalSubtitle => _pick(
      'A few numbers to calibrate your zones and effort scores.',
      'Nekoliko brojki za kalibraciju vaših zona i ocjena napora.');
  static String get trainingProfileOverline =>
      _pick('Training profile', 'Trening profil');
  static String get fitnessQuestion =>
      _pick("What's your fitness level?", 'Koja je vaša razina kondicije?');
  static String get fitnessSubtitle => _pick(
      'Calibrates your training effect and calorie calculations.',
      'Kalibrira učinak treninga i izračun kalorija.');
  static String get strapOverline => _pick('Bluetooth', 'Bluetooth');
  static String get strapSubtitle => _pick(
      'Polar · Wahoo · Garmin · generic Bluetooth straps.',
      'Polar · Wahoo · Garmin · generički Bluetooth mjerači.');
  static String get yourStudioOverline => _pick('Your studio', 'Vaš studio');
  static String get buildYourSpace =>
      _pick('Build your space', 'Izgradite svoj prostor');
  static String get studioFormSubtitle => _pick(
      'This is where your athletes will join you.',
      'Ovdje će vam se pridružiti vaši sportaši.');

  static String get age => _pick('Age', 'Dob');
  static String get sex => _pick('Sex', 'Spol');
  static String get weight => _pick('Weight', 'Težina');
  static String get height => _pick('Height', 'Visina');
  static String get restingHrOptional =>
      _pick('Resting HR (optional)', 'Puls u mirovanju (opcionalno)');
  static String get restingHrTip => _pick(
      'Measure lying down in the morning before getting up.',
      'Izmjerite ležeći ujutro prije ustajanja.');
  static String get studioName => _pick('Studio name', 'Naziv studija');
  static String get locationOptional =>
      _pick('Location (optional)', 'Lokacija (opcionalno)');
  static String get maxMembers =>
      _pick('Maximum members', 'Najveći broj članova');
  static String get estimatedHrMax =>
      _pick('Estimated HR max', 'Procijenjeni maks. puls');
  static String get hrMaxInfoTitle => _pick('About HR max', 'O maks. pulsu');
  static String get hrMaxInfoBody => _pick(
      'BeatSync estimates your maximum heart rate from your age with the '
      'Tanaka formula: 208 − 0.7 × age. For women it uses the Gulati '
      'formula: 206 − 0.88 × age, which reflects female heart-rate response '
      'better. Both come from large clinical studies and are more accurate '
      'than the classic "220 − age". Your true maximum can still differ a '
      'little — if you exceed it during a workout, BeatSync raises it '
      'automatically.',
      'BeatSync procjenjuje vaš maksimalni puls iz dobi Tanaka formulom: '
      '208 − 0,7 × dob. Za žene koristi Gulati formulu: 206 − 0,88 × dob, '
      'koja bolje odražava ženski puls. Obje dolaze iz velikih kliničkih '
      'studija i preciznije su od klasične "220 − dob". Stvarni maksimum '
      'ipak može malo odstupati — ako ga premašite tijekom treninga, '
      'BeatSync ga automatski povećava.');
  static String get trainingProfileFallback =>
      _pick('your training profile', 'vaš trening profil');

  static String get searchForStraps => _pick('Search for straps', 'Traži mjerače');
  static String get pairLater => _pick(
      'You can also pair from settings later.',
      'Možete povezati i kasnije u postavkama.');
  static String get searchingStraps =>
      _pick('Searching for nearby straps…', 'Tražim obližnje mjerače…');
  static String get connected => _pick('Connected', 'Povezano');
  static String strapBattery(String name) =>
      _pick('$name · 92% battery', '$name · 92% baterije');
  static String get disconnect => _pick('Disconnect', 'Prekini vezu');

  static String get upToPrefix => _pick('Up to ', 'Do ');
  static String get membersSuffix => _pick('members', 'članova');
  static String get upgradeLater => _pick(
      'Upgrade later if you outgrow this.',
      'Nadogradite kasnije ako prerastete ovo.');
  static String get studioCreated => _pick('Studio created!', 'Studio stvoren!');
  static String get inviteCode => _pick('INVITE CODE', 'POZIVNI KOD');
  static String get shareInvite => _pick(
      'Share this with your athletes to join your studio.',
      'Podijelite ovo sa sportašima da se pridruže vašem studiju.');
  static String get yourStudioFallback => _pick('Your studio', 'Vaš studio');
  static String get createYourStudio =>
      _pick('Create your studio', 'Stvorite svoj studio');
  static String get upgradePlanLater => _pick(
      'You can upgrade your plan later if you outgrow this.',
      'Plan možete nadograditi kasnije ako prerastete ovo.');

  // ── Athlete home ─────────────────────────────────────────────
  static String get goodMorning => _pick('Good morning', 'Dobro jutro');
  static String get goodAfternoon => _pick('Good afternoon', 'Dobar dan');
  static String get goodEvening => _pick('Good evening', 'Dobra večer');
  static String get readyWhenYouAre =>
      _pick('READY WHEN YOU ARE', 'SPREMNI KAD I VI');
  static String get startWorkout => _pick('Start workout', 'Započni trening');
  static String get startWorkoutSubtitle => _pick(
      "We'll connect your HR strap and pick up where you left off.",
      'Povezat ćemo vaš mjerač pulsa i nastaviti gdje ste stali.');
  static String get lastSessionPrefix =>
      _pick('Last session · ', 'Zadnji trening · ');
  static String avgDuration(String dur) =>
      _pick('avg · $dur', 'prosj. · $dur');
  static String get thisWeek => _pick('This week', 'Ovaj tjedan');
  static String get recentWorkouts =>
      _pick('Recent workouts', 'Nedavni treninzi');
  static String get seeAll => _pick('See all', 'Prikaži sve');
  static String get noWorkoutsYet => _pick(
      'No workouts yet.\nFinish a session and it shows up here.',
      'Još nema treninga.\nZavršite trening i pojavit će se ovdje.');
  static String get sessions => _pick('Sessions', 'Treninzi');
  static String get thisWeekUnit => _pick('this week', 'ovaj tjedan');
  static String get time => _pick('Time', 'Vrijeme');
  static String get joinAStudio => _pick('Join a studio', 'Pridruži se studiju');
  static String get joinStudioHint => _pick(
      "Enter your trainer's 6-digit code",
      'Unesite trenerov 6-znamenkasti kod');
  static String get joinGroupSession =>
      _pick('Join a group session', 'Pridruži se grupnom treningu');
  static String get scanQrFromTrainer => _pick(
      'Scan the QR from your trainer', 'Skenirajte QR od svog trenera');

  // ── Join studio ──────────────────────────────────────────────
  static String get enterStudioCode =>
      _pick('Enter your studio code', 'Unesite kod studija');
  static String get studioCodeSubtitle => _pick(
      'Your trainer shares a 6-digit code to join their studio.',
      'Vaš trener dijeli 6-znamenkasti kod za pridruživanje studiju.');
  static String get enterCodeError => _pick(
      'Enter the 6-digit code from your trainer.',
      'Unesite 6-znamenkasti kod od svog trenera.');
  static String get notSignedIn =>
      _pick('You are not signed in.', 'Niste prijavljeni.');
  static String get codeNoMatch => _pick(
      "That code didn't match a studio.",
      'Taj kod ne odgovara nijednom studiju.');
  static String couldNotJoin(Object e) =>
      _pick('Could not join: $e', 'Pridruživanje nije uspjelo: $e');
  static String get joinedStudio =>
      _pick('You joined the studio!', 'Pridružili ste se studiju!');
  static String get joinStudioBtn => _pick('Join studio', 'Pridruži se');

  // ── Join / live session ──────────────────────────────────────
  static String get joinSession => _pick('Join session', 'Pridruži se treningu');
  static String get removedFromSession => _pick(
      'You were removed from this session.',
      'Uklonjeni ste s ovog treninga.');
  static String get waitingToStart =>
      _pick('waiting to start', 'čeka početak');
  static String get justStarted => _pick('just started', 'upravo započeo');
  static String startedMinAgo(int m) =>
      _pick('started ${m}m ago', 'započeo prije $m min');
  static String get joinStudioFirst => _pick(
      'Join a studio first —\ngroup sessions happen inside one.',
      'Prvo se pridružite studiju —\ngrupni treninzi odvijaju se unutar njega.');
  static String get scanQrTitle => _pick(
      'Scan the QR code from your trainer',
      'Skenirajte QR kod od svog trenera');
  static String get holdSteady => _pick(
      'Hold your phone steady — we connect automatically.',
      'Držite telefon mirno — povezujemo se automatski.');
  static String get orEnterCode => _pick('OR ENTER CODE', 'ILI UNESITE KOD');
  static String get noLiveSession =>
      _pick('No live session right now', 'Trenutno nema treninga uživo');
  static String get noLiveSessionHint => _pick(
      'When your trainer starts one,\nit shows up here automatically.',
      'Kad ga vaš trener pokrene,\npojavit će se ovdje automatski.');
  static String get liveNow => _pick('LIVE NOW', 'UŽIVO SADA');
  static String get scanning => _pick('Scanning…', 'Skeniram…');

  // Session lobby (waiting room)
  static String get waitingForTrainer => _pick(
      'Waiting for your trainer to start…', 'Čekanje da trener započne…');
  static String connectionIssue(Object e) =>
      _pick('Connection issue: $e', 'Problem s vezom: $e');
  static String get youreInTheRoom =>
      _pick("You're in the room", 'Vi ste u sobi');
  static String nInTheRoom(int n) => _pick('$n in the room', '$n u sobi');
  static String get leave => _pick('Leave', 'Napusti');

  // ── Workout (live) ───────────────────────────────────────────
  static String get endWorkoutTitle =>
      _pick('End workout?', 'Završiti trening?');
  static String get endWorkoutBody => _pick(
      "We'll save your session and show you the summary.",
      'Spremit ćemo trening i prikazati sažetak.');
  static String get endLabel => _pick('End', 'Završi');
  static String get simulated => _pick('Simulated', 'Simulirano');
  static String get liveStudioSession =>
      _pick('LIVE · Studio session', 'UŽIVO · Studijski trening');
  static String get pausedByTrainer =>
      _pick('Paused by trainer', 'Pauzirao trener');
  static String get paused => _pick('Paused', 'Pauzirano');
  static String get duration => _pick('Duration', 'Trajanje');
  static String get calories => _pick('Calories', 'Kalorije');
  static String get resume => _pick('Resume', 'Nastavi');
  static String get pause => _pick('Pause', 'Pauza');
  static String get viewWholeStudio =>
      _pick('View whole studio', 'Pogledaj cijeli studio');
  static String get seeEveryone => _pick(
      'See everyone training together', 'Vidite sve kako treniraju zajedno');

  // ── Workout summary ──────────────────────────────────────────
  static String get workoutSummary =>
      _pick('Workout summary', 'Sažetak treninga');
  static String get workoutFallback => _pick('Workout', 'Trening');
  static String get average => _pick('AVERAGE', 'PROSJEK');
  static String get peak => _pick('PEAK', 'VRHUNAC');
  static String get timeInZones => _pick('Time in zones', 'Vrijeme u zonama');
  static String get details => _pick('Details', 'Detalji');
  static String get avgHr => _pick('Avg HR', 'Prosj. puls');
  static String get maxHr => _pick('Max HR', 'Maks. puls');
  static String get hrMaxPct => _pick('HR Max %', '% maks. pulsa');
  static String get saveWorkout => _pick('Save workout', 'Spremi trening');
  static String get discard => _pick('Discard', 'Odbaci');

  // ── Workout history ──────────────────────────────────────────
  static String get history => _pick('History', 'Povijest');
  static String get filterAll => _pick('All', 'Sve');
  static String get filterThisMonth => _pick('This month', 'Ovaj mjesec');
  static String get noWorkoutsMatch => _pick(
      'No workouts match your filters.',
      'Nijedan trening ne odgovara filtrima.');
  static String get couldNotLoadWorkouts => _pick(
      'Could not load workouts.', 'Učitavanje treninga nije uspjelo.');
  static String get statAvg => _pick('AVG', 'PROSJ');
  static String get statMax => _pick('MAX', 'MAKS');

  /// Display label for a filter time key ('All' / 'This week' / 'This month').
  static String timeFilterLabel(String key) => switch (key) {
        'This week' => thisWeek,
        'This month' => filterThisMonth,
        _ => filterAll,
      };

  /// Localized display for an English workout type label. Values stay English
  /// in the model; this maps them for display only.
  static String workoutTypeLabel(String en) => switch (en.toLowerCase()) {
        'cardio' => _pick('Cardio', 'Kardio'),
        'strength' => _pick('Strength', 'Snaga'),
        'cycling' => _pick('Cycling', 'Biciklizam'),
        'yoga' => _pick('Yoga', 'Joga'),
        'endurance' => _pick('Endurance', 'Izdržljivost'),
        _ => en, // HIIT, CrossFit, etc. — keep as-is
      };

  static String workoutTypeDesc(String en) => switch (en.toLowerCase()) {
        'hiit' =>
          _pick('High-intensity intervals', 'Intervali visokog intenziteta'),
        'strength' => _pick('Weights · resistance', 'Utezi · otpor'),
        'endurance' => _pick('Long, steady effort', 'Dug, ravnomjeran napor'),
        'cardio' =>
          _pick('Sustained moderate pace', 'Umjeren, postojan tempo'),
        'crossfit' => _pick('Functional · circuits', 'Funkcionalno · kružni'),
        _ => '',
      };
  static String get whatTraining =>
      _pick('What are you training?', 'Što treniraš?');
  static String get tagSessionHint => _pick(
      "We'll tag your session so you can filter by type later.",
      'Označit ćemo trening da ga kasnije možete filtrirati po vrsti.');

  // ── Trainer home ─────────────────────────────────────────────
  static String get coach => _pick('Coach', 'Trener');
  static String get liveNowLower => _pick('live now', 'uživo sada');
  static String athletesCount(int n) => _pick('$n athletes', '$n sportaša');
  static String get studioAtGlance =>
      _pick('Studio at a glance', 'Studio na prvi pogled');
  static String get noSessionsYet => _pick(
      'No sessions yet — start your first.',
      'Još nema treninga — pokrenite prvi.');
  static String get activeToday => _pick('Active today', 'Aktivni danas');
  static String get members => _pick('Members', 'Članovi');
  static String get sessionsPerWk =>
      _pick('Sessions / week', 'Treninga / tjedan');
  static String get today => _pick('Today', 'Danas');
  static String get yesterday => _pick('Yesterday', 'Jučer');
  static String daysAgo(int n) => _pick('$n days ago', 'prije $n dana');
  static String get recentSessions =>
      _pick('Recent sessions', 'Nedavni treninzi');
  static String get live => _pick('LIVE', 'UŽIVO');
  static String get length => _pick('LENGTH', 'TRAJANJE');
  static String get openSession => _pick('Open session', 'Otvori trening');
  static String get readyToTrain =>
      _pick('READY TO TRAIN', 'SPREMNI ZA TRENING');
  static String get startNewSession =>
      _pick('Start new session', 'Pokreni novi trening');
  static String get startSessionSubtitle => _pick(
      "Pick the type, set intervals, share the code — and you're live.",
      'Odaberite vrstu, postavite intervale, podijelite kod — i krećete uživo.');
  static String get createSession => _pick('Create session', 'Stvori trening');

  // ── Member list ──────────────────────────────────────────────
  static String nSessions(int n) => _pick('$n sessions', '$n treninga');
  static String get inviteAthlete =>
      _pick('Invite an athlete', 'Pozovi sportaša');
  static String get inviteShareHint => _pick(
      'Share this code or QR — they enter it in the app.',
      'Podijelite kod ili QR — unose ga u aplikaciji.');
  static String get shareInviteBtn =>
      _pick('Share invite', 'Podijeli pozivnicu');
  static String get couldNotLoadStudio => _pick(
      'Could not load your studio.', 'Učitavanje studija nije uspjelo.');
  static String get couldNotLoadMembers => _pick(
      'Could not load members.', 'Učitavanje članova nije uspjelo.');
  static String get noMembersYet => _pick(
      'No members yet.\nShare your invite code — athletes join with it.',
      'Još nema članova.\nPodijelite pozivni kod — sportaši se pridružuju njime.');
  static String get searchByName => _pick('Search by name', 'Pretraži po imenu');
  static String get invite => _pick('Invite', 'Pozovi');
  static String get inactive => _pick('Inactive', 'Neaktivni');
  static String get noSessionsYetMember =>
      _pick('No sessions yet', 'Još nema treninga');
  static String memberFilterLabel(String key) => switch (key) {
        'Active today' => activeToday,
        'Inactive' => inactive,
        _ => filterAll,
      };

  // ── Trainer: member detail ───────────────────────────────────
  static String get notesSaved => _pick('Notes saved', 'Bilješke spremljene');
  static String get notesSaveFailed =>
      _pick('Could not save notes.', 'Spremanje bilješki nije uspjelo.');
  static String get noWorkoutsShort =>
      _pick('No workouts yet', 'Još nema treninga');
  static String lastWorkout(String date) =>
      _pick('Last workout · $date', 'Zadnji trening · $date');
  static String get avgTrimp => _pick('Avg TRIMP', 'Pros. TRIMP');
  static String get attendance12w =>
      _pick('Attendance · last 12 weeks', 'Dolasci · zadnjih 12 tjedana');
  static String get trimpTrend8w =>
      _pick('TRIMP trend · last 8 weeks', 'TRIMP trend · zadnjih 8 tjedana');
  static String get trainerNotes => _pick('Trainer notes', 'Bilješke trenera');
  static String get onlyYouSee =>
      _pick('Only you can see these.', 'Samo vi ovo vidite.');
  static String get addAthleteNote => _pick(
      'Add notes about this athlete…', 'Dodajte bilješke o ovom sportašu…');
  static String get saveNotes => _pick('Save notes', 'Spremi bilješke');

  // ── Trainer: studio analytics ────────────────────────────────
  static String get analytics => _pick('Analytics', 'Analitika');
  static String get last8Weeks => _pick('Last 8 weeks', 'Zadnjih 8 tjedana');
  static String get hours => _pick('Hours', 'Sati');
  static String get athletes => _pick('Athletes', 'Sportaši');
  static String get attendanceTitle => _pick('Attendance', 'Dolasci');
  static String get athletesPerWeek =>
      _pick('Athletes per week', 'Sportaša tjedno');
  static String get groupTrimp => _pick('Group TRIMP', 'Grupni TRIMP');
  static String get averagePerSession =>
      _pick('Average per session', 'Prosjek po treningu');
  static String get topAthletes =>
      _pick('Top athletes', 'Najaktivniji sportaši');
  static String get mostActiveMonth =>
      _pick('Most active this month', 'Najaktivniji ovaj mjesec');
  static String get noWorkoutsMonth => _pick(
      'No workouts this month yet.', 'Još nema treninga ovaj mjesec.');
  static String get sessionsLower => _pick('sessions', 'treninga');

  // ── Sessions (history / detail) ──────────────────────────────
  static String get allSessions => _pick('All sessions', 'Sve sesije');
  static String get filterThisWeek => _pick('This week', 'Ovaj tjedan');
  static String get noSessionsMatch => _pick(
      'No sessions match your filters.', 'Nijedna sesija ne odgovara filtrima.');
  static String get athletesLower => _pick('athletes', 'sportaša');
  static String get sessionAnalytics =>
      _pick('Session analytics', 'Analitika sesije');
  static String get dominant => _pick('Dominant', 'Dominantna');
  static String get groupAvgAllAthletes => _pick(
      'Group average across all athletes', 'Grupni prosjek svih sportaša');
  static String participated(int n) =>
      _pick('$n participated', '$n sudjelovalo');
  static String get avgGroupHr => _pick('AVG GROUP HR', 'PROS. GRUPNI PULS');
  static String get groupTrimpCaps => _pick('GROUP TRIMP', 'GRUPNI TRIMP');
  static String get avgPerAthlete =>
      _pick('avg per athlete', 'prosj. po sportašu');
  static String avgPeak(int avg, int peak) =>
      _pick('avg $avg · peak $peak', 'prosj. $avg · vrh $peak');
  static String get couldNotLoadResults => _pick(
      "Couldn't load this session's results.",
      'Učitavanje rezultata nije uspjelo.');
  static String get noSavedWorkoutsYet => _pick(
      'No saved workouts yet — results appear once athletes end their workout.',
      'Još nema spremljenih treninga — rezultati se pojavljuju kad sportaši završe trening.');
  static String get refresh => _pick('Refresh', 'Osvježi');

  // ── Trainer: start/host session ──────────────────────────────
  static String get startSessionTitle => _pick('Start session', 'Novi trening');
  static String get untitledSession =>
      _pick('Untitled session', 'Bezimeni trening');
  static String get couldNotStartSession => _pick(
      'Could not start the session. Try again.',
      'Pokretanje treninga nije uspjelo. Pokušajte ponovno.');
  static String get sessionNameLabel => _pick('Session name', 'Naziv treninga');
  static String get typeLabel => _pick('Type', 'Vrsta');
  static String get intervalTimer =>
      _pick('Interval timer', 'Intervalni tajmer');
  static String get intervalTimerDesc => _pick(
      'Auto work/rest cycles with countdown.',
      'Automatski ciklusi rada/odmora s odbrojavanjem.');
  static String get work => _pick('Work', 'Rad');
  static String get rest => _pick('Rest', 'Odmor');
  static String get rounds => _pick('Rounds', 'Runde');
  static String get sec => _pick('sec', 'sek');
  static String get qrJoinHint => _pick(
      'Athletes will scan a QR code to join once you launch the session.',
      'Sportaši skeniraju QR kod za pridruživanje nakon što pokrenete trening.');
  static String get launchSession =>
      _pick('Launch session', 'Pokreni trening');

  // ── Trainer: live monitor ────────────────────────────────────
  static String get complete => _pick('Complete', 'Završeno');
  static String roundOf(int r, int total) =>
      _pick('Round $r/$total', 'Runda $r/$total');
  static String get couldNotStartWorkout => _pick(
      'Could not start the workout. Try again.',
      'Pokretanje treninga nije uspjelo. Pokušajte ponovno.');
  static String get couldNotPause => _pick(
      'Could not pause. Try again.', 'Pauziranje nije uspjelo. Pokušajte ponovno.');
  static String get couldNotResume => _pick(
      'Could not resume. Try again.', 'Nastavak nije uspio. Pokušajte ponovno.');
  static String get couldNotRemoveAthlete => _pick(
      'Could not remove athlete. Try again.',
      'Uklanjanje sportaša nije uspjelo. Pokušajte ponovno.');
  static String get couldNotEndSession => _pick(
      'Could not end the session. Try again.',
      'Završavanje treninga nije uspjelo. Pokušajte ponovno.');
  static String removeAthleteTitle(String name) =>
      _pick('Remove $name?', 'Ukloniti $name?');
  static String get removeAthleteBody => _pick(
      "They'll be dropped from the session and can't rejoin it.",
      'Bit će uklonjen iz treninga i ne može se ponovno pridružiti.');
  static String get remove => _pick('Remove', 'Ukloni');
  static String get lobbyWaiting =>
      _pick('Lobby · waiting to start', 'Predvorje · čeka se početak');
  static String get inTheRoom => _pick('In the room', 'U sobi');
  static String get waitingForAthletes => _pick(
      'Waiting for athletes to join…\nShare the QR / invite code.',
      'Čekanje da se sportaši pridruže…\nPodijelite QR / pozivni kod.');
  static String get intensity => _pick('Intensity', 'Intenzitet');
  static String get endSessionTitle =>
      _pick('End session?', 'Završiti sesiju?');
  static String get endSessionBody => _pick(
      'This ends the workout for everyone and shows the results.',
      'Ovo završava trening za sve i prikazuje rezultate.');
  static String get endSession => _pick('End session', 'Završi sesiju');
  static String get ready => _pick('Ready', 'Spreman');

  // ── TV host board ────────────────────────────────────────────
  static String get tvNoLiveSession => _pick(
      'No live session right now — the board lights up when one starts.',
      'Trenutno nema treninga uživo — ploča se pali kad trening počne.');
  static String get pausedCaps => _pick('PAUSED', 'PAUZIRANO');
  static String get startingSoon => _pick('STARTING SOON', 'USKORO POČINJE');
  static String get getIntoPosition => _pick(
      'Get into position — scan the code to join',
      'Zauzmite mjesta — skenirajte kod za pridruživanje');
  static String get waitingForAthletesShort =>
      _pick('Waiting for athletes…', 'Čekanje sportaša…');
  static String get waitingToJoin => _pick(
      'Waiting for athletes to join…', 'Čekanje da se sportaši pridruže…');

  // ── Health data ──────────────────────────────────────────────
  static String get restingHrLabel => _pick('Resting HR', 'Puls u mirovanju');
  static String get fitnessLevel => _pick('Fitness level', 'Razina kondicije');
  static String zoneName(int z) => switch (z) {
        0 => _pick('Rest', 'Odmor'),
        1 => _pick('Warmup', 'Zagrijavanje'),
        2 => _pick('Fat Burn', 'Sagorijevanje masti'),
        3 => _pick('Aerobic', 'Aerobno'),
        4 => _pick('Anaerobic', 'Anaerobno'),
        _ => _pick('VO2 Max', 'VO2 Maks'),
      };

  // ── Device pairing ───────────────────────────────────────────
  static String get heartRateSensor =>
      _pick('Heart rate sensor', 'Mjerač pulsa');
  static String get btPermissionNeeded => _pick(
      'Bluetooth permission is needed to find your sensor.',
      'Za pronalazak senzora potrebno je dopuštenje za Bluetooth.');
  static String get pairYourSensor =>
      _pick('Pair your sensor', 'Povežite svoj senzor');
  static String get pairSensorSubtitle => _pick(
      'Any Bluetooth chest strap works — or a sports watch in '
          'heart-rate broadcast mode.',
      'Radi bilo koji Bluetooth prsni mjerač — ili sportski sat u '
          'načinu emitiranja pulsa.');
  static String get couldNotConnectSensor => _pick(
      "Couldn't connect — make sure the sensor is awake "
          'and close by, then try again.',
      'Povezivanje nije uspjelo — provjerite je li senzor aktivan '
          'i blizu, pa pokušajte ponovno.');
  static String get tryAgain => _pick('Try again', 'Pokušaj ponovno');
  static String get startScanning =>
      _pick('Start scanning', 'Započni skeniranje');
  static String connectingTo(String name) =>
      _pick('Connecting to $name…', 'Povezivanje s $name…');
  static String get holdTight => _pick(
      'Hold tight — this takes a few seconds.',
      'Strpljenja — ovo traje nekoliko sekundi.');
  static String get wearStrap => _pick(
      'Wear the strap so it wakes up and starts advertising.',
      'Stavite mjerač da se aktivira i počne emitirati.');
  static String get lookingForSensors =>
      _pick('Looking for sensors nearby…', 'Tražim senzore u blizini…');
  static String get stop => _pick('Stop', 'Zaustavi');
  static String get connectedCaps => _pick('CONNECTED', 'POVEZANO');
  static String get waitingFirstBeat =>
      _pick('Waiting for the first heartbeat…', 'Čekanje prvog otkucaja…');
  static String get liveHrReady => _pick(
      'Live heart rate — you’re ready to train.',
      'Puls uživo — spremni ste za trening.');
  static String get signalLabel => _pick('Signal', 'Signal');
  static String get signalStrong => _pick('Strong', 'Jak');
  static String get signalGood => _pick('Good', 'Dobar');
  static String get signalWeak => _pick('Weak', 'Slab');

  // ── Live-board widgets ───────────────────────────────────────
  static String get workCaps => _pick('WORK', 'RAD');
  static String get restCaps => _pick('REST', 'ODMOR');
  static String get standbyCaps => _pick('STANDBY', 'PRIPRAVNOST');
  static String get athletesCaps => _pick('ATHLETES', 'SPORTAŠI');
  static String get timeCaps => _pick('TIME', 'VRIJEME');
  static String get standby => _pick('Standby', 'Pripravnost');
  static String get athletesJoinCode =>
      _pick('Athletes join with this code', 'Sportaši se pridružuju ovim kodom');
  static String get less => _pick('Less', 'Manje');
  static String get more => _pick('More', 'Više');
  static String hrvQuality(int rmssd) {
    if (rmssd <= 0) return _pick('N/A', 'N/D');
    if (rmssd < 20) return _pick('Low', 'Nizak');
    if (rmssd < 50) return _pick('Normal', 'Normalan');
    if (rmssd < 100) return _pick('Good', 'Dobar');
    return _pick('Excellent', 'Izvrstan');
  }

  // ── Settings: sections + rows ────────────────────────────────
  static String get account => _pick('Account', 'Račun');
  static String get app => _pick('App', 'Aplikacija');
  static String get studio => _pick('Studio', 'Studio');
  static String get support => _pick('Support', 'Podrška');

  static String get personalInfo => _pick('Personal info', 'Osobni podaci');
  static String get healthData => _pick('Health data', 'Zdravstveni podaci');
  static String get connectedDevices =>
      _pick('Connected devices', 'Povezani uređaji');
  static String get appearance => _pick('Appearance', 'Izgled');
  static String get language => _pick('Language', 'Jezik');
  static String get myStudio => _pick('My studio', 'Moj studio');
  static String get subscription => _pick('Subscription', 'Pretplata');
  static String get helpFaq => _pick('Help & FAQ', 'Pomoć i ČPP');
  static String get privacyPolicy =>
      _pick('Privacy policy', 'Pravila privatnosti');
  static String get termsOfService =>
      _pick('Terms of service', 'Uvjeti korištenja');
  static String get signOut => _pick('Sign out', 'Odjava');

  // Appearance options
  static String get themeLight => _pick('Light', 'Svijetlo');
  static String get themeDark => _pick('Dark', 'Tamno');
  static String get themeSystem => _pick('System', 'Sustav');

  // Settings header / stats
  static String get athlete => _pick('Athlete', 'Sportaš');
  static String get trainer => _pick('Trainer', 'Trener');
  static String get workouts => _pick('Workouts', 'Treninzi');
  static String get totalTime => _pick('Total time', 'Ukupno vrijeme');
  static String get hrMax => _pick('HR max', 'Maks. puls');
  static String get noStudioYet => _pick('None yet', 'Još nema');
  static String get free => _pick('Free', 'Besplatno');
}
