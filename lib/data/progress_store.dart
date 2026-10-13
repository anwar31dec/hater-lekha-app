import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';

enum PracticeMode { watch, trace, write }

class GlyphProgress {
  const GlyphProgress({
    this.watched = false,
    this.traceStars = 0,
    this.writeStars = 0,
    this.attempts = 0,
    this.lastPracticed,
  });

  final bool watched;
  final int traceStars;
  final int writeStars;
  final int attempts;
  final DateTime? lastPracticed;

  int get bestStars => traceStars > writeStars ? traceStars : writeStars;
  bool get started => watched || attempts > 0;
  bool get completed => traceStars > 0;
  bool get mastered => traceStars >= 2 && writeStars >= 2;

  GlyphProgress copyWith({
    bool? watched,
    int? traceStars,
    int? writeStars,
    int? attempts,
    DateTime? lastPracticed,
  }) {
    return GlyphProgress(
      watched: watched ?? this.watched,
      traceStars: traceStars ?? this.traceStars,
      writeStars: writeStars ?? this.writeStars,
      attempts: attempts ?? this.attempts,
      lastPracticed: lastPracticed ?? this.lastPracticed,
    );
  }

  Map<String, dynamic> toJson() => {
    'w': watched,
    't': traceStars,
    'r': writeStars,
    'a': attempts,
    'l': lastPracticed?.toIso8601String(),
  };

  factory GlyphProgress.fromJson(Map<String, dynamic> j) => GlyphProgress(
    watched: j['w'] as bool? ?? false,
    traceStars: j['t'] as int? ?? 0,
    writeStars: j['r'] as int? ?? 0,
    attempts: j['a'] as int? ?? 0,
    lastPracticed: j['l'] == null ? null : DateTime.tryParse(j['l'] as String),
  );
}

class ProgressState {
  const ProgressState(this.byId);
  final Map<String, GlyphProgress> byId;

  GlyphProgress of(String id) => byId[id] ?? const GlyphProgress();

  int totalStars(Iterable<String> ids) =>
      ids.fold(0, (sum, id) => sum + of(id).bestStars);

  int completedCount(Iterable<String> ids) =>
      ids.where((id) => of(id).completed).length;

  int get overallStars => byId.values.fold(0, (sum, p) => sum + p.bestStars);
}

class ProgressNotifier extends Notifier<ProgressState> {
  static const _key = 'progress_v1';

  @override
  ProgressState build() {
    final raw = ref.watch(sharedPrefsProvider).getString(_key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return ProgressState({
          for (final e in decoded.entries)
            e.key: GlyphProgress.fromJson(e.value as Map<String, dynamic>),
        });
      } catch (_) {
        // Corrupt value: start fresh rather than crash a child's app.
      }
    }
    return const ProgressState({});
  }

  void _commit(Map<String, GlyphProgress> next) {
    state = ProgressState(Map.unmodifiable(next));
    ref
        .read(sharedPrefsProvider)
        .setString(
          _key,
          jsonEncode({for (final e in next.entries) e.key: e.value.toJson()}),
        );
  }

  void markWatched(String id) {
    final p = state.of(id);
    if (p.watched) return;
    _commit({...state.byId, id: p.copyWith(watched: true)});
  }

  /// Records a finished attempt. Stars only ever go up, so a bad day never
  /// erases a child's best result.
  void record(String id, PracticeMode mode, int stars) {
    final p = state.of(id);
    final now = DateTime.now();
    final next = switch (mode) {
      PracticeMode.trace => p.copyWith(
        traceStars: stars > p.traceStars ? stars : p.traceStars,
        attempts: p.attempts + 1,
        lastPracticed: now,
      ),
      PracticeMode.write => p.copyWith(
        writeStars: stars > p.writeStars ? stars : p.writeStars,
        attempts: p.attempts + 1,
        lastPracticed: now,
      ),
      PracticeMode.watch => p.copyWith(watched: true, lastPracticed: now),
    };
    _commit({...state.byId, id: next});
  }

  void resetAll() => _commit({});
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(
  ProgressNotifier.new,
);
