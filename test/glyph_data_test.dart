import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hater_lekha/data/models.dart';
import 'package:hater_lekha/engine/stroke_geometry.dart';

void main() {
  late GlyphSet set;

  setUpAll(() {
    final raw = File('assets/data/glyphs.json').readAsStringSync();
    set = GlyphSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('has every category the curriculum needs', () {
    final ids = set.categories.map((c) => c.id).toList();
    expect(
      ids,
      containsAll([
        'pre',
        'bn_vowel',
        'bn_cons',
        'bn_digit',
        'en_upper',
        'en_lower',
        'en_digit',
      ]),
    );
    expect(set.inCategory('bn_vowel').length, 11);
    expect(set.inCategory('bn_cons').length, 39);
    expect(set.inCategory('bn_digit').length, 10);
    expect(set.inCategory('en_upper').length, 26);
    expect(set.inCategory('en_lower').length, 26);
    expect(set.inCategory('en_digit').length, 10);
    expect(set.inCategory('pre').length, greaterThanOrEqualTo(16));
  });

  test('glyph ids are unique and every category is non-empty', () {
    final ids = set.glyphs.map((g) => g.id).toSet();
    expect(ids.length, set.glyphs.length);
    for (final c in set.categories) {
      expect(set.inCategory(c.id), isNotEmpty, reason: c.id);
    }
  });

  test('every stroke parses, has length and stays inside the glyph box', () {
    for (final g in set.glyphs) {
      expect(g.strokes, isNotEmpty, reason: g.id);
      for (final st in g.strokes) {
        final s = SampledStroke.fromSvg(st.d);
        expect(s.length, greaterThan(5), reason: '${g.id}: ${st.d}');
        for (final p in s.points) {
          expect(p.dx, inInclusiveRange(-2, 102), reason: g.id);
          expect(p.dy, inInclusiveRange(-2, 102), reason: g.id);
        }
        expect(st.hintBn, isNotEmpty);
        expect(st.hintEn, isNotEmpty);
      }
    }
  });

  test('Bengali letters carry names, words and sounds', () {
    for (final g in [
      ...set.inCategory('bn_vowel'),
      ...set.inCategory('bn_cons'),
    ]) {
      expect(g.char, isNotEmpty);
      expect(g.nameBn, isNotEmpty, reason: g.id);
      expect(g.wordBn, isNotNull, reason: g.id);
      expect(g.sound, isNotNull, reason: g.id);
    }
  });
}
