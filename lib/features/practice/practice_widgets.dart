import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../engine/stroke_geometry.dart';
import '../../widgets/common.dart';
import '../../widgets/glyph_painters.dart';

class PracticeHeader extends StatelessWidget {
  const PracticeHeader({
    super.key,
    required this.glyph,
    required this.category,
    required this.strings,
    required this.index,
    required this.total,
    required this.onBack,
    required this.onListen,
  });

  final Glyph glyph;
  final GlyphCategory category;
  final Strings strings;
  final int index;
  final int total;
  final VoidCallback onBack;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final isBn = category.script == Script.bn;
    final word = s.t(glyph.wordBn ?? '', glyph.wordEn ?? '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
            size: 48,
          ),
          const SizedBox(width: 10),
          if (!glyph.isDrill)
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: category.color.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Text(
                glyph.char,
                style: TextStyle(
                  fontFamily: isBn ? kLetterFont : kDisplayFont,
                  fontSize: 34,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(glyph.nameBn, glyph.nameEn),
                  style: display(
                    size: glyph.isDrill ? 18 : 20,
                    weight: FontWeight.w800,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (word.isNotEmpty)
                  Text(
                    '${glyph.emoji ?? ''} $word',
                    style: display(
                      size: 16,
                      weight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            s.of(index + 1, total),
            style: display(
              size: 15,
              weight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.volume_up_rounded,
            tooltip: s.listen,
            onPressed: onListen,
            size: 48,
          ),
        ],
      ),
    );
  }
}

class HintBar extends StatelessWidget {
  const HintBar({
    super.key,
    required this.text,
    required this.highlighted,
    required this.color,
  });
  final String text;
  final bool highlighted;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.guideActive.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              highlighted
                  ? Icons.touch_app_rounded
                  : Icons.lightbulb_outline_rounded,
              color: highlighted ? AppColors.guideActive : color,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  text,
                  key: ValueKey(text),
                  style: display(
                    size: 16,
                    weight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The copybook's "step by step" row: cell *n* shows the first *n* strokes.
class StepRow extends StatelessWidget {
  const StepRow({
    super.key,
    required this.strokes,
    required this.highlighted,
    required this.color,
    required this.label,
  });
  final List<SampledStroke> strokes;
  final int? highlighted;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        children: [
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              label,
              style: display(
                size: 11,
                weight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: strokes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final active = highlighted != null && i == highlighted;
                  final done = highlighted != null && i < highlighted!;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    decoration: BoxDecoration(
                      color: active
                          ? color.withValues(alpha: 0.16)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? color
                            : (done
                                  ? color.withValues(alpha: 0.4)
                                  : const Color(0xFFE2E8F0)),
                        width: active ? 2.5 : 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: CustomPaint(
                              painter: StrokesPainter(
                                strokes: strokes,
                                upTo: i + 1,
                                width: 7,
                                highlightLast: true,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 4,
                          top: 2,
                          child: Text(
                            '${i + 1}',
                            style: display(
                              size: 11,
                              weight: FontWeight.w800,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The copybook row the child fills in: model letter first, then up to six of
/// their own attempts from this sitting.
class AttemptsStrip extends StatelessWidget {
  const AttemptsStrip({
    super.key,
    required this.strokes,
    required this.attempts,
    required this.label,
    required this.color,
  });
  final List<SampledStroke> strokes;
  final List<List<List<Offset>>> attempts;
  final String label;
  final Color color;

  static const _cells = 6;

  @override
  Widget build(BuildContext context) {
    final shown = attempts.length > _cells
        ? attempts.sublist(attempts.length - _cells)
        : attempts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Row(
        children: [
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              label,
              style: display(
                size: 11,
                weight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  _Cell(
                    border: color,
                    fill: color.withValues(alpha: 0.10),
                    child: CustomPaint(
                      painter: StrokesPainter(
                        strokes: strokes,
                        width: 7,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  for (var i = 0; i < _cells; i++)
                    _Cell(
                      border: i < shown.length
                          ? AppColors.inkDone.withValues(alpha: 0.6)
                          : const Color(0xFFE2E8F0),
                      fill: Colors.white,
                      dashed: i >= shown.length,
                      child: i < shown.length
                          ? CustomPaint(
                              painter: InkPainter(ink: shown[i], width: 7),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.border,
    required this.fill,
    this.child,
    this.dashed = false,
  });
  final Color border;
  final Color fill;
  final Widget? child;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.5),
            ),
            padding: const EdgeInsets.all(4),
            child:
                child ??
                (dashed
                    ? const Center(
                        child: Icon(
                          Icons.more_horiz_rounded,
                          size: 16,
                          color: Color(0xFFCBD5E1),
                        ),
                      )
                    : null),
          ),
        ),
      ),
    );
  }
}
