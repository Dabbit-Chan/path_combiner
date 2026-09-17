import 'package:flutter/widgets.dart';

import 'path_lerp.dart';

class PathCombiner extends ImplicitlyAnimatedWidget {
  const PathCombiner({
    super.key,
    required this.path,
    this.controller,
    required this.color,
    this.strokeWidth = 5,
    this.strokeCap = StrokeCap.round,
    this.strokeJoin = StrokeJoin.round,
    this.combineMethod = CombineMethod.space,
    this.precision = 1,
    super.curve,
    required super.duration,
    super.onEnd,
  });

  final Path path;
  final PathCombineController? controller;
  final Color color;
  final double strokeWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
  final CombineMethod combineMethod;
  final double precision;

  @override
  AnimatedWidgetBaseState<PathCombiner> createState() => _PathCombinerState();
}

class _PathCombinerState extends AnimatedWidgetBaseState<PathCombiner> {
  PathTween? _path;

  PathCombineController? _controller;
  PathCombineController get _effectiveController =>
      widget.controller ?? (_controller ??= PathCombineController());

  @override
  void initState() {
    super.initState();
    _effectiveController.combineMethod = widget.combineMethod;
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _path = visitor(
      _path,
      widget.path,
      (dynamic value) => PathTween(
        begin: value as Path,
        precision: widget.precision,
        controller: _effectiveController,
      ),
    ) as PathTween?;
  }

  @override
  void didUpdateWidget(covariant PathCombiner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.combineMethod != widget.combineMethod) {
      _effectiveController.combineMethod = widget.combineMethod;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PathCombinerPainter(
        path: _path?.evaluate(animation),
        color: widget.color,
        strokeWidth: widget.strokeWidth,
        strokeCap: widget.strokeCap,
        strokeJoin: widget.strokeJoin,
      ),
    );
  }
}

class _PathCombinerPainter extends CustomPainter {
  _PathCombinerPainter({
    required this.path,
    required this.color,
    required this.strokeWidth,
    required this.strokeCap,
    required this.strokeJoin,
  });

  final Path? path;
  final Color color;
  final double strokeWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;

  @override
  void paint(Canvas canvas, Size size) {
    if (path != null) {
      Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = strokeCap
        ..strokeJoin = strokeJoin;

      canvas.drawPath(path!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PathCombinerPainter oldDelegate) {
    return path != oldDelegate.path;
  }
}
