import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

const glyphAssetPath = 'assets/data/glyphs.json';

final glyphSetProvider = FutureProvider<GlyphSet>((ref) async {
  final raw = await rootBundle.loadString(glyphAssetPath);
  return GlyphSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});
