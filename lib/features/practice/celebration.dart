import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

/// Full-canvas overlay shown when a glyph is finished: stars pop in one by
/// one, confetti falls, and the child can go again or move on.
class Celebration extends StatefulWidget {
  const Celebration({
    super.key,
    required this.stars,
    required this.glyph,
    required this.category,
    required this.strings,
    required this.onAgain,
    required this.onNext,
  });

  final int stars;
  final Glyph glyph;
  final GlyphCategory category;
  final Strings strings;
  final VoidCallback onAgain;
  final VoidCallback? onNext;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();
  late final List<_Confetto> _confetti = List.generate(
    36,
    (i) => _Confetto.random(i),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final praise = widget.stars >= 3
        ? s.praise[3]
        : (widget.stars == 2 ? s.praise[1] : s.praise[0]);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: ColoredBox(
                color: AppColors.paper.withValues(
                  alpha:
                      0.86 *
                      Curves.easeOut.transform(_c.value.clamp(0, 0.3) / 0.3),
                ),
              ),
            ),
            CustomPaint(
              painter: _ConfettiPainter(
                _confetti,
                _c.value,
                widget.category.color,
              ),
            ),
            Center(
              child: Transform.scale(
                scale: Curves.elasticOut.transform(
                  _c.value.clamp(0, 0.6) / 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Transform.scale(
                            scale: i < widget.stars
                                ? Curves.elasticOut.transform(
                                    ((_c.value - 0.3 - i * 0.18) / 0.5).clamp(
                                      0,
                                      1,
                                    ),
                                  )
                                : 1,
                            child: Icon(
                              i < widget.stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: i == 1 ? 76 : 60,
                              color: i < widget.stars
                                  ? AppColors.star
                                  : AppColors.guide,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      praise,
                      style: display(
                        size: 32,
                        weight: FontWeight.w800,
                        color: AppColors.seed,
                      ),
                    ),
                    if (widget.glyph.emoji != null &&
                        widget.glyph.wordBn != null)
                      Text(
                        '${widget.glyph.emoji} ${s.t(widget.glyph.wordBn!, widget.glyph.wordEn ?? '')}',
                        style: display(
                          size: 20,
                          weight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.onAgain,
                          icon: const Icon(Icons.replay_rounded),
                          label: Text(s.again),
                        ),
                        if (widget.onNext != null)
                          FilledButton.icon(
                            onPressed: widget.onNext,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(s.next),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Confetto {
  _Confetto(this.x, this.delay, this.speed, this.size, this.hue, this.spin);
  final double x, delay, speed, size, hue, spin;

  factory _Confetto.random(int seed) {
    final r = math.Random(seed * 7919);
    return _Confetto(
      r.nextDouble(),
      r.nextDouble() * 0.5,
      0.6 + r.nextDouble() * 0.8,
      6 + r.nextDouble() * 8,
      r.nextDouble() * 360,
      r.nextDouble() * 6,
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.items, this.t, this.accent);
  final List<_Confetto> items;
  final double t;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in items) {
      final p = ((t - c.delay) / (1 - c.delay)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final y = -20 + (size.height + 40) * Curves.easeIn.transform(p) * c.speed;
      final x = c.x * size.width + math.sin(p * 6 + c.spin) * 14;
      final color = HSLColor.fromAHSL(1 - p * 0.6, c.hue, 0.8, 0.55).toColor();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p * c.spin * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: c.size,
            height: c.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
