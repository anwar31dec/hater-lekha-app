import 'dart:math' show cos, sin;

import 'package:flutter_test/flutter_test.dart';
import 'package:hater_lekha/data/settings_store.dart';
import 'package:hater_lekha/engine/stroke_geometry.dart';
import 'package:hater_lekha/engine/tracer.dart';

TraceSession session(
  List<String> paths, {
  bool free = false,
  Difficulty d = Difficulty.normal,
}) {
  final cfg = TraceConfig.forDifficulty(d);
  return TraceSession(
    strokes: paths.map(SampledStroke.fromSvg).toList(),
    config: free ? cfg.relaxed() : cfg,
    freeMode: free,
  );
}

/// Drags a finger along [pts] and returns the final event.
TraceEvent drag(TraceSession s, List<Offset> pts) {
  var ev = s.begin(pts.first);
  if (ev == TraceEvent.rejectedStart) return ev;
  for (final p in pts.skip(1)) {
    ev = s.move(p);
    if (ev == TraceEvent.offTrack) return ev;
  }
  return s.end();
}

List<Offset> line(Offset a, Offset b, {int n = 40, double jitter = 0}) => [
  for (var i = 0; i <= n; i++)
    Offset.lerp(a, b, i / n)! + Offset(jitter * ((i % 2 == 0) ? 1 : -1), 0),
];

void main() {
  test(
    'tracing a vertical line top to bottom completes the glyph with 3 stars',
    () {
      final s = session(['M50 14 L50 86']);
      final ev = drag(
        s,
        line(const Offset(50, 14), const Offset(50, 86), jitter: 1.5),
      );
      expect(ev, TraceEvent.glyphCompleted);
      expect(s.isComplete, isTrue);
      expect(s.stars, 3);
      expect(s.ink.length, 1);
    },
  );

  test('starting far from the stroke start is rejected in guided mode', () {
    final s = session(['M50 14 L50 86']);
    expect(s.begin(const Offset(50, 60)), TraceEvent.rejectedStart);
    expect(s.isDrawing, isFalse);
  });

  test('drawing in the wrong direction does not complete the stroke', () {
    final s = session(['M50 14 L50 86']);
    // Begin at the correct start, but then move back up/away: nothing covered.
    final ev = drag(s, [
      const Offset(50, 14),
      const Offset(50, 15),
      const Offset(50, 14),
    ]);
    expect(ev, TraceEvent.strokeReset);
    expect(s.resets, 1);
    expect(s.isComplete, isFalse);
  });

  test('wandering far off the path cancels the stroke', () {
    final s = session(['M10 50 L90 50']);
    final pts = [
      ...line(const Offset(10, 50), const Offset(40, 50), n: 10),
      ...line(const Offset(40, 50), const Offset(40, 95), n: 30),
    ];
    final ev = drag(s, pts);
    expect(ev, TraceEvent.offTrack);
    expect(s.currentInk, isEmpty);
    expect(s.resets, 1);
  });

  test('strokes must be completed in order', () {
    final s = session(['M30 22 L70 22', 'M50 22 L50 78']);
    expect(
      drag(s, line(const Offset(30, 22), const Offset(70, 22))),
      TraceEvent.strokeCompleted,
    );
    expect(s.currentStroke, 1);
    expect(
      drag(s, line(const Offset(50, 22), const Offset(50, 78))),
      TraceEvent.glyphCompleted,
    );
    expect(s.stars, greaterThanOrEqualTo(2));
  });

  test('a closed circle is not finished at the first touch', () {
    final s = session(['M50 18 A32 32 0 1 0 50 82 A32 32 0 1 0 50 18']);
    expect(s.begin(const Offset(50, 18)), TraceEvent.started);
    // Hover at the start: nothing is covered, so ending resets.
    s.move(const Offset(49, 19));
    expect(s.end(), TraceEvent.strokeReset);

    // Now go the full way round counter-clockwise (left first).
    final pts = <Offset>[];
    for (var i = 0; i <= 120; i++) {
      final a = -1.5708 - (i / 120) * 6.2832; // start at top, go left
      pts.add(Offset(50 + 32 * cos(a), 50 + 32 * sin(a)));
    }
    expect(drag(s, pts), TraceEvent.glyphCompleted);
  });

  test('a dot is completed with a tap', () {
    final s = session([
      'M50 46.8 A3.2 3.2 0 1 0 50 53.2 A3.2 3.2 0 1 0 50 46.8',
    ]);
    expect(
      drag(s, [const Offset(50, 47), const Offset(50, 48)]),
      TraceEvent.glyphCompleted,
    );
  });

  test('free mode keeps stray ink and still credits a matching stroke', () {
    final s = session(['M50 14 L50 86'], free: true);
    // Scribble somewhere unrelated: kept as ink, not credited.
    expect(
      drag(s, line(const Offset(10, 90), const Offset(30, 95))),
      TraceEvent.progressed,
    );
    expect(s.ink.length, 1);
    expect(s.currentStroke, 0);
    expect(s.starsSoFar, 1);
    // Now write the actual line.
    expect(
      drag(s, line(const Offset(50, 14), const Offset(50, 86))),
      TraceEvent.glyphCompleted,
    );
    expect(s.ink.length, 2);
    expect(s.stars, greaterThanOrEqualTo(1));
  });

  test('retries lower the star rating', () {
    final s = session(['M50 14 L50 86']);
    for (var i = 0; i < 4; i++) {
      drag(s, [const Offset(50, 14), const Offset(50, 16)]);
    }
    expect(s.resets, 4);
    drag(s, line(const Offset(50, 14), const Offset(50, 86)));
    expect(s.stars, 1);
  });

  test('clear() restores the initial state', () {
    final s = session(['M50 14 L50 86']);
    drag(s, line(const Offset(50, 14), const Offset(50, 86)));
    s.clear();
    expect(s.isComplete, isFalse);
    expect(s.ink, isEmpty);
    expect(s.resets, 0);
  });
}
