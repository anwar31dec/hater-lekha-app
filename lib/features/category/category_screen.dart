import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/speech.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/glyph_repository.dart';
import '../../data/models.dart';
import '../../data/progress_store.dart';
import '../../engine/stroke_geometry.dart';
import '../../widgets/common.dart';
import '../../widgets/glyph_painters.dart';
import '../practice/practice_screen.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.categoryId});
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final set = ref.watch(glyphSetProvider).value;
    if (set == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final category = set.categories.firstWhere((c) => c.id == categoryId);
    final glyphs = set.inCategory(categoryId);
    final progress = ref.watch(progressProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t(category.titleBn, category.titleEn)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                s.of(
                  progress.completedCount(glyphs.map((g) => g.id)),
                  glyphs.length,
                ),
                style: display(
                  size: 18,
                  weight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cols = (constraints.maxWidth / 120).floor().clamp(3, 8);
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.86,
              ),
              itemCount: glyphs.length,
              itemBuilder: (context, i) => _GlyphTile(
                glyph: glyphs[i],
                category: category,
                progress: progress.of(glyphs[i].id),
                onTap: () {
                  ref.read(feedbackProvider).tap();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PracticeScreen(
                        categoryId: categoryId,
                        initialIndex: i,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlyphTile extends StatelessWidget {
  const _GlyphTile({
    required this.glyph,
    required this.category,
    required this.progress,
    required this.onTap,
  });
  final Glyph glyph;
  final GlyphCategory category;
  final GlyphProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = category.color;
    final done = progress.completed;
    return Material(
      color: done ? c.withValues(alpha: 0.16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: done ? c : const Color(0xFFE2E8F0), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Column(
            children: [
              Expanded(
                child: glyph.isDrill
                    ? CustomPaint(
                        size: Size.infinite,
                        painter: StrokesPainter(
                          strokes: glyph.strokes
                              .map((st) => SampledStroke.fromSvg(st.d, step: 4))
                              .toList(),
                          color: c,
                          width: 6,
                        ),
                      )
                    : FittedBox(
                        child: Text(
                          glyph.char,
                          style: TextStyle(
                            fontFamily: category.script == Script.bn
                                ? kLetterFont
                                : kDisplayFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 48,
                            height: 1.3,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
              ),
              StarRow(stars: progress.bestStars, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
