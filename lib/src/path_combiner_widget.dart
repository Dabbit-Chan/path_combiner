import 'package:flutter/widgets.dart';

import 'path_lerp.dart';

class PathCombiner extends ImplicitlyAnimatedWidget {
  const PathCombiner({
    super.key,
    required this.path,
    this.controller,
    required this.color,
    this.paintingStyle = PaintingStyle.stroke,
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
  final PaintingStyle paintingStyle;
  final double strokeWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
  final CombineMethod combineMethod;
  final double precision;

  @override
  AnimatedWidgetBaseState<PathCombiner> createState() => _PathCombinerState();
}

class _PathCombinerState extends AnimatedWidgetBaseState<PathCombiner> {
  /// Flutter 复用的路径 Tween，同时持有当前起终点的预处理缓存。
  PathTween? _path;

  /// 未传外部 controller 时，懒创建并复用的内部配置对象。
  PathCombineController? _controller;

  /// 优先使用调用方的 controller，否则使用内部对象。
  PathCombineController get _effectiveController =>
      widget.controller ?? (_controller ??= PathCombineController());

  @override
  void initState() {
    super.initState();
    _effectiveController.combineMethod = widget.combineMethod;
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    // 交给 Flutter 创建或更新 Tween；不是每次 build 都创建新对象。
    // 动画中途切换目标时，框架会以当前插值结果作为新的 begin。
    _path = visitor(
      _path,
      widget.path,
      (dynamic value) => PathTween(
        begin: value as Path,
        precision: widget.precision,
        controller: _effectiveController,
        paintingStyle: widget.paintingStyle,
      ),
    ) as PathTween?;
  }

  @override
  void didUpdateWidget(covariant PathCombiner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.combineMethod != widget.combineMethod ||
        oldWidget.controller != widget.controller) {
      _effectiveController.combineMethod = widget.combineMethod;
    }
    // 只同步配置；缓存由下一帧 lerp 按需更新，避免在这里重复做预处理。
    _path
      ?..paintingStyle = widget.paintingStyle
      ..precision = widget.precision
      ..controller = _effectiveController;
  }

  @override
  Widget build(BuildContext context) {
    // ticker 驱动 evaluate；缓存有效时只插值已准备的点并构建当前帧路径。
    return CustomPaint(
      painter: _PathCombinerPainter(
        path: _path?.evaluate(animation),
        color: widget.color,
        paintingStyle: widget.paintingStyle,
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
    required this.paintingStyle,
    required this.strokeWidth,
    required this.strokeCap,
    required this.strokeJoin,
  });

  final Path? path;
  final Color color;
  final PaintingStyle paintingStyle;
  final double strokeWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;

  @override
  void paint(Canvas canvas, Size size) {
    if (path != null) {
      Paint paint = Paint()
        ..style = paintingStyle
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = strokeCap
        ..strokeJoin = strokeJoin;

      canvas.drawPath(path!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PathCombinerPainter oldDelegate) {
    return path != oldDelegate.path ||
        color != oldDelegate.color ||
        paintingStyle != oldDelegate.paintingStyle ||
        strokeWidth != oldDelegate.strokeWidth ||
        strokeCap != oldDelegate.strokeCap ||
        strokeJoin != oldDelegate.strokeJoin;
  }
}
