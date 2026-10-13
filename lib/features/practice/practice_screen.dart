import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/speech.dart';
import '../../core/strings.dart';
import '../../data/glyph_repository.dart';
import '../../data/models.dart';
import '../../data/progress_store.dart';
import '../../data/settings_store.dart';
import '../../engine/stroke_geometry.dart';
import '../../engine/tracer.dart';
import '../../widgets/common.dart';
import '../../widgets/glyph_painters.dart';
import 'celebration.dart';
import 'practice_widgets.dart';

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({
    super.key,
    required this.categoryId,
    this.initialIndex = 0,
  });

  final String categoryId;
  final int initialIndex;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen>
    with TickerProviderStateMixin {
  late int _index;
  PracticeMode _mode = PracticeMode.watch;

  late List<SampledStroke> _strokes;
  late TraceSession _session;
  final List<List<List<Offset>>> _attempts = [];

  late final AnimationController _demo;
  late final AnimationController _pulse;
  late final FeedbackService _feedback;
  late List<_DemoSegment> _segments;

  String? _notice;
  Timer? _noticeTimer;
  int? _celebrationStars;
  bool _demoPlayedOnce = false;

  GlyphSet get _set => ref.read(glyphSetProvider).requireValue;
  List<Glyph> get _glyphs => _set.inCategory(widget.categoryId);
  Glyph get _glyph => _glyphs[_index];
  GlyphCategory get _category => _set.categoryOf(_glyph);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _feedback = ref.read(feedbackProvider);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _demo = AnimationController(vsync: this)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _demoPlayedOnce = true;
          ref.read(progressProvider.notifier).markWatched(_glyph.id);
          setState(() {});
        }
      });
    _loadGlyph(announce: true);
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _demo.dispose();
    _pulse.dispose();
    _feedback.stop();
    super.dispose();
  }

  // ---------------------------------------------------------------- setup

  void _loadGlyph({bool announce = false}) {
    _strokes = _glyph.strokes
        .map((s) => SampledStroke.fromSvg(s.d))
        .toList(growable: false);
    _segments = _DemoSegment.plan(_strokes);
    _demo.duration = Duration(milliseconds: _segments.last.endMs);
    _attempts.clear();
    _celebrationStars = null;
    _demoPlayedOnce = false;
    _resetSession();
    if (announce) _announce();
    if (_mode == PracticeMode.watch) _playDemo();
  }

  void _resetSession() {
    final difficulty = ref.read(settingsProvider).difficulty;
    final cfg = TraceConfig.forDifficulty(difficulty);
    _session = TraceSession(
      strokes: _strokes,
      config: _mode == PracticeMode.write ? cfg.relaxed() : cfg,
      freeMode: _mode == PracticeMode.write,
    );
  }

  void _announce() {
    final s = ref.read(stringsProvider);
    final fb = _feedback;
    final g = _glyph;
    if (g.isDrill) {
      fb.say(s.t(g.nameBn, g.nameEn), bengali: s.isBn);
    } else if (_category.script == Script.bn) {
      fb.say(g.sound ?? g.char, bengali: true);
    } else {
      fb.say(g.sound ?? g.char, bengali: false);
    }
  }

  void _playDemo() {
    _demo
      ..stop()
      ..value = 0
      ..forward();
  }

  void _setMode(PracticeMode mode) {
    if (mode == _mode) return;
    _feedback.tap();
    setState(() {
      _mode = mode;
      _celebrationStars = null;
      _notice = null;
      _demo.stop();
      _resetSession();
      if (mode == PracticeMode.watch) {
        _playDemo();
      } else if (mode == PracticeMode.write) {
        _showNotice(ref.read(stringsProvider).writeYourself, long: true);
      }
    });
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _glyphs.length) return;
    _feedback.tap();
    setState(() {
      _index = next;
      _notice = null;
      _loadGlyph(announce: true);
    });
  }

  void _showNotice(String text, {bool long = false}) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(Duration(milliseconds: long ? 2600 : 1400), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  // ------------------------------------------------------------- tracing

  bool get _interactive =>
      _mode != PracticeMode.watch && _celebrationStars == null;

  void _onPanStart(Offset boxPoint) {
    if (!_interactive) return;
    final fb = _feedback;
    final ev = _session.begin(boxPoint);
    if (ev == TraceEvent.rejectedStart) {
      fb.nudge();
      _showNotice(ref.read(stringsProvider).startHere);
    }
    setState(() {});
  }

  void _onPanUpdate(Offset boxPoint) {
    if (!_interactive) return;
    final ev = _session.move(boxPoint);
    if (ev == TraceEvent.offTrack) {
      _feedback.nudge();
      _showNotice(ref.read(stringsProvider).stayOnLine);
    }
    setState(() {});
  }

  void _onPanEnd() {
    if (!_interactive) return;
    final fb = _feedback;
    final s = ref.read(stringsProvider);
    final ev = _session.end();
    switch (ev) {
      case TraceEvent.strokeCompleted:
        fb.success();
      case TraceEvent.strokeReset:
        fb.nudge();
        _showNotice(s.tryAgain);
      case TraceEvent.glyphCompleted:
        _finish(_session.stars);
      default:
        break;
    }
    setState(() {});
  }

  void _finish(int stars) {
    final fb = _feedback;
    final s = ref.read(stringsProvider);
    fb.celebrate();
    ref.read(progressProvider.notifier).record(_glyph.id, _mode, stars);
    _attempts.add(_session.ink.map((e) => List<Offset>.from(e)).toList());
    final praise = s.praise[math.Random().nextInt(s.praise.length)];
    fb.say(praise, bengali: s.isBn);
    setState(() => _celebrationStars = stars);
  }

  void _again() {
    _feedback.tap();
    setState(() {
      _celebrationStars = null;
      _resetSession();
    });
  }

  void _clear() {
    _feedback.tap();
    setState(() => _resetSession());
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final leftHanded = ref.watch(settingsProvider.select((v) => v.leftHanded));
    final glyph = _glyph;
    final category = _category;
    final hasNext = _index + 1 < _glyphs.length;
    final hasPrev = _index > 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PracticeHeader(
              glyph: glyph,
              category: category,
              strings: s,
              index: _index,
              total: _glyphs.length,
              onBack: () => Navigator.of(context).maybePop(),
              onListen: () {
                _feedback.tap();
                _announce();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: SegmentedButton<PracticeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: PracticeMode.watch,
                    label: Text(s.watch),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                  ),
                  ButtonSegment(
                    value: PracticeMode.trace,
                    label: Text(s.trace),
                    icon: const Icon(Icons.gesture_rounded),
                  ),
                  ButtonSegment(
                    value: PracticeMode.write,
                    label: Text(s.write),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => _setMode(v.first),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final landscape = c.maxWidth > c.maxHeight * 1.15;
                  final side = _SidePanel(
                    strokes: _strokes,
                    strings: s,
                    glyph: glyph,
                    category: category,
                    mode: _mode,
                    currentStroke: _session.currentStroke,
                    demoStroke: _mode == PracticeMode.watch
                        ? _demoSegment().stroke
                        : null,
                    attempts: _attempts,
                    hint: _hintText(s),
                    notice: _notice,
                    actions: _actions(s, hasPrev, hasNext, leftHanded),
                    landscape: landscape,
                  );
                  final canvas = _buildCanvas();
                  if (landscape) {
                    final children = [
                      Expanded(flex: 5, child: canvas),
                      SizedBox(
                        width: math.min(360, c.maxWidth * 0.42),
                        child: side,
                      ),
                    ];
                    return Row(
                      children: leftHanded
                          ? children.reversed.toList()
                          : children,
                    );
                  }
                  return Column(
                    children: [
                      Expanded(child: canvas),
                      side,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(
    Strings s,
    bool hasPrev,
    bool hasNext,
    bool leftHanded,
  ) {
    final fb = _feedback;
    final primary = switch (_mode) {
      PracticeMode.watch => FilledButton.icon(
        onPressed: () {
          fb.tap();
          _playDemo();
        },
        icon: const Icon(Icons.replay_rounded),
        label: Text(s.replay),
      ),
      PracticeMode.trace => OutlinedButton.icon(
        onPressed: _session.hasInk ? _clear : null,
        icon: const Icon(Icons.cleaning_services_rounded),
        label: Text(s.clear),
      ),
      PracticeMode.write => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _session.hasInk ? _clear : null,
            icon: const Icon(Icons.cleaning_services_rounded),
            label: Text(s.clear),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _session.hasInk && _celebrationStars == null
                ? () => _finish(_session.starsSoFar)
                : null,
            icon: const Icon(Icons.check_rounded),
            label: Text(s.finish),
          ),
        ],
      ),
    };
    final prev = RoundIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: s.previous,
      onPressed: hasPrev ? () => _go(-1) : null,
    );
    final next = RoundIconButton(
      icon: Icons.arrow_forward_rounded,
      tooltip: s.next,
      onPressed: hasNext ? () => _go(1) : null,
    );
    final row = [prev, const Spacer(), primary, const Spacer(), next];
    return leftHanded ? row.reversed.toList() : row;
  }

  String _hintText(Strings s) {
    switch (_mode) {
      case PracticeMode.watch:
        final seg = _demoSegment();
        if (seg.stroke >= _strokes.length) return s.watchHint;
        return '${s.stroke(seg.stroke + 1)}: ${s.t(_glyph.strokes[seg.stroke].hintBn, _glyph.strokes[seg.stroke].hintEn)}';
      case PracticeMode.trace:
        if (_session.isComplete) return s.allDone;
        final i = _session.currentStroke;
        return '${s.stroke(i + 1)}: ${s.t(_glyph.strokes[i].hintBn, _glyph.strokes[i].hintEn)}';
      case PracticeMode.write:
        return s.writeYourself;
    }
  }

  _DemoAt _demoSegment() {
    final ms = _demo.value * (_demo.duration?.inMilliseconds ?? 1);
    return _DemoSegment.at(_segments, ms);
  }

  Widget _buildCanvas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              final t = BoxTransform(size);
              final seg = _mode == PracticeMode.watch ? _demoSegment() : null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: _category.color.withValues(alpha: 0.45),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _mode == PracticeMode.watch ? _playDemo : null,
                      onPanStart: (d) => _onPanStart(t.toBox(d.localPosition)),
                      onPanUpdate: (d) =>
                          _onPanUpdate(t.toBox(d.localPosition)),
                      onPanEnd: (_) => _onPanEnd(),
                      onPanCancel: _onPanEnd,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => CustomPaint(
                          painter: CopybookPainter(
                            strokes: _strokes,
                            script: _category.script,
                            matraY: _set.matraY,
                            baselineY: _set.baselineY,
                            layers: CopybookLayers(
                              showGuide: _mode == PracticeMode.trace,
                              ghost:
                                  _mode == PracticeMode.write &&
                                  !_session.hasInk,
                              completedStrokes: _session.currentStroke,
                              activeStroke:
                                  _mode == PracticeMode.trace &&
                                      !_session.isComplete
                                  ? _session.currentStroke
                                  : null,
                              activeFraction: _session.activeFraction,
                              demoStroke: seg?.stroke,
                              demoFraction: seg?.fraction ?? 0,
                              pulse: _pulse.value,
                              ink: _session.ink,
                              currentInk: _session.currentInk,
                              showStartMarker: _mode == PracticeMode.trace,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_mode == PracticeMode.watch &&
                      _demoPlayedOnce &&
                      !_demo.isAnimating)
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _setMode(PracticeMode.trace),
                        icon: const Icon(Icons.gesture_rounded),
                        label: Text(ref.read(stringsProvider).trace),
                      ),
                    ),
                  if (_celebrationStars != null)
                    Celebration(
                      stars: _celebrationStars!,
                      glyph: _glyph,
                      category: _category,
                      strings: ref.read(stringsProvider),
                      onAgain: _again,
                      onNext: _index + 1 < _glyphs.length ? () => _go(1) : null,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.strokes,
    required this.strings,
    required this.glyph,
    required this.category,
    required this.mode,
    required this.currentStroke,
    required this.demoStroke,
    required this.attempts,
    required this.hint,
    required this.notice,
    required this.actions,
    required this.landscape,
  });

  final List<SampledStroke> strokes;
  final Strings strings;
  final Glyph glyph;
  final GlyphCategory category;
  final PracticeMode mode;
  final int currentStroke;
  final int? demoStroke;
  final List<List<List<Offset>>> attempts;
  final String hint;
  final String? notice;
  final List<Widget> actions;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final highlighted = mode == PracticeMode.watch
        ? demoStroke
        : (mode == PracticeMode.trace ? currentStroke : null);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HintBar(
          text: notice ?? hint,
          highlighted: notice != null,
          color: category.color,
        ),
        const SizedBox(height: 6),
        if (strokes.length > 1 && mode != PracticeMode.write)
          StepRow(
            strokes: strokes,
            highlighted: highlighted,
            color: category.color,
            label: strings.strokeBuildUp,
          ),
        AttemptsStrip(
          strokes: strokes,
          attempts: attempts,
          label: strings.yourWriting,
          color: category.color,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(children: actions),
        ),
      ],
    );
    if (landscape) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Timing plan for the demonstration: each stroke animates for a duration
