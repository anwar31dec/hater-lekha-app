import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';

enum AppLang { bn, en }

enum Difficulty { easy, normal, hard }

class Settings {
  const Settings({
    this.lang = AppLang.bn,
    this.sound = true,
    this.voice = true,
    this.difficulty = Difficulty.normal,
    this.leftHanded = false,
  });

  final AppLang lang;
  final bool sound;
  final bool voice;
  final Difficulty difficulty;
  final bool leftHanded;

  Settings copyWith({
    AppLang? lang,
    bool? sound,
    bool? voice,
    Difficulty? difficulty,
    bool? leftHanded,
  }) {
    return Settings(
      lang: lang ?? this.lang,
      sound: sound ?? this.sound,
      voice: voice ?? this.voice,
      difficulty: difficulty ?? this.difficulty,
      leftHanded: leftHanded ?? this.leftHanded,
    );
  }

  Map<String, dynamic> toJson() => {
    'lang': lang.name,
    'sound': sound,
    'voice': voice,
    'difficulty': difficulty.name,
    'leftHanded': leftHanded,
  };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    lang: AppLang.values.firstWhere(
      (l) => l.name == json['lang'],
      orElse: () => AppLang.bn,
    ),
    sound: json['sound'] as bool? ?? true,
    voice: json['voice'] as bool? ?? true,
    difficulty: Difficulty.values.firstWhere(
      (d) => d.name == json['difficulty'],
      orElse: () => Difficulty.normal,
    ),
    leftHanded: json['leftHanded'] as bool? ?? false,
  );
}

class SettingsNotifier extends Notifier<Settings> {
  static const _key = 'settings_v1';

  @override
  Settings build() {
    final raw = ref.watch(sharedPrefsProvider).getString(_key);
    if (raw != null) {
      try {
        return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt value: fall back to defaults.
      }
    }
    return const Settings();
  }

  void _commit(Settings next) {
    state = next;
    ref.read(sharedPrefsProvider).setString(_key, jsonEncode(next.toJson()));
  }

  void setLang(AppLang lang) => _commit(state.copyWith(lang: lang));
  void toggleLang() =>
      setLang(state.lang == AppLang.bn ? AppLang.en : AppLang.bn);
  void setSound(bool v) => _commit(state.copyWith(sound: v));
  void setVoice(bool v) => _commit(state.copyWith(voice: v));
  void setDifficulty(Difficulty d) => _commit(state.copyWith(difficulty: d));
  void setLeftHanded(bool v) => _commit(state.copyWith(leftHanded: v));
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
