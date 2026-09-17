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

/// Interpolates between two paths by aligning their contour samples.
class PathTween extends Tween<Path?> {
  PathTween({
    super.begin,
    required this.precision,
    required this.controller,
  });

  final double precision;
  final PathCombineController controller;

  @override
  Path? lerp(double t) => PathUtil.lerpPath(
        begin,
        end,
        t,
        precision,
        controller,
      );
}

/// Resamples and combines path contours for interpolation.
class PathUtil {
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

    List<ui.PathMetric> beginMetrics =
        begin.computeMetrics().where((metric) => metric.length > 0).toList();
    List<ui.PathMetric> endMetrics =
        end.computeMetrics().where((metric) => metric.length > 0).toList();

    if (beginMetrics.isEmpty || endMetrics.isEmpty) {
      return t < 0.5 ? begin : end;
    }

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
          final difference = longList.length - shortList.length;
          final result = <T>[];

          // Keep the extra samples around the midpoint. For an even-sized
          // list, the two central samples share the inserted values; for an
          // odd-sized list, there is one central sample.
          final leftCenter = (shortList.length - 1) ~/ 2;
          final rightCenter = shortList.length ~/ 2;
          final leftExtra = difference ~/ 2;
          final rightExtra = difference - leftExtra;

          for (int i = 0; i < shortList.length; i++) {
            result.add(shortList[i]);
            if (leftCenter == rightCenter && i == leftCenter) {
              result.addAll(List<T>.filled(difference, shortList[i]));
            } else if (i == leftCenter) {
              result.addAll(List<T>.filled(leftExtra, shortList[i]));
            } else if (i == rightCenter) {
              result.addAll(List<T>.filled(rightExtra, shortList[i]));
            }
          }

          shortList
            ..clear()
            ..addAll(result);
          break;
        }
      case CombineMethod.space:
        {
          final result = List<T>.generate(longList.length, (i) {
            // Map both endpoints exactly and round the normalized position.
            // This distributes the remainder as evenly as integer sampling
            // allows, without front-loading it at the beginning.
            final sourceIndex =
                (i * (shortList.length - 1) / (longList.length - 1)).round();
            return shortList[sourceIndex];
          });

          shortList
            ..clear()
            ..addAll(result);
          break;
        }
    }
  }
}
