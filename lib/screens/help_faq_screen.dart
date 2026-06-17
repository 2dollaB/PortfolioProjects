import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../widgets/mobile_frame.dart';

/// Static help / frequently-asked-questions for athletes and trainers.
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  // Built at runtime so the copy follows the current language.
  List<({String q, String a})> get _faqs => [
        (
          q: Strings.pick('How do I join a studio?',
              'Kako se pridružiti studiju?'),
          a: Strings.pick(
            'Ask your trainer for their 6-digit invite code, then open '
                'Settings → My studio (or the “Join a studio” button on Home) and '
                'enter the code. You can belong to one studio at a time.',
            'Zatražite od trenera 6-znamenkasti pozivni kod, zatim otvorite '
                'Postavke → Moj studio (ili gumb „Pridruži se studiju” na početnoj) '
                'i unesite kod. Možete biti u jednom studiju istovremeno.',
          ),
        ),
        (
          q: Strings.pick('How do I leave or switch studios?',
              'Kako napustiti ili promijeniti studio?'),
          a: Strings.pick(
            'Go to Settings → My studio and tap “Leave studio”. Once you’ve left, '
                'you can join a different studio with its invite code.',
            'Otvorite Postavke → Moj studio i dodirnite „Napusti studio”. Nakon '
                'što odete, možete se pridružiti drugom studiju njegovim pozivnim kodom.',
          ),
        ),
        (
          q: Strings.pick('Which heart-rate straps work?',
              'Koji mjerači pulsa rade?'),
          a: Strings.pick(
            'Any standard Bluetooth heart-rate strap or watch that broadcasts '
                'heart rate — Polar, Garmin, Coros, Wahoo and similar. Pair it from '
                'Settings → Connected devices, then start a workout. (Apple Watch '
                'cannot broadcast heart rate to other apps.)',
            'Bilo koji standardni Bluetooth mjerač pulsa ili sat koji emitira puls '
                '— Polar, Garmin, Coros, Wahoo i slično. Povežite ga u '
                'Postavke → Povezani uređaji, zatim započnite trening. (Apple Watch '
                'ne može emitirati puls drugim aplikacijama.)',
          ),
        ),
        (
          q: Strings.pick('What do the heart-rate zones mean?',
              'Što znače zone pulsa?'),
          a: Strings.pick(
            'Zones are a percentage of your maximum heart rate, from Warmup '
                '(easy) to VO2 Max (all-out). They’re estimated from your age, sex '
                'and profile — keep those up to date in Personal info for the best '
                'accuracy.',
            'Zone su postotak vašeg maksimalnog pulsa, od Zagrijavanja (lagano) '
                'do VO2 Maks (maksimalno). Procjenjuju se iz vaše dobi, spola i '
                'profila — držite ih ažurnima u Osobnim podacima za najbolju točnost.',
          ),
        ),
        (
          q: Strings.pick('How does a live session work?',
              'Kako funkcionira trening uživo?'),
          a: Strings.pick(
            'Your trainer starts a session and you join from Home. During the '
                'session your heart rate appears on the studio board in real time. '
                'When it ends, your workout is saved to your history.',
            'Vaš trener pokreće trening, a vi se pridružujete s početne. Tijekom '
                'treninga vaš se puls prikazuje na ploči studija u stvarnom vremenu. '
                'Kad završi, trening se sprema u vašu povijest.',
          ),
        ),
        (
          q: Strings.pick('How is my data handled?',
              'Kako se postupa s mojim podacima?'),
          a: Strings.pick(
            'Your profile and workouts are stored securely and shared only with '
                'your studio’s trainer. See the Privacy Policy in Settings → Support '
                'for the full details.',
            'Vaš profil i treninzi pohranjeni su sigurno i dijele se samo s '
                'trenerom vašeg studija. Pogledajte Pravila privatnosti u '
                'Postavke → Podrška za sve pojedinosti.',
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(title: Text(Strings.helpFaq)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
            ),
            children: [
              for (final f in _faqs)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Theme(
                    // Drop the default ExpansionTile dividers for a clean card.
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
                      ),
                      iconColor: AppColors.brandRed,
                      collapsedIconColor: AppColors.textSecondary,
                      title: Text(f.q, style: AppTheme.bodyLarge(weight: FontWeight.w600)),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            f.a,
                            style: AppTheme.bodyLarge(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
