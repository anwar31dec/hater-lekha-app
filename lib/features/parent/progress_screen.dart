import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/glyph_repository.dart';
import '../../data/models.dart';
import '../../data/progress_store.dart';
import '../../widgets/common.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final set = ref.watch(glyphSetProvider).value;
    final progress = ref.watch(progressProvider);
    if (set == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.star_rounded,
              color: AppColors.star,
              size: 36,
            ),
            title: Text(
              s.totalStars,
              style: display(size: 18, weight: FontWeight.w700),
            ),
            trailing: Text(
              s.num(progress.overallStars),
              style: display(size: 26, weight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final c in set.categories) ...[
          _CategoryProgress(
            category: c,
            glyphs: set.inCategory(c.id),
            progress: progress,
            strings: s,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CategoryProgress extends StatelessWidget {
  const _CategoryProgress({
    required this.category,
    required this.glyphs,
    required this.progress,
    required this.strings,
  });
  final GlyphCategory category;
  final List<Glyph> glyphs;
  final ProgressState progress;
  final Strings strings;

  String _when(DateTime? d) {
    if (d == null) return strings.notYet;
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return strings.today;
    if (days == 1) return strings.yesterday;
    return strings.daysAgo(days);
  }

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final ids = glyphs.map((g) => g.id);
    final done = progress.completedCount(ids);
    final last = glyphs
        .map((g) => progress.of(g.id).lastPracticed)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: EmojiBadge(
          emoji: category.emoji,
          size: 44,
          background: category.color.withValues(alpha: 0.15),
        ),
        title: Text(
          s.t(category.titleBn, category.titleEn),
          style: display(size: 17, weight: FontWeight.w700),
        ),
        subtitle: Text(
          '${s.completed}: ${s.of(done, glyphs.length)}  ·  ${s.lastPracticed}: ${_when(last)}',
          style: display(
            size: 13,
            weight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: AppColors.star, size: 20),
            Text(
              s.num(progress.totalStars(ids)),
              style: display(size: 16, weight: FontWeight.w700),
            ),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1.4),
              2: FlexColumnWidth(1.4),
              3: FlexColumnWidth(2),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  Text(
                    s.traceLabel,
                    style: display(
                      size: 13,
                      weight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    s.writeLabel,
                    style: display(
                      size: 13,
                      weight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    s.lastPracticed,
                    style: display(
                      size: 13,
                      weight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              for (final g in glyphs)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        g.isDrill ? s.t(g.nameBn, g.nameEn) : g.char,
                        style: TextStyle(
                          fontFamily: category.script == Script.bn
                              ? kLetterFont
                              : kDisplayFont,
                          fontSize: g.isDrill ? 13 : 22,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StarRow(stars: progress.of(g.id).traceStars, size: 16),
                    StarRow(stars: progress.of(g.id).writeStars, size: 16),
                    Text(
                      _when(progress.of(g.id).lastPracticed),
                      style: display(size: 13, weight: FontWeight.w500),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
