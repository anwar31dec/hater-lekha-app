import 'package:flutter_test/flutter_test.dart';
import 'package:hater_lekha/engine/stroke_geometry.dart';

void main() {
  test('samples a straight line evenly', () {
    final s = SampledStroke.fromSvg('M50 10 L50 90');
    expect(s.length, closeTo(80, 0.01));
    expect(s.start, const Offset(50, 10));
    expect(s.end, const Offset(50, 90));
    expect(s.points.length, greaterThanOrEqualTo(80));
    expect(s.fractionAt(0), 0);
    expect(s.fractionAt(s.points.length - 1), 1);
    expect(s.isDot, isFalse);
  });

  test('a dot is recognised as a tap target', () {
    final s = SampledStroke.fromSvg(
      'M50 46.8 A3.2 3.2 0 1 0 50 53.2 A3.2 3.2 0 1 0 50 46.8',
    );
    expect(s.isDot, isTrue);
  });

  test('nearest respects the search window', () {
    final s = SampledStroke.fromSvg('M10 50 L90 50');
    final (i, d) = s.nearest(const Offset(80, 50), from: 0, to: 20);
    expect(i, 20);
    expect(d, closeTo(50, 1));
    final (j, d2) = s.nearest(const Offset(80, 52));
    expect(s.points[j].dx, closeTo(80, 1));
    expect(d2, closeTo(2, 0.5));
  });

  test('indexAhead walks forward by arc length', () {
    final s = SampledStroke.fromSvg('M10 50 L90 50');
    final i = s.indexAhead(0, 30);
    expect(s.cumulative[i], closeTo(30, 1));
  });

  test('partial path and pointAt follow the stroke', () {
    final s = SampledStroke.fromSvg('M0 0 L100 0');
    expect(s.pointAt(0.5).dx, closeTo(50, 0.01));
    final half = SampledStroke.fromPath(s.partial(0.5));
    expect(half.length, closeTo(50, 0.01));
  });
}
