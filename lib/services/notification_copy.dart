/// Rotating, localized copy for the three daily reminder slots.
///
/// Every slot has several variants; the variant is chosen from the weekday so
/// that the reminders rotate naturally without re-scheduling.
class NotificationCopy {
  NotificationCopy._();

  static const List<String> slots = ['morning', 'midday', 'evening'];

  static String title(String lang, String slot) =>
      _titles[lang]?[slot] ?? _titles['en']![slot]!;

  static String body(String lang, String slot, int weekday) {
    final bodies = _bodies[lang]?[slot] ?? _bodies['en']![slot]!;
    return bodies[(weekday - 1) % bodies.length];
  }

  static const Map<String, Map<String, String>> _titles = {
    'en': {
      'morning': 'Morning check-in',
      'midday': 'Quick money check',
      'evening': 'Daily money check',
    },
    'fr': {
      'morning': 'Point du matin',
      'midday': 'Bilan rapide',
      'evening': 'Bilan du jour',
    },
    'ar': {
      'morning': 'تسجيل الصباح',
      'midday': 'متابعة سريعة',
      'evening': 'مراجعة اليوم',
    },
  };

  static const Map<String, Map<String, List<String>>> _bodies = {
    'en': {
      'morning': [
        'How does today\u2019s budget look? Log it in a few seconds.',
        'A quick morning check keeps your numbers clear.',
        'Start the day right — record your plans and spendings.',
      ],
      'midday': [
        'Just a quick glance: anything to log so far today?',
        'A fast money check protects your monthly budget.',
        'Two seconds to keep your finances on track.',
      ],
      'evening': [
        'Time to review today\u2019s expenses and income.',
        'How did today go? Log it before you forget.',
        'Close the day with a quick tracking update.',
      ],
    },
    'fr': {
      'morning': [
        'Comment se présente le budget du jour ? Enregistrez-le en quelques secondes.',
        'Un point du matin rapide garde des chiffres clairs.',
        'Bonne journée — notez vos dépenses dès maintenant.',
      ],
      'midday': [
        'Un rapide coup d\u2019œil : quelque chose à enregistrer ?',
        'Un bilan rapide protège le budget du mois.',
        'Deux secondes pour garder des finances à jour.',
      ],
      'evening': [
        'Il est temps de revoir les dépenses et revenus du jour.',
        'Comment s\u2019est passée la journée ? Notez-la avant d\u2019oublier.',
        'Terminez la journée avec un point de suivi rapide.',
      ],
    },
    'ar': {
      'morning': [
        'كيف يبدو ميزانية اليوم؟ سجّلها في ثوانٍ.',
        'تسجيل سريع صباحًا يُبقي أرقامك واضحة.',
        'ابدأ يومك جيدًا — سجّل خططك ومصاريفك.',
      ],
      'midday': [
        'نظرة سريعة: هل من شيء لتسجّله اليوم؟',
        'متابعة سريعة تحمي ميزانية الشهر.',
        'ثانيتان لإبقاء أموالك على المسار.',
      ],
      'evening': [
        'حان وقت مراجعة مصاريف ودخل اليوم.',
        'كيف كان يومك؟ سجّله قبل أن تنسى.',
        'اختم يومك بتحديث سريع لتتبع مصاريفك.',
      ],
    },
  };
}