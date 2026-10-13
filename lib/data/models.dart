import 'package:flutter/material.dart';

/// One pen stroke of a glyph: an SVG path in the 100x100 glyph box, drawn in
/// the direction the path is written, plus a short direction hint.
class StrokeData {
  const StrokeData({
    required this.d,
    required this.hintBn,
    required this.hintEn,
  });

  final String d;
  final String hintBn;
  final String hintEn;

  factory StrokeData.fromJson(Map<String, dynamic> j) => StrokeData(
    d: j['d'] as String,
    hintBn: j['hint_bn'] as String? ?? '',
    hintEn: j['hint_en'] as String? ?? '',
  );
}

class Glyph {
  const Glyph({
    required this.id,
    required this.category,
    required this.char,
    required this.strokes,
    required this.nameBn,
    required this.nameEn,
    this.wordBn,
    this.wordEn,
    this.emoji,
    this.sound,
    this.key,
  });

  final String id;
  final String category;

  /// The character itself; empty for pre-writing drills.
  final String char;
  final List<StrokeData> strokes;
  final String nameBn;
  final String nameEn;
  final String? wordBn;
  final String? wordEn;
  final String? emoji;

  /// What to say aloud for this glyph (Bengali letter name / English letter).
  final String? sound;

  /// Stable key for drills without a character.
  final String? key;

  bool get isDrill => char.isEmpty;

  factory Glyph.fromJson(Map<String, dynamic> j) => Glyph(
    id: j['id'] as String,
    category: j['category'] as String,
    char: j['char'] as String? ?? '',
    strokes: (j['strokes'] as List)
        .map((s) => StrokeData.fromJson(s as Map<String, dynamic>))
        .toList(growable: false),
    nameBn: j['name_bn'] as String,
    nameEn: j['name_en'] as String,
    wordBn: j['word_bn'] as String?,
    wordEn: j['word_en'] as String?,
    emoji: j['emoji'] as String?,
    sound: j['sound'] as String?,
    key: j['key'] as String?,
  );
}

enum Script { bn, en, pre }

class GlyphCategory {
  const GlyphCategory({
    required this.id,
    required this.titleBn,
    required this.titleEn,
    required this.subtitleBn,
    required this.subtitleEn,
    required this.emoji,
    required this.color,
    required this.script,
  });

  final String id;
  final String titleBn;
  final String titleEn;
  final String subtitleBn;
  final String subtitleEn;
  final String emoji;
  final Color color;
  final Script script;

  factory GlyphCategory.fromJson(Map<String, dynamic> j) => GlyphCategory(
    id: j['id'] as String,
    titleBn: j['title_bn'] as String,
    titleEn: j['title_en'] as String,
    subtitleBn: j['subtitle_bn'] as String,
    subtitleEn: j['subtitle_en'] as String,
    emoji: j['emoji'] as String,
    color: _parseColor(j['color'] as String),
    script: Script.values.firstWhere(
      (s) => s.name == j['script'],
      orElse: () => Script.bn,
    ),
  );

  static Color _parseColor(String hex) {
    final v = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | v);
  }
}

class GlyphSet {
  const GlyphSet({
    required this.box,
    required this.matraY,
    required this.baselineY,
    required this.categories,
    required this.glyphs,
  });

  final double box;
  final double matraY;
  final double baselineY;
  final List<GlyphCategory> categories;
  final List<Glyph> glyphs;

  factory GlyphSet.fromJson(Map<String, dynamic> j) => GlyphSet(
    box: (j['box'] as num).toDouble(),
    matraY: (j['matra_y'] as num).toDouble(),
    baselineY: (j['baseline_y'] as num).toDouble(),
    categories: (j['categories'] as List)
        .map((c) => GlyphCategory.fromJson(c as Map<String, dynamic>))
        .toList(growable: false),
    glyphs: (j['glyphs'] as List)
        .map((g) => Glyph.fromJson(g as Map<String, dynamic>))
        .toList(growable: false),
  );

  List<Glyph> inCategory(String categoryId) =>
      glyphs.where((g) => g.category == categoryId).toList(growable: false);

  GlyphCategory categoryOf(Glyph g) =>
      categories.firstWhere((c) => c.id == g.category);

  Glyph? byId(String id) {
    for (final g in glyphs) {
      if (g.id == id) return g;
    }
    return null;
  }
}
