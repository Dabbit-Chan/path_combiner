import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_combiner/path_combiner.dart';
import 'package:path_combiner/src/path_lerp.dart' show PathTween, PathUtil;

Path rectangles(List<double> positions) {
  final path = Path();
  for (final position in positions) {
    path.addRect(Rect.fromLTWH(position, 0, 2, 2));
  }
  return path;
}

List<double> contourStarts(Path path) => [
      for (final metric in path.computeMetrics()) metric.getTangentForOffset(0)!.position.dx,
    ];

double minimumAssignmentCost(List<double> source, List<double> target) {
  final memo = <int, double>{};
  double visit(int row, int mask) {
    if (row == source.length) return 0;
    return memo.putIfAbsent(mask, () {
      var best = double.infinity;
      for (var column = 0; column < target.length; column++) {
        if (mask & (1 << column) != 0) continue;
        best = math.min(
          best,
          (source[row] - target[column]).abs() + visit(row + 1, mask | (1 << column)),
        );
      }
      return best;
    });
  }

  return visit(0, 0);
}

List<String> greedyPairs(List<double> source, List<double> target) {
  final edges = [
    for (var row = 0; row < source.length; row++)
      for (var column = 0; column < target.length; column++)
        (row, column, (source[row] - target[column]).abs()),
  ]..sort((first, second) {
      final costOrder = first.$3.compareTo(second.$3);
      if (costOrder != 0) return costOrder;
      final rowOrder = first.$1.compareTo(second.$1);
      return rowOrder != 0 ? rowOrder : first.$2.compareTo(second.$2);
    });
  final usedRows = <int>{};
  final usedColumns = <int>{};
  final pairs = List<String>.filled(source.length, '');
  for (final edge in edges) {
    if (usedRows.contains(edge.$1) || usedColumns.contains(edge.$2)) continue;
    usedRows.add(edge.$1);
    usedColumns.add(edge.$2);
    pairs[edge.$1] = '${source[edge.$1]}->${target[edge.$2]}';
  }
  return pairs;
}

