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
