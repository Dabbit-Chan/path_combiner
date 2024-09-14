library path_combiner;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

enum CombineMethod {
  start,
  end,
  center,
  space,
}

class PathCombineController {
  CombineMethod combineMethod = CombineMethod.space;
}

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
  _PathTween? _path;

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
      (dynamic value) => _PathTween(
        begin: value as Path,
        precision: widget.precision,
        controller: _effectiveController,
      ),
    ) as _PathTween?;
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

class _PathTween extends Tween<Path?> {
  _PathTween({
    super.begin,
    required this.precision,
    required this.controller,
  });

  final double precision;
  final PathCombineController controller;

  @override
  Path? lerp(double t) => _PathUtil.lerpPath(
        begin,
        end,
        t,
        precision,
        controller,
      );
}

class _PathUtil {
  static Path? lerpPath(
    Path? begin,
    Path? end,
    double t,
    double precision,
    PathCombineController controller,
  ) {
    if (identical(begin, end)) {
      return begin;
    }
    if (begin == null) {
      return end;
    }
    if (end == null) {
      return begin;
    }

    Path result = Path();

    List<ui.PathMetric> beginMetrics = begin.computeMetrics().toList();
    List<ui.PathMetric> endMetrics = end.computeMetrics().toList();

    if (beginMetrics.length != endMetrics.length) {
      combineList(beginMetrics, endMetrics, CombineMethod.space);
    }

    for (int i = 0; i < beginMetrics.length; i++) {
      computeMetric(
        beginMetric: beginMetrics[i],
        endMetric: endMetrics[i],
        result: result,
        t: t,
        combineMethod: controller.combineMethod,
        precision: precision,
      );
    }

    return result;
  }

  static void computeMetric({
    required ui.PathMetric beginMetric,
    required ui.PathMetric endMetric,
    required Path result,
    required double t,
    required CombineMethod combineMethod,
    required double precision,
  }) {
    double beginLength = beginMetric.length;
    double endLength = endMetric.length;

    List<Offset> beginPointList = [];
    List<Offset> endPointList = [];

    List<Offset> resultList = [];

    for (double i = 0; i < beginLength; i += precision) {
      beginPointList.add(beginMetric.getTangentForOffset(i)!.position);
    }

    for (double i = 0; i < endLength; i += precision) {
      endPointList.add(endMetric.getTangentForOffset(i)!.position);
    }

    // 处理两个list，使两个list的长度一致
    if (beginPointList.length != endPointList.length) {
      combineList(
        beginPointList,
        endPointList,
        combineMethod,
      );
    }

    for (int i = 0; i < beginPointList.length; i++) {
      resultList.add(Offset.lerp(beginPointList[i], endPointList[i], t)!);
    }

    result.moveTo(resultList[0].dx, resultList[0].dy);
    result.addPolygon(
      List.generate(
        resultList.length - 1,
        (i) => resultList[i + 1],
      ),
      false,
    );
  }

  static void combineList<T>(
      List<T> a, List<T> b, CombineMethod combineMethod) {
    assert(a.length != b.length,
        'Only handle the case where two lists are not the same length');

    late List<T> shortList;
    late List<T> longList;
    if (a.length > b.length) {
      longList = a;
      shortList = b;
    } else {
      longList = b;
      shortList = a;
    }

    switch (combineMethod) {
      case CombineMethod.start:
        {
          shortList.insertAll(
            0,
            List.generate(
              (longList.length - shortList.length),
              (_) => shortList.first,
            ),
          );
          break;
        }
      case CombineMethod.end:
        {
          shortList.addAll(List.generate(
            (longList.length - shortList.length),
            (_) => shortList.last,
          ));
          break;
        }
      case CombineMethod.center:
        {
          int index = (shortList.length / 2).floor();
          shortList.insertAll(
            index,
            List.generate(
              (longList.length - shortList.length),
              (_) => shortList[index],
            ),
          );
          break;
        }
      case CombineMethod.space:
        {
          int quotient = (longList.length / shortList.length).floor();
          int residue = longList.length % shortList.length;
          List<T> result = [];
          for (T t in shortList) {
            result.addAll(List.generate(quotient, (_) => t));
            if (residue > 0) {
              result.add(t);
              residue--;
            }
          }
          shortList.clear();
          shortList.addAll(result);
          break;
        }
    }
  }
}
