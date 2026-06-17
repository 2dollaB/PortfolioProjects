import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../widgets/mobile_frame.dart';

/// One heading + body block in a legal document.
typedef LegalSection = ({String heading, String body});

/// Simple scrollable reader for a legal document (Privacy Policy / Terms).
/// Content is drafted below via the [LegalDocScreen.privacy] / [.terms]
/// constructors — plain copy suitable for a group-fitness HR app. Each string
/// is language-aware via [Strings.pick].
class LegalDocScreen extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final String intro;
  final List<LegalSection> sections;

  const LegalDocScreen({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
            ),
            children: [
              Text(title, style: AppTheme.h1()),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Strings.pick(
                    'Last updated $lastUpdated', 'Zadnje ažuriranje $lastUpdated'),
                style: AppTheme.caption(),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                intro,
                style: AppTheme.bodyLarge(color: AppColors.textSecondary),
              ),
              for (final s in sections) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(s.heading, style: AppTheme.h2()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.body,
                  style: AppTheme.bodyLarge(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                Strings.pick(
                  'Questions? Contact us at privacy@beatsync.app.',
                  'Pitanja? Kontaktirajte nas na privacy@beatsync.app.',
                ),
                style: AppTheme.caption(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Privacy Policy for BeatSync.
  factory LegalDocScreen.privacy() {
    return LegalDocScreen(
      title: Strings.pick('Privacy Policy', 'Pravila privatnosti'),
      lastUpdated: Strings.pick('June 16, 2026', '16. lipnja 2026.'),
      intro: Strings.pick(
        'BeatSync helps you and your fitness studio track heart rate during '
            'group workouts. This policy explains what we collect, why, and how '
            'it is used. We collect only what the app needs to work.',
        'BeatSync pomaže vama i vašem fitness studiju pratiti puls tijekom '
            'grupnih treninga. Ova pravila objašnjavaju što prikupljamo, zašto i '
            'kako se koristi. Prikupljamo samo ono što je aplikaciji potrebno za rad.',
      ),
      sections: [
        (
          heading: Strings.pick('What we collect', 'Što prikupljamo'),
          body: Strings.pick(
            'Account details (your email and the name you enter); your '
                'profile (age, sex, height, weight, resting heart rate and '
                'fitness level, used to estimate your heart-rate zones); your '
                'workout summaries (duration, average and max heart rate, time '
                'in each zone, training load); the studio you belong to; and, '
                'when you pair one, the name of your heart-rate strap. We do not '
                'collect precise location or payment information.',
            'Podatke računa (vašu e-poštu i ime koje unesete); vaš profil (dob, '
                'spol, visinu, težinu, puls u mirovanju i razinu kondicije, za '
                'procjenu zona pulsa); sažetke treninga (trajanje, prosječni i '
                'maksimalni puls, vrijeme u svakoj zoni, opterećenje); studio '
                'kojem pripadate; i, kada ga povežete, naziv vašeg mjerača pulsa. '
                'Ne prikupljamo preciznu lokaciju ni podatke o plaćanju.',
          ),
        ),
        (
          heading: Strings.pick('How it is stored', 'Kako se pohranjuje'),
          body: Strings.pick(
            'Your data is stored in Google Firebase (Firestore and Firebase '
                'Authentication) on our project beatsync-prod. Access is '
                'restricted by security rules so that, in general, only you can '
                'read and write your own profile and workouts.',
            'Vaši podaci pohranjeni su u Google Firebaseu (Firestore i Firebase '
                'Authentication) na projektu beatsync-prod. Pristup je ograničen '
                'sigurnosnim pravilima tako da, općenito, samo vi možete čitati i '
                'mijenjati vlastiti profil i treninge.',
          ),
        ),
        (
          heading: Strings.pick('Who can see it', 'Tko ih može vidjeti'),
          body: Strings.pick(
            'When you join a studio, the trainer who owns that studio can '
                'see your profile and workout summaries so they can coach you '
                'and run live sessions. Other athletes can see your name and '
                'live heart rate on the session board during a workout. If you '
                'leave the studio, the trainer loses this access for future '
                'sessions. We never sell your data or share it with advertisers.',
            'Kada se pridružite studiju, trener koji ga posjeduje može vidjeti '
                'vaš profil i sažetke treninga kako bi vas trenirao i vodio '
                'treninge uživo. Drugi sportaši mogu vidjeti vaše ime i puls '
                'uživo na ploči tijekom treninga. Ako napustite studio, trener '
                'gubi taj pristup za buduće treninge. Nikada ne prodajemo vaše '
                'podatke niti ih dijelimo s oglašivačima.',
          ),
        ),
        (
          heading: Strings.pick('Not medical advice', 'Nije medicinski savjet'),
          body: Strings.pick(
            'BeatSync is a fitness tool, not a medical device. Heart-rate '
                'readings and zones are estimates and may be inaccurate. Do not '
                'rely on the app for medical decisions. Consult a doctor before '
                'starting any exercise program, especially if you have a heart '
                'condition.',
            'BeatSync je fitness alat, a ne medicinski uređaj. Očitanja pulsa i '
                'zone su procjene i mogu biti netočne. Ne oslanjajte se na '
                'aplikaciju za medicinske odluke. Posavjetujte se s liječnikom '
                'prije početka bilo kakvog programa vježbanja, osobito ako imate '
                'srčano stanje.',
          ),
        ),
        (
          heading: Strings.pick('Deleting your data', 'Brisanje podataka'),
          body: Strings.pick(
            'You can leave a studio at any time from Settings → My studio. '
                'To delete your account and associated data, contact us at '
                'privacy@beatsync.app and we will remove your profile and '
                'workouts.',
            'Studio možete napustiti u bilo kojem trenutku u Postavke → Moj '
                'studio. Za brisanje računa i povezanih podataka kontaktirajte '
                'nas na privacy@beatsync.app i uklonit ćemo vaš profil i treninge.',
          ),
        ),
      ],
    );
  }

  /// Terms of Service for BeatSync.
  factory LegalDocScreen.terms() {
    return LegalDocScreen(
      title: Strings.pick('Terms of Service', 'Uvjeti korištenja'),
      lastUpdated: Strings.pick('June 16, 2026', '16. lipnja 2026.'),
      intro: Strings.pick(
        'These terms govern your use of BeatSync. By creating an account or '
            'using the app, you agree to them.',
        'Ovi uvjeti uređuju vaše korištenje BeatSynca. Stvaranjem računa ili '
            'korištenjem aplikacije prihvaćate ih.',
      ),
      sections: [
        (
          heading: Strings.pick('Eligibility', 'Uvjeti za korištenje'),
          body: Strings.pick(
            'You must be at least 16 years old (or have a guardian’s '
                'consent) and physically able to take part in exercise to use '
                'BeatSync.',
            'Morate imati najmanje 16 godina (ili pristanak skrbnika) i biti '
                'tjelesno sposobni sudjelovati u vježbanju da biste koristili BeatSync.',
          ),
        ),
        (
          heading: Strings.pick('Your account', 'Vaš račun'),
          body: Strings.pick(
            'You are responsible for keeping your login details secure and '
                'for activity under your account. Keep your profile information '
                'accurate so heart-rate estimates are meaningful.',
            'Odgovorni ste za čuvanje podataka za prijavu i za aktivnost na svom '
                'računu. Držite podatke profila točnima kako bi procjene pulsa '
                'bile smislene.',
          ),
        ),
        (
          heading: Strings.pick('Acceptable use', 'Prihvatljivo korištenje'),
          body: Strings.pick(
            'Use BeatSync only for its intended purpose. Do not attempt to '
                'access other users’ data, disrupt the service, or misuse '
                'studio invite codes.',
            'Koristite BeatSync samo u predviđenu svrhu. Ne pokušavajte '
                'pristupiti podacima drugih korisnika, ometati uslugu ili '
                'zlorabiti pozivne kodove studija.',
          ),
        ),
        (
          heading: Strings.pick('Health disclaimer', 'Zdravstvena napomena'),
          body: Strings.pick(
            'Heart-rate data and training metrics are informational only and '
                'are not medical advice. Exercise carries inherent risks; you '
                'take part at your own risk and should stop and seek help if you '
                'feel unwell.',
            'Podaci o pulsu i metrike treninga isključivo su informativni i '
                'nisu medicinski savjet. Vježbanje nosi rizike; sudjelujete na '
                'vlastitu odgovornost i trebali biste prestati i potražiti pomoć '
                'ako se osjećate loše.',
          ),
        ),
        (
          heading: Strings.pick('Service provided as-is', 'Usluga „kakva jest”'),
          body: Strings.pick(
            'BeatSync is provided “as is” without warranties of '
                'any kind. We do not guarantee the app will be uninterrupted, '
                'error-free, or that readings will be accurate.',
            'BeatSync se pruža „kakav jest” bez ikakvih jamstava. Ne jamčimo da '
                'će aplikacija raditi bez prekida, bez pogrešaka, ni da će '
                'očitanja biti točna.',
          ),
        ),
        (
          heading: Strings.pick('Termination & changes', 'Prekid i izmjene'),
          body: Strings.pick(
            'You may stop using BeatSync and request deletion at any time. '
                'We may update these terms as the app evolves; continued use '
                'after an update means you accept the revised terms.',
            'Možete prestati koristiti BeatSync i zatražiti brisanje u bilo '
                'kojem trenutku. Možemo ažurirati ove uvjete kako se aplikacija '
                'razvija; nastavak korištenja nakon ažuriranja znači prihvaćanje '
                'izmijenjenih uvjeta.',
          ),
        ),
      ],
    );
  }
}
