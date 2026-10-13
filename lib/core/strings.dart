import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_store.dart';

/// Tiny bilingual string table. Bengali is the primary language of the app;
/// English is offered for parents and bilingual classrooms.
class Strings {
  const Strings(this.lang);

  final AppLang lang;

  bool get isBn => lang == AppLang.bn;
  String t(String bn, String en) => isBn ? bn : en;

  // App
  String get appName => t('হাতের লেখা', 'Hater Lekha');
  String get tagline =>
      t('এসো সহজে লিখতে শিখি', "Let's learn to write, the easy way");
  String get whatToLearn => t('আজ কী শিখবে?', 'What shall we learn today?');
  String get parents => t('অভিভাবক', 'Parents');
  String get settings => t('সেটিংস', 'Settings');
  String get progress => t('অগ্রগতি', 'Progress');
  String get language => t('ভাষা', 'Language');
  String get langToggle => t('EN', 'বাং');

  // Practice
  String get watch => t('দেখো', 'Watch');
  String get trace => t('আঁকো', 'Trace');
  String get write => t('লেখো', 'Write');
  String get replay => t('আবার দেখো', 'Replay');
  String get clear => t('মুছো', 'Clear');
  String get next => t('পরেরটা', 'Next');
  String get previous => t('আগেরটা', 'Previous');
  String get again => t('আবার', 'Again');
  String get finish => t('শেষ', 'Done');
  String get startHere => t('এখান থেকে শুরু করো', 'Start here');
  String get tryAgain => t('আবার চেষ্টা করো', 'Try again');
  String get stayOnLine => t('রেখার উপর দিয়ে আঁকো', 'Stay on the dotted line');
  String get writeYourself => t('এবার নিজে নিজে লেখো', 'Now write it yourself');
  String get watchHint =>
      t('আঙুল দিয়ে অনুসরণ করো', 'Follow along with your finger');
  String get strokeBuildUp => t('ধাপে ধাপে', 'Step by step');
  String get yourWriting => t('তোমার লেখা', 'Your writing');
  String get allDone => t('সব শেষ! দারুণ!', 'All done! Amazing!');
  String get listen => t('শোনো', 'Listen');
  String stroke(int n) => t('আঁক ${num(n)}', 'Stroke $n');
  String of(int a, int b) => '${num(a)}/${num(b)}';
  String get stars => t('তারা', 'stars');

  List<String> get praise => isBn
      ? const ['সাবাশ!', 'খুব ভালো!', 'দারুণ!', 'চমৎকার!', 'বাহ্‌!']
      : const ['Well done!', 'Great job!', 'Awesome!', 'Excellent!', 'Wow!'];

  // Parent area
  String get parentGateTitle => t('অভিভাবকের জন্য', 'For grown-ups');
  String get parentGateQuestion =>
      t('প্রবেশ করতে উত্তর দাও', 'Answer to continue');
  String get wrongAnswer =>
      t('ঠিক হয়নি, আবার চেষ্টা করো', 'Not quite, try again');
  String get cancel => t('বাতিল', 'Cancel');
  String get totalStars => t('মোট তারা', 'Total stars');
  String get completed => t('সম্পন্ন', 'Completed');
  String get lastPracticed => t('শেষ অনুশীলন', 'Last practised');
  String get notYet => t('এখনো হয়নি', 'Not yet');
  String get today => t('আজ', 'Today');
  String get yesterday => t('গতকাল', 'Yesterday');
  String daysAgo(int d) => t('${num(d)} দিন আগে', '$d days ago');
  String get traceLabel => t('আঁকা', 'Trace');
  String get writeLabel => t('লেখা', 'Write');

  // Settings
  String get soundEffects => t('শব্দ ও কম্পন', 'Sounds & vibration');
  String get voice =>
      t('কণ্ঠস্বর (অক্ষর পড়ে শোনানো)', 'Voice (read letters aloud)');
  String get difficulty => t('কঠিনতা', 'Difficulty');
  String get easy => t('সহজ', 'Easy');
  String get normal => t('মাঝারি', 'Normal');
  String get hard => t('কঠিন', 'Hard');
  String get leftHanded => t('বাঁ-হাতি', 'Left-handed');
  String get leftHandedHint =>
      t('বোতামগুলো বাঁ দিকে রাখো', 'Keep the buttons on the left');
  String get resetProgress => t('অগ্রগতি মুছে ফেলো', 'Reset progress');
  String get resetConfirm => t(
    'সব তারা ও অগ্রগতি মুছে যাবে। নিশ্চিত?',
    'All stars and progress will be erased. Are you sure?',
  );
  String get reset => t('মুছে ফেলো', 'Reset');
  String get about => t('অ্যাপ সম্পর্কে', 'About');
  String get aboutText => t(
    'প্রাক্‌-প্রাথমিক শিশুদের জন্য বাংলা, ইংরেজি ও সংখ্যা লেখা শেখার অ্যাপ। '
        'হাতের লেখা শেখার প্রচলিত পদ্ধতি অনুসরণ করা হয়েছে: আগে হাত ঘুরানো, '
        'তারপর ধাপে ধাপে দেখা, বিন্দুর উপর আঁকা, এবং শেষে নিজে লেখা।',
    'A handwriting app for pre-primary children: Bengali, English and numbers. '
        'It follows the classic copybook method: warm-up strokes, watch step by step, '
        'trace over the dots, then write on your own.',
  );
  String get credits => t(
    'ফন্ট: Baloo Da 2 ও Hind Siliguri (SIL Open Font License)',
    'Fonts: Baloo Da 2 and Hind Siliguri (SIL Open Font License)',
  );

  /// Formats a non-negative integer in the current script.
  String num(int n) => isBn ? toBengaliDigits(n) : '$n';

  static const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  static String toBengaliDigits(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (final ch in s.runes) {
      if (ch >= 0x30 && ch <= 0x39) {
        out.write(_bnDigits[ch - 0x30]);
      } else {
        out.writeCharCode(ch);
      }
    }
    return out.toString();
  }
}

final stringsProvider = Provider<Strings>(
  (ref) => Strings(ref.watch(settingsProvider.select((s) => s.lang))),
);
