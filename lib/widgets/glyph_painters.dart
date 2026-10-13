import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../engine/stroke_geometry.dart';

/// Maps the 100x100 glyph box onto a square centred in [size].
class BoxTransform {
  BoxTransform(Size size, {double box = 100})
    : scale = size.shortestSide / box,
      offset = Offset(
        (size.width - size.shortestSide) / 2,
        (size.height - size.shortestSide) / 2,
      );

  final double scale;
  final Offset offset;

  Offset toBox(Offset local) => (local - offset) / scale;
  Offset toCanvas(Offset box) => box * scale + offset;

  void apply(Canvas canvas) {
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale, scale);
  }
}

Paint _strokePaint(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Draws the first [upTo] strokes of a glyph as solid lines. Used for tiles,
/// the step-by-step row and the model letter.
class StrokesPainter extends CustomPainter {
  StrokesPainter({
    required this.strokes,
    this.upTo,
    this.color = const Color(0xFF1F2937),
    this.width = 7,
    this.highlightLast = false,
  });

  final List<SampledStroke> strokes;
  final int? upTo;
  final Color color;
  final double width;
  final bool highlightLast;

  @override
  void paint(Canvas canvas, Size size) {
    final t = BoxTransform(size);
    canvas.save();
    t.apply(canvas);
    final n = upTo ?? strokes.length;
    for (var i = 0; i < n && i < strokes.length; i++) {
      final last = highlightLast && i == n - 1;
      canvas.drawPath(
        strokes[i].path,
        _strokePaint(last ? AppColors.guideActive : color, width),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StrokesPainter old) =>
      old.strokes != strokes ||
      old.upTo != upTo ||
      old.color != color ||
      old.width != width ||
      old.highlightLast != highlightLast;
}

/// Draws a child's ink (lists of points in box units).
class InkPainter extends CustomPainter {
  InkPainter({required this.ink, this.color = AppColors.ink, this.width = 7});

  final List<List<Offset>> ink;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final t = BoxTransform(size);
    canvas.save();
    t.apply(canvas);
    paintInk(canvas, ink, color, width);
    canvas.restore();
  }

  static void paintInk(
    Canvas canvas,
    List<List<Offset>> ink,
    Color color,
    double width,
  ) {
    final paint = _strokePaint(color, width);
    for (final stroke in ink) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, width / 2, Paint()..color = color);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        final prev = stroke[i - 1];
        final cur = stroke[i];
        final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(InkPainter old) => true;
}

/// Which visual layers the copybook canvas shows.
class CopybookLayers {
  const CopybookLayers({
    this.showGuide = true,
    this.completedStrokes = 0,
    this.activeStroke,
    this.activeFraction = 0,
    this.demoStroke,
    this.demoFraction = 0,
    this.pulse = 0,
    this.ink = const [],
    this.currentInk = const [],
    this.showStartMarker = true,
    this.inkColor = AppColors.ink,
    this.ghost = false,
  });

  final bool showGuide;
  final int completedStrokes;
  final int? activeStroke;
  final double activeFraction;
  final int? demoStroke;
  final double demoFraction;
  final double pulse;
  final List<List<Offset>> ink;
  final List<Offset> currentInk;
  final bool showStartMarker;
  final Color inkColor;

  /// Very faint whole-letter hint (free-writing page).
  final bool ghost;
}

/// The practice sheet: ruled lines, dotted guide, demo animation, ink.
class CopybookPainter extends CustomPainter {
  CopybookPainter({
    required this.strokes,
    required this.script,
    required this.layers,
    this.matraY = 22,
    this.baselineY = 78,
  });

  final List<SampledStroke> strokes;
  final Script script;
  final CopybookLayers layers;
  final double matraY;
  final double baselineY;

  @override
  void paint(Canvas canvas, Size size) {
    final t = BoxTransform(size);
    canvas.save();
    t.apply(canvas);
    _paintRuling(canvas);
    if (layers.ghost) {
      for (final s in strokes) {
        canvas.drawPath(
          s.path,
          _strokePaint(AppColors.guide.withValues(alpha: 0.22), 7),
        );
      }
    }
    if (layers.showGuide) _paintGuide(canvas);
    if (layers.demoStroke != null) _paintDemo(canvas);
    InkPainter.paintInk(canvas, layers.ink, layers.inkColor, 7);
    if (layers.currentInk.isNotEmpty) {
      InkPainter.paintInk(canvas, [layers.currentInk], layers.inkColor, 7);
    }
    if (layers.showStartMarker &&
        layers.activeStroke != null &&
        layers.activeStroke! < strokes.length &&
        layers.currentInk.isEmpty) {
      _paintStartMarker(
        canvas,
        strokes[layers.activeStroke!],
        layers.activeStroke! + 1,
      );
    }
    canvas.restore();
  }

  void _paintRuling(Canvas canvas) {
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    switch (script) {
      case Script.bn:
        canvas.drawLine(
          Offset(4, matraY),
          Offset(96, matraY),
          thin..color = AppColors.matra.withValues(alpha: 0.55),
        );
        canvas.drawLine(
          Offset(4, baselineY),
          Offset(96, baselineY),
          thin..color = AppColors.baseline.withValues(alpha: 0.5),
        );
      case Script.en:
        canvas.drawLine(
          const Offset(4, 22),
          const Offset(96, 22),
          thin..color = AppColors.baseline.withValues(alpha: 0.5),
        );
        _dashedLine(
          canvas,
          const Offset(4, 44),
          const Offset(96, 44),
          thin..color = AppColors.midline.withValues(alpha: 0.7),
        );
        canvas.drawLine(
          const Offset(4, 78),
          const Offset(96, 78),
          thin..color = AppColors.matra.withValues(alpha: 0.55),
        );
        _dashedLine(
          canvas,
          const Offset(4, 96),
          const Offset(96, 96),
          thin..color = AppColors.midline.withValues(alpha: 0.5),
        );
      case Script.pre:
        break;
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
    canvas.drawPath(
      dashPath(path, dashArray: CircularIntervalList([2.0, 2.0])),
      p,
    );
  }

  void _paintGuide(Canvas canvas) {
    for (var i = 0; i < strokes.length; i++) {
      final s = strokes[i];
      if (i < layers.completedStrokes) {
        canvas.drawPath(
          s.path,
          _strokePaint(AppColors.inkDone.withValues(alpha: 0.18), 7),
        );
        continue;
      }
      final isActive = i == layers.activeStroke;
      final color = isActive ? AppColors.guideActive : AppColors.guide;
      final dashed = dashPath(
        s.path,
        dashArray: CircularIntervalList([2.4, 2.6]),
      );
      canvas.drawPath(
        dashed,
        _strokePaint(
          color.withValues(alpha: isActive ? 0.95 : 0.6),
          isActive ? 3.2 : 2.6,
        ),
      );
      if (isActive && layers.activeFraction > 0) {
        canvas.drawPath(
          s.partial(layers.activeFraction),
          _strokePaint(AppColors.guideActive.withValues(alpha: 0.35), 7),
        );
      }
      if (isActive && !s.isDot) _paintDirectionArrow(canvas, s, color);
    }
  }

  void _paintDirectionArrow(Canvas canvas, SampledStroke s, Color color) {
    final a = s.pointAt(0.18);
    final b = s.pointAt(0.22);
    final dir = b - a;
    if (dir.distance == 0) return;
    final u = dir / dir.distance;
    final n = Offset(-u.dy, u.dx);
    final tip = b;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - u.dx * 4 + n.dx * 2.6, tip.dy - u.dy * 4 + n.dy * 2.6)
      ..lineTo(tip.dx - u.dx * 4 - n.dx * 2.6, tip.dy - u.dy * 4 - n.dy * 2.6)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintDemo(Canvas canvas) {
    final idx = layers.demoStroke!;
    for (var i = 0; i < idx && i < strokes.length; i++) {
      canvas.drawPath(strokes[i].path, _strokePaint(AppColors.inkDone, 7));
    }
    if (idx >= strokes.length) return;
    final s = strokes[idx];
    canvas.drawPath(
      s.partial(layers.demoFraction),
      _strokePaint(AppColors.guideActive, 7),
    );
    final tip = s.pointAt(layers.demoFraction);
    canvas.drawCircle(
      tip,
      5.5,
      Paint()..color = AppColors.guideActive.withValues(alpha: 0.35),
    );
    canvas.drawCircle(tip, 3, Paint()..color = Colors.white);
    canvas.drawCircle(tip, 3, _strokePaint(AppColors.guideActive, 1.2));
  }

  void _paintStartMarker(Canvas canvas, SampledStroke s, int number) {
    final c = s.start;
    final r = 5.0 + 1.6 * layers.pulse;
    canvas.drawCircle(
      c,
      r + 3,
      Paint()
        ..color = AppColors.guideActive.withValues(
          alpha: 0.18 * (1 - layers.pulse),
        ),
    );
    canvas.drawCircle(c, r, Paint()..color = AppColors.guideActive);
    canvas.drawCircle(c, r, _strokePaint(Colors.white, 1.2));
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 6.5,
          fontWeight: FontWeight.w800,
          fontFamily: kDisplayFont,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(CopybookPainter old) => true;
}
