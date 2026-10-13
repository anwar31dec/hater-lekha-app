import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/speech.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/glyph_repository.dart';
import '../../data/models.dart';
import '../../data/progress_store.dart';
import '../../data/settings_store.dart';
import '../../widgets/common.dart';
import '../category/category_screen.dart';
import '../parent/parent_gate.dart';
import '../parent/parent_hub.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final glyphs = ref.watch(glyphSetProvider);
    return Scaffold(
      body: SafeArea(
        child: glyphs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (set) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(strings: s)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final cols = (constraints.crossAxisExtent / 360)
                        .floor()
                        .clamp(1, 4);
                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisExtent: 136,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _CategoryCard(
                          category: set.categories[i],
                          set: set,
                        ),
                        childCount: set.categories.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.strings});
  final Strings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings;
    final totalStars = ref.watch(
      progressProvider.select((p) => p.overallStars),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✍️', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.appName,
                      style: display(
                        size: 34,
                        weight: FontWeight.w800,
                        color: AppColors.seed,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      s.tagline,
                      style: display(
                        size: 16,
                        weight: FontWeight.w500,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              _LangToggle(strings: s),
              const SizedBox(width: 8),
              RoundIconButton(
                icon: Icons.lock_outline_rounded,
                tooltip: s.parents,
                onPressed: () async {
                  final ok = await showParentGate(context, s);
                  if (ok && context.mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ParentHub()),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.whatToLearn,
                  style: display(size: 22, weight: FontWeight.w700),
                ),
              ),
              if (totalStars > 0) ...[
                const Icon(Icons.star_rounded, color: AppColors.star, size: 26),
                const SizedBox(width: 2),
                Text(
                  s.num(totalStars),
                  style: display(
                    size: 20,
                    weight: FontWeight.w800,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LangToggle extends ConsumerWidget {
  const _LangToggle({required this.strings});
  final Strings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(
        side: BorderSide(color: Color(0xFFE2E8F0), width: 2),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          ref.read(feedbackProvider).tap();
          ref.read(settingsProvider.notifier).toggleLang();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded, size: 20),
              const SizedBox(width: 6),
              Text(
                strings.langToggle,
                style: display(size: 16, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({required this.category, required this.set});
  final GlyphCategory category;
  final GlyphSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final glyphs = set.inCategory(category.id);
    final ids = glyphs.map((g) => g.id);
    final progress = ref.watch(progressProvider);
    final done = progress.completedCount(ids);
    final stars = progress.totalStars(ids);
    final c = category.color;
    return Material(
      color: c.withValues(alpha: 0.13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: c.withValues(alpha: 0.5), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          ref.read(feedbackProvider).tap();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CategoryScreen(categoryId: category.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              EmojiBadge(
                emoji: category.emoji,
                size: 66,
                background: Colors.white,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        s.t(category.titleBn, category.titleEn),
                        style: display(
                          size: 20,
                          weight: FontWeight.w800,
                          color: const Color(0xFF1F2937),
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.t(category.subtitleBn, category.subtitleEn),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: category.script == Script.bn
                            ? kLetterFont
                            : kDisplayFont,
                        fontSize: 16,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: glyphs.isEmpty ? 0 : done / glyphs.length,
                              minHeight: 10,
                              backgroundColor: Colors.white,
                              color: c,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          s.of(done, glyphs.length),
                          style: display(
                            size: 15,
                            weight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        if (stars > 0) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: AppColors.star,
                          ),
                          Text(
                            s.num(stars),
                            style: display(
                              size: 15,
                              weight: FontWeight.w700,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
