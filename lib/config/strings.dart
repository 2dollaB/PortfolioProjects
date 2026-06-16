/// BeatSync localization — lightweight string catalogue (English + Croatian).
///
/// Mirrors the theme system: a global [Strings.lang] flag is flipped by
/// `BeatSyncAppState.setLang` (which persists it and rebuilds the app), and
/// every UI string is a getter that resolves against it via [_pick]. English
/// and Croatian sit side by side so they're easy to review.
///
/// Add new strings in the section for the screen that uses them.
library;

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