void main() {
  test('public controller defaults to ordered matching', () {
    expect(PathCombineController().contourMatchMethod, ContourMatchMethod.ordered);
  });

  for (final method in ContourMatchMethod.values) {
    test('$method pairs reversed contours and invalidates cached preparation', () {
      final source = rectangles([0, 100]);
      final target = rectangles([100, 0]);
      final controller = PathCombineController();
      final tween = PathTween(begin: source, precision: 1, controller: controller)..end = target;
      expect(contourStarts(tween.lerp(0.5)!), [50, 50]);
      controller.contourMatchMethod = method;
      final expected = method == ContourMatchMethod.ordered ? [50.0, 50.0] : [0.0, 100.0];
      expect(contourStarts(tween.lerp(0.5)!), expected);
      expect(contourStarts(PathUtil.lerpPath(source, target, 0.5, 1, controller)!), expected);
      controller.contourMatchMethod = ContourMatchMethod.ordered;
      expect(contourStarts(tween.lerp(0.5)!), [50, 50]);
      expect(tween.lerp(0), same(source));
      expect(tween.lerp(1), same(target));
    });

    test('$method preserves normalized contour counts and fill rules', () {
      for (final style in PaintingStyle.values) {
        for (final fillType in PathFillType.values) {
          final source = rectangles([0, 10, 20])..fillType = fillType;
          final target = rectangles([20, 0])..fillType = fillType;
          final controller = PathCombineController()..contourMatchMethod = method;
          final result = PathUtil.lerpPath(
            source,
            target,
            0.5,
            1,
            controller,
            paintingStyle: style,
          )!;
          final expectedCount =
              style == PaintingStyle.fill && fillType == PathFillType.nonZero ? 6 : 3;
          expect(result.computeMetrics(), hasLength(expectedCount));
          expect(result.fillType, fillType);
          expect(result.computeMetrics().every((metric) => metric.isClosed), isTrue);
        }
      }
    });

    test('$method handles empty and single-contour paths', () {
      final controller = PathCombineController()..contourMatchMethod = method;
      final empty = Path();
      final target = rectangles([0]);
      expect(
        PathUtil.lerpPath(empty, target, 0.25, 1, controller),
        same(empty),
      );
      expect(PathUtil.lerpPath(empty, target, 0.5, 1, controller), same(target));
      expect(
        contourStarts(PathUtil.lerpPath(rectangles([0]), rectangles([10]), 0.5, 1, controller)!),
        [5],
      );
    });
  }

  test('Hungarian minimizes total cost rather than choosing the cheapest edge', () {
    final source = rectangles([0, 5]);
    final target = rectangles([4, 7]);
    final controller = PathCombineController()..contourMatchMethod = ContourMatchMethod.greedy;
    expect(contourStarts(PathUtil.lerpPath(source, target, 0.5, 1, controller)!), [3.5, 4.5]);
    controller.contourMatchMethod = ContourMatchMethod.hungarian;
    expect(contourStarts(PathUtil.lerpPath(source, target, 0.5, 1, controller)!), [2, 6]);
  });

  test('compressed matching agrees with independent expanded assignment solvers', () {
    final random = math.Random(42);
    for (final counts in [(2, 3), (3, 2), (3, 4), (4, 3), (1, 4), (4, 1), (2, 4), (4, 4)]) {
      for (var iteration = 0; iteration < 10; iteration++) {
        final source = List.generate(counts.$1, (_) => random.nextInt(30).toDouble());
        final target = List.generate(counts.$2, (_) => random.nextInt(30).toDouble());
        for (final style in PaintingStyle.values) {
          final count = style == PaintingStyle.fill
              ? counts.$1 ~/ counts.$1.gcd(counts.$2) * counts.$2
              : math.max(counts.$1, counts.$2);
          List<double> expand(List<double> values) => List.generate(count, (index) {
                final original = style == PaintingStyle.fill
                    ? index ~/ (count ~/ values.length)
                    : (index * (values.length - 1) / (count - 1)).round();
                return values[original];
              });
          final expandedSource = expand(source);
          final expandedTarget = expand(target);
          for (final method in [ContourMatchMethod.greedy, ContourMatchMethod.hungarian]) {
            final controller = PathCombineController()..contourMatchMethod = method;
            final result = PathUtil.lerpPath(
              rectangles(source),
              rectangles(target),
              0.5,
              1,
              controller,
              paintingStyle: style,
            )!;
            final midpoints = contourStarts(result);
            expect(midpoints, hasLength(count));
            final assignedTarget = [
              for (var row = 0; row < count; row++) 2 * midpoints[row] - expandedSource[row],
            ];
            expect([...assignedTarget]..sort(), [...expandedTarget]..sort());
            if (method == ContourMatchMethod.greedy) {
              final pairs = [
                for (var row = 0; row < count; row++)
                  '${expandedSource[row]}->${assignedTarget[row]}',
              ];
              expect(pairs, greedyPairs(expandedSource, expandedTarget));
            } else {
              var actualCost = 0.0;
              for (var row = 0; row < count; row++) {
                actualCost += (expandedSource[row] - assignedTarget[row]).abs();
              }
              expect(
                actualCost,
                closeTo(minimumAssignmentCost(expandedSource, expandedTarget), 1e-8),
              );
            }
          }
        }
      }
    }
  });

  testWidgets('widget synchronizes matching configuration during animation and controller changes',
      (tester) async {
    final source = rectangles([0, 100]);
    final target = rectangles([100, 0]);
    final controller = PathCombineController();
    Future<void> pump(Path path, ContourMatchMethod method, PathCombineController? configuration) =>
        tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: PathCombiner(
              path: path,
              controller: configuration,
              contourMatchMethod: method,
              color: const Color(0xFF000000),
              duration: const Duration(seconds: 1),
            ),
          ),
        );
    Path paintedPath() {
      final dynamic painter = tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;
      return painter.path as Path;
    }

    await pump(source, ContourMatchMethod.ordered, controller);
    await pump(target, ContourMatchMethod.ordered, controller);
    await tester.pump(const Duration(milliseconds: 500));
    expect(contourStarts(paintedPath()), [50, 50]);
    await pump(target, ContourMatchMethod.greedy, controller);
    expect(controller.contourMatchMethod, ContourMatchMethod.greedy);
    expect(contourStarts(paintedPath()), [0, 100]);
    await pump(target, ContourMatchMethod.hungarian, null);
    expect(contourStarts(paintedPath()), [0, 100]);
    final replacement = PathCombineController();
    await pump(target, ContourMatchMethod.hungarian, replacement);
    expect(replacement.contourMatchMethod, ContourMatchMethod.hungarian);
    expect(contourStarts(paintedPath()), [0, 100]);
    await tester.pumpAndSettle();
  });
}
