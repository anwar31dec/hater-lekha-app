import 'dart:math' as math;
import 'dart:ui';

import 'package:path_drawing/path_drawing.dart';

/// A stroke path sampled into evenly spaced points (in glyph-box units) so the
/// tracer can measure how far along it a finger has travelled.
class SampledStroke {
  SampledStroke._(this.path, this.points, this.cumulative, this.length);

  final Path path;
  final List<Offset> points;

  /// Arc length from the start of the stroke to each sample in [points].
  final List<double> cumulative;
  final double length;

  Offset get start => points.first;
  Offset get end => points.last;

  /// Very short strokes (the dots under ড় ঢ় য় র, the dot on i and j) are
  /// completed with a tap instead of a drag.
  bool get isDot => length < 25;

  factory SampledStroke.fromSvg(String d, {double step = 1.0}) {
    return SampledStroke.fromPath(parseSvgPathData(d), step: step);
  }

  factory SampledStroke.fromPath(Path path, {double step = 1.0}) {
    final pts = <Offset>[];
    final cum = <double>[];
    double total = 0;
    for (final metric in path.computeMetrics()) {
      double t = 0;
      while (t < metric.length) {
        final tangent = metric.getTangentForOffset(t);
        if (tangent != null) {
          pts.add(tangent.position);
          cum.add(total + t);
        }
        t += step;
      }
      final endTangent = metric.getTangentForOffset(metric.length);
      if (endTangent != null) {
        pts.add(endTangent.position);
        cum.add(total + metric.length);
      }
      total += metric.length;
    }
    if (pts.isEmpty) {
      pts.add(Offset.zero);
      cum.add(0);
    }
    return SampledStroke._(
      path,
      List.unmodifiable(pts),
      List.unmodifiable(cum),
      total,
    );
  }

  /// Fraction (0..1) of the stroke covered up to sample [index].
  double fractionAt(int index) {
    if (length <= 0) return 1;
    return (cumulative[index.clamp(0, cumulative.length - 1)] / length).clamp(
      0.0,
      1.0,
    );
  }

  /// Index of the last sample within [ahead] units of arc length after
  /// sample [from].
  int indexAhead(int from, double ahead) {
    final limit = cumulative[from.clamp(0, cumulative.length - 1)] + ahead;
    var i = from;
    while (i + 1 < cumulative.length && cumulative[i + 1] <= limit) {
      i++;
    }
    return i;
  }

  /// Nearest sample to [p] within the index window `[from, to]` (inclusive).
  /// Returns `(index, distance)`.
  (int, double) nearest(Offset p, {int from = 0, int? to}) {
    final last = math.min(to ?? points.length - 1, points.length - 1);
    var bestI = from;
    var bestD = double.infinity;
    for (var i = from; i <= last; i++) {
      final d = (points[i] - p).distance;
      if (d < bestD) {
        bestD = d;
        bestI = i;
      }
    }
    return (bestI, bestD);
  }

  /// Sub-path from the start to [fraction] of the length; used to animate the
  /// demonstration.
  Path partial(double fraction) {
    final target = length * fraction.clamp(0.0, 1.0);
    final out = Path();
    double consumed = 0;
    for (final metric in path.computeMetrics()) {
      if (consumed >= target) break;
      final take = math.min(metric.length, target - consumed);
      out.addPath(metric.extractPath(0, take), Offset.zero);
      consumed += metric.length;
    }
    return out;
  }

  /// Position along the stroke at [fraction] of its length.
  Offset pointAt(double fraction) {
    final target = length * fraction.clamp(0.0, 1.0);
    double consumed = 0;
    for (final metric in path.computeMetrics()) {
      if (target <= consumed + metric.length) {
        return metric.getTangentForOffset(target - consumed)?.position ?? end;
      }
      consumed += metric.length;
    }
    return end;
  }
}
