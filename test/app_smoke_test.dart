import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hater_lekha/app.dart';
import 'package:hater_lekha/data/glyph_repository.dart';
import 'package:hater_lekha/data/models.dart';
import 'package:hater_lekha/data/prefs.dart';
import 'package:hater_lekha/data/progress_store.dart';
import 'package:hater_lekha/data/settings_store.dart';
import 'package:hater_lekha/features/category/category_screen.dart';
import 'package:hater_lekha/features/parent/parent_hub.dart';
import 'package:hater_lekha/features/parent/progress_screen.dart';
import 'package:hater_lekha/features/parent/settings_screen.dart';
import 'package:hater_lekha/features/practice/practice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real asset, read from disk so the test never waits on the bundle.
final GlyphSet glyphSet = GlyphSet.fromJson(
  jsonDecode(File('assets/data/glyphs.json').readAsStringSync())
      as Map<String, dynamic>,
);

Future<Widget> app() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      glyphSetProvider.overrideWith((ref) async => glyphSet),
    ],
    child: const HaterLekhaApp(),
  );
}

/// Lay the app out at a typical phone size instead of the 800x600 default.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2160);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

void main() {
  parentTests();
  testWidgets('home shows every category and the parent lock', (tester) async {
    phone(tester);
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    expect(find.text('হাতের লেখা'), findsOneWidget);
    expect(find.text('স্বরবর্ণ'), findsOneWidget);
    expect(find.text('ব্যঞ্জনবর্ণ'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('language toggle switches the UI to English', (tester) async {
    phone(tester);
    await tester.pumpWidget(await app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.translate_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Hater Lekha'), findsOneWidget);
    expect(find.text('Bengali vowels'), findsOneWidget);
  });

  testWidgets(
    'tapping a category opens the letter grid and a letter opens practice',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(await app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('স্বরবর্ণ'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryScreen), findsOneWidget);
      expect(find.text('অ'), findsWidgets);
      await tester.tap(find.text('অ').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(find.text('স্বরে অ'), findsOneWidget);
      // Switch to trace mode and check the first-stroke hint shows up.
      await tester.tap(find.text('আঁকো'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('আঁক ১'), findsOneWidget);
    },
  );

  test('progress store persists and only raises stars', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final n = container.read(progressProvider.notifier);
    n.record('bn_vowel_00', PracticeMode.trace, 2);
    n.record('bn_vowel_00', PracticeMode.trace, 1);
    expect(container.read(progressProvider).of('bn_vowel_00').traceStars, 2);
    expect(container.read(progressProvider).of('bn_vowel_00').attempts, 2);
    expect(prefs.getString('progress_v1'), contains('bn_vowel_00'));

    // A fresh container reads the persisted value back.
    final again = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(again.dispose);
    expect(again.read(progressProvider).of('bn_vowel_00').traceStars, 2);
  });

  test('settings store round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier).setDifficulty(Difficulty.hard);
    container.read(settingsProvider.notifier).setLang(AppLang.en);
    final again = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(again.dispose);
    expect(again.read(settingsProvider).difficulty, Difficulty.hard);
    expect(again.read(settingsProvider).lang, AppLang.en);
  });
}

Future<Widget> parentHub() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      glyphSetProvider.overrideWith((ref) async => glyphSet),
    ],
    child: const MaterialApp(home: ParentHub()),
  );
}

void parentTests() {
  testWidgets('parent hub shows the progress report and settings', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(await parentHub());
    await tester.pumpAndSettle();
    expect(find.byType(ProgressScreen), findsOneWidget);
    expect(find.text('মোট তারা'), findsOneWidget);
    await tester.tap(find.text('সেটিংস'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('অগ্রগতি মুছে ফেলো'), findsOneWidget);
  });
}
