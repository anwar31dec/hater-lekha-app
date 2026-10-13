import 'dart:ui';

import '../data/settings_store.dart';
import 'stroke_geometry.dart';

enum TraceEvent {
  none,
  started,
  rejectedStart,
  progressed,
  offTrack,
  strokeReset,
  strokeCompleted,
  glyphCompleted,
}

/// Tolerances are in glyph-box units (the glyph box is 100 units wide).
class TraceConfig {
  const TraceConfig({
    required this.startRadius,
    required this.tolerance,
    required this.completion,
    required this.maxOffTrack,
    this.lookahead = 30,
  });

  /// How close to the stroke's first point a finger must land to begin.
  final double startRadius;

  /// How far a finger may stray from the stroke before it counts as off.
  final double tolerance;

  /// Fraction of the stroke that must be covered for it to count.
  final double completion;

  /// Consecutive off-track samples tolerated before the stroke is cancelled.
  final int maxOffTrack;

  /// How far ahead along the stroke we look for the finger, in units. Keeps a
  /// closed shape (a circle) from being "finished" the moment it starts.
  final double lookahead;

  factory TraceConfig.forDifficulty(Difficulty d) => switch (d) {
    Difficulty.easy => const TraceConfig(
      startRadius: 16,
      tolerance: 13,
      completion: 0.82,
      maxOffTrack: 14,
    ),
    Difficulty.normal => const TraceConfig(
      startRadius: 12,
      tolerance: 10,
      completion: 0.88,
      maxOffTrack: 10,
    ),
    Difficulty.hard => const TraceConfig(
      startRadius: 9,
      tolerance: 7,
      completion: 0.93,
      maxOffTrack: 6,
    ),
  };

  /// Looser variant used for free writing, where there is no visible guide.
  TraceConfig relaxed() => TraceConfig(
    startRadius: startRadius * 1.8,
    tolerance: tolerance * 1.7,
    completion: completion - 0.1,
    maxOffTrack: maxOffTrack * 2,
    lookahead: lookahead,
  );
}

/// State machine for tracing one glyph stroke by stroke.
///
/// In guided mode a finger must start near the stroke's start point and stay
/// near the path; straying cancels the stroke. In [freeMode] (the "write it
/// yourself" page) all ink is kept, and a stroke is credited whenever the
/// child's line happens to follow the model closely enough.
class TraceSession {
  TraceSession({
    required this.strokes,
    required this.config,
    this.freeMode = false,
  });

  final List<SampledStroke> strokes;
  final TraceConfig config;
  final bool freeMode;

  int currentStroke = 0;
  int _progress = 0;
  bool _matching = false;
  bool _drawing = false;
  int resets = 0;
  double _errorSum = 0;
  int _errorSamples = 0;
  int _offTrack = 0;

  /// Ink that has been kept: credited strokes, plus free ink in [freeMode].
  final List<List<Offset>> ink = [];
  List<Offset> currentInk = const [];

  bool get isComplete => currentStroke >= strokes.length;
  bool get isDrawing => _drawing;
  bool get hasInk => ink.isNotEmpty || currentInk.isNotEmpty;
  SampledStroke? get activeStroke => isComplete ? null : strokes[currentStroke];

  /// How much of the active stroke has been covered so far (0..1).
  double get activeFraction =>
      activeStroke == null ? 1 : activeStroke!.fractionAt(_progress);

  double get meanError => _errorSamples == 0 ? 0 : _errorSum / _errorSamples;

  TraceEvent begin(Offset p) {
    if (isComplete) return TraceEvent.none;
    final s = strokes[currentStroke];
    final nearStart = (p - s.start).distance <= config.startRadius;
    if (!nearStart && !freeMode) return TraceEvent.rejectedStart;
    _drawing = true;
    _matching = nearStart;
    _progress = 0;
    _offTrack = 0;
    currentInk = [p];
    return TraceEvent.started;
  }

  TraceEvent move(Offset p) {
    if (!_drawing) return TraceEvent.none;
    currentInk = [...currentInk, p];
    if (!_matching) return TraceEvent.progressed;
    final s = strokes[currentStroke];
    final windowEnd = s.indexAhead(_progress, config.lookahead);
    final (idx, dist) = s.nearest(p, from: _progress, to: windowEnd);
    if (dist <= config.tolerance) {
      if (idx > _progress) _progress = idx;
      _errorSum += dist;
      _errorSamples++;
      _offTrack = 0;
      return TraceEvent.progressed;
    }
    _offTrack++;
    if (_offTrack > config.maxOffTrack) {
      if (freeMode) {
        _matching = false;
        return TraceEvent.progressed;
      }
      _drawing = false;
      currentInk = const [];
      resets++;
      return TraceEvent.offTrack;
    }
    return TraceEvent.progressed;
  }

  TraceEvent end() {
    if (!_drawing) return TraceEvent.none;
    _drawing = false;
    final s = strokes[currentStroke];
    final credited =
        _matching && (s.isDot || s.fractionAt(_progress) >= config.completion);
    if (credited) {
      ink.add(currentInk);
      currentInk = const [];
      currentStroke++;
      return isComplete
          ? TraceEvent.glyphCompleted
          : TraceEvent.strokeCompleted;
    }
    if (freeMode) {
      if (currentInk.length > 1) ink.add(currentInk);
      currentInk = const [];
      return TraceEvent.progressed;
    }
    currentInk = const [];
    resets++;
    return TraceEvent.strokeReset;
  }

  /// 1–3 stars once complete, 0 before. Accuracy is the mean distance from the
  /// model path relative to the tolerance; retries cost a star.
  int get stars {
    if (!isComplete) return 0;
    final ratio = meanError / config.tolerance;
    if (ratio < 0.42 && resets <= 1) return 3;
    if (ratio < 0.7 && resets <= 3) return 2;
    return 1;
  }

  /// Stars for a free-writing attempt the child chose to finish early.
  int get starsSoFar {
    if (isComplete) return stars;
    if (currentStroke == 0) return hasInk ? 1 : 0;
    final covered = currentStroke / strokes.length;
    return covered >= 0.5 ? 2 : 1;
  }

  void clear() {
    currentStroke = 0;
    _progress = 0;
    _matching = false;
    _drawing = false;
    resets = 0;
    _errorSum = 0;
    _errorSamples = 0;
    _offTrack = 0;
    ink.clear();
    currentInk = const [];
  }
}
