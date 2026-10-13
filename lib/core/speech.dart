import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../data/settings_store.dart';

/// Thin, failure-tolerant wrapper around text-to-speech and haptics. Voice
/// availability differs per device (Bengali voices are not installed
/// everywhere), so every call is best-effort and never throws into the UI.
class FeedbackService {
  FeedbackService(this._ref) {
    _init();
  }

  final Ref _ref;
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    try {
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.1);
      _ready = true;
    } catch (e) {
      debugPrint('TTS unavailable: $e');
    }
  }

  Settings get _settings => _ref.read(settingsProvider);

  Future<void> say(String text, {bool bengali = true}) async {
    if (!_ready || !_settings.voice || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.setLanguage(bengali ? 'bn-BD' : 'en-US');
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> stop() async {
    if (!_ready) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  void tap() {
    if (!_settings.sound) return;
    HapticFeedback.selectionClick();
  }

  void success() {
    if (!_settings.sound) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  void celebrate() {
    if (!_settings.sound) return;
    HapticFeedback.heavyImpact();
  }

  void nudge() {
    if (!_settings.sound) return;
    HapticFeedback.lightImpact();
  }
}

final feedbackProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(ref),
);