/// proportional to its length, followed by a short pause.
class _DemoSegment {
  const _DemoSegment(this.stroke, this.startMs, this.endMs, this.pauseMs);

  final int stroke;
  final int startMs;
  final int endMs;
  final int pauseMs;

  double get fraction => 1;

  static List<_DemoSegment> plan(List<SampledStroke> strokes) {
    final out = <_DemoSegment>[];
    var t = 350;
    for (var i = 0; i < strokes.length; i++) {
      final ms = (strokes[i].length * 16).clamp(450, 2200).toInt();
      out.add(_DemoSegment(i, t, t + ms, 420));
      t += ms + 420;
    }
    return out;
  }

  static _DemoAt at(List<_DemoSegment> segments, double ms) {
    for (final seg in segments) {
      if (ms < seg.startMs) return _DemoAt(seg.stroke, 0);
      if (ms <= seg.endMs) {
        return _DemoAt(
          seg.stroke,
          (ms - seg.startMs) / (seg.endMs - seg.startMs),
        );
      }
      if (ms <= seg.endMs + seg.pauseMs) return _DemoAt(seg.stroke, 1);
    }
    return _DemoAt(segments.length, 1);
  }
}

class _DemoAt {
  const _DemoAt(this.stroke, this.fraction);
  final int stroke;
  final double fraction;
}
