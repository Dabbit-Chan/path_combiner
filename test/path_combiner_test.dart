import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_combiner/path_combiner.dart';
import 'package:path_combiner/src/path_lerp.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cached frames match uncached interpolation for every mode', () {
    final source = Path()
      ..addRect(const Rect.fromLTWH(0, 0, 20, 10))
      ..addRect(const Rect.fromLTWH(0, 40, 20, 10))
      ..addRect(const Rect.fromLTWH(0, 80, 20, 10));
    final target = Path()
      ..addOval(const Rect.fromLTWH(20, 10, 50, 30))
      ..addRect(const Rect.fromLTWH(30, 70, 20, 10));
    for (final style in PaintingStyle.values) {
      for (final method in CombineMethod.values) {
        final controller = PathCombineController()..combineMethod = method;
        final tween = PathTween(
          begin: source,
          precision: 2,
          controller: controller,
          paintingStyle: style,
        )..end = target;
        for (final progress in [0.01, 0.25, 0.5, 0.75, 0.99]) {
          final actual = tween.lerp(progress)!;
          final expected = PathUtil.lerpPath(
            source,
            target,
            progress,
            2,
            controller,
            paintingStyle: style,
          )!;
          final actualMetrics = actual.computeMetrics().toList();
          final expectedMetrics = expected.computeMetrics().toList();
          expect(actual.fillType, expected.fillType);
          expect(actualMetrics.length, expectedMetrics.length);
          for (var index = 0; index < actualMetrics.length; index++) {
            expect(actualMetrics[index].length, expectedMetrics[index].length);
            for (final fraction in [0.0, 0.25, 0.5, 0.75, 1.0]) {
              final distance = expectedMetrics[index].length * fraction;
              expect(
                actualMetrics[index].getTangentForOffset(distance)!.position,
                expectedMetrics[index].getTangentForOffset(distance)!.position,
              );
            }
          }
        }
      }
    }
  });

  test('empty-path preparation is cached and invalid precision is rejected', () {
    final source = Path();
    final target = Path()..addRect(const Rect.fromLTWH(0, 0, 20, 20));
    final tween = PathTween(begin: source, precision: 1, controller: PathCombineController())
      ..end = target;
    expect(tween.lerp(0.25), same(source));
    expect(tween.lerp(0.75), same(target));
    for (final precision in [0.0, -1.0, double.infinity, double.nan]) {
      tween.precision = precision;
      expect(() => tween.lerp(0.5), throwsArgumentError);
    }
  });

  testWidgets('PathCombiner defaults to stroke and accepts a painting style', (tester) async {
    final path = Path()..addRect(const Rect.fromLTWH(0, 0, 20, 20));

    Future<void> pump({PaintingStyle? paintingStyle}) => tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.square(
              dimension: 20,
              child: paintingStyle == null
                  ? PathCombiner(
                      path: path,
                      color: const Color(0xFF000000),
                      duration: Duration.zero,
                    )
                  : PathCombiner(
                      path: path,
                      color: const Color(0xFF000000),
                      paintingStyle: paintingStyle,
                      duration: Duration.zero,
                    ),
            ),
          ),
        );

    await pump();
    var widget = tester.widget<PathCombiner>(find.byType(PathCombiner));
    expect(widget.paintingStyle, PaintingStyle.stroke);
    dynamic painter = tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;
    expect(painter.paintingStyle, PaintingStyle.stroke);

    await pump(paintingStyle: PaintingStyle.fill);
    widget = tester.widget<PathCombiner>(find.byType(PathCombiner));
    expect(widget.paintingStyle, PaintingStyle.fill);
    painter = tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;
    expect(painter.paintingStyle, PaintingStyle.fill);
  });

  testWidgets('changing painting style updates contour alignment during animation', (tester) async {
    final start = Path()
      ..addRect(const Rect.fromLTWH(0, 0, 20, 10))
      ..addRect(const Rect.fromLTWH(0, 40, 20, 10))
      ..addRect(const Rect.fromLTWH(0, 80, 20, 10));
    final end = Path()
      ..addRect(const Rect.fromLTWH(100, 10, 20, 10))
      ..addRect(const Rect.fromLTWH(100, 70, 20, 10));
    Future<void> pump(Path path, PaintingStyle style) => tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: PathCombiner(
              path: path,
              color: const Color(0xFF000000),
              duration: const Duration(seconds: 1),
              paintingStyle: style,
            ),
          ),
        );
    int contourCount() {
      final dynamic painter = tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;
      return (painter.path as Path).computeMetrics().length;
    }

    await pump(start, PaintingStyle.stroke);
    await pump(end, PaintingStyle.stroke);
    await tester.pump(const Duration(milliseconds: 200));
    expect(contourCount(), 3);
    await pump(end, PaintingStyle.fill);
    expect(contourCount(), 6);
    await pump(end, PaintingStyle.stroke);
    expect(contourCount(), 3);
    await pump(end, PaintingStyle.fill);
    await tester.pumpAndSettle();
    expect(contourCount(), 2);
  });

  for (final method in CombineMethod.values) {
    final controller = PathCombineController()..combineMethod = method;

    test('$method balances repeated contours without collapsing them', () {
      final ring = Path()
        ..addRect(const Rect.fromLTWH(0, 0, 100, 100))
        ..addPolygon(
          const [Offset(20, 20), Offset(20, 80), Offset(80, 80), Offset(80, 20)],
          true,
        );
      final extra = Path()
        ..addRect(const Rect.fromLTWH(0, 0, 100, 100))
        ..addRect(const Rect.fromLTWH(120, 0, 20, 20))
        ..addPolygon(
          const [Offset(20, 20), Offset(20, 80), Offset(80, 80), Offset(80, 20)],
          true,
        );
      for (final progress in [0.0001, 0.9999]) {
        for (final pair in [
          [extra, ring],
          [ring, extra],
        ]) {
          final result = PathUtil.lerpPath(
            pair.first,
            pair.last,
            progress,
            1,
            controller,
            paintingStyle: PaintingStyle.fill,
          )!;
          expect(result.computeMetrics(), hasLength(6));
          expect(result.computeMetrics().every((metric) => metric.length > 70), isTrue);
          expect(result.contains(const Offset(50, 50)), isFalse);
          expect(result.contains(const Offset(10, 50)), isTrue);
        }
      }
    });

    test('$method retains full-contour splitting and original stroke correspondence', () {
      final start = Path()
        ..addRect(const Rect.fromLTWH(0, 0, 20, 10))
        ..addRect(const Rect.fromLTWH(0, 40, 20, 10))
        ..addRect(const Rect.fromLTWH(0, 80, 20, 10));
      final end = Path()
        ..addRect(const Rect.fromLTWH(100, 10, 20, 10))
        ..addRect(const Rect.fromLTWH(100, 70, 20, 10));
      for (final style in PaintingStyle.values) {
        final result = PathUtil.lerpPath(start, end, 0.5, 1, controller, paintingStyle: style)!;
        final metrics = result.computeMetrics().toList();
        final tops = style == PaintingStyle.fill ? [5, 5, 25, 55, 75, 75] : [5, 55, 75];
        expect(metrics, hasLength(tops.length));
        for (var index = 0; index < metrics.length; index++) {
          final metric = metrics[index];
          expect(metric.isClosed, isTrue);
          expect(metric.length, closeTo(60, 0.001));
          expect(
            metric.extractPath(0, metric.length).getBounds(),
            Rect.fromLTWH(50, tops[index].toDouble(), 20, 10),
          );
        }
      }
    });

    test('$method preserves closed contours throughout interpolation', () {
      final start = Path()..addRect(const Rect.fromLTWH(0, 0, 20, 20));
      final end = Path()..addRect(const Rect.fromLTWH(10, 10, 40, 30));
      for (final progress in [0.01, 0.25, 0.5, 0.75, 0.99]) {
        final result = PathUtil.lerpPath(start, end, progress, 3, controller)!;
        final metric = result.computeMetrics().single;
        expect(metric.isClosed, isTrue);
        final first = metric.getTangentForOffset(0)!.position;
        final last = metric.getTangentForOffset(metric.length)!.position;
        expect((first - last).distance, lessThan(0.001));
        expect(first.dx, closeTo(10 * progress, 0.001));
        expect(first.dy, closeTo(10 * progress, 0.001));
      }
    });

    test('$method retains the first and last points of open paths', () {
      final start = Path()
        ..moveTo(0, 0)
        ..lineTo(10, 0);
      final end = Path()
        ..moveTo(10, 10)
        ..lineTo(30, 10);
      final result = PathUtil.lerpPath(start, end, 0.5, 3, controller)!;
      final metric = result.computeMetrics().single;
      expect(metric.isClosed, isFalse);
      expect(metric.getTangentForOffset(0)!.position, const Offset(5, 5));
      expect(
        metric.getTangentForOffset(metric.length)!.position,
        const Offset(20, 5),
      );
      expect(metric.length, closeTo(15, 0.001));
    });

    test('$method does not drop contours shorter than the sampling step', () {
      final start = Path()..lineTo(0.2, 0);
      final end = Path()
        ..moveTo(0, 1)
        ..lineTo(0.4, 1);
      final metric = PathUtil.lerpPath(start, end, 0.5, 1.5, controller)!.computeMetrics().single;
      expect(metric.length, closeTo(0.3, 0.001));
      expect(metric.isClosed, isFalse);
    });

    test('$method does not force a mixed open/closed pair closed', () {
      final start = Path()..addRect(const Rect.fromLTWH(0, 0, 10, 10));
      final end = Path()
        ..moveTo(0, 0)
        ..lineTo(20, 0);
      final metric = PathUtil.lerpPath(start, end, 0.5, 3, controller)!.computeMetrics().single;
      expect(metric.isClosed, isFalse);
      expect(metric.getTangentForOffset(0)!.position, Offset.zero);
      expect(
        metric.getTangentForOffset(metric.length)!.position,
        const Offset(10, 0),
      );
    });

    test('$method returns exact source paths at animation endpoints', () {
      final start = Path()..addOval(const Rect.fromLTWH(0, 0, 10, 10));
      final end = Path()..addRect(const Rect.fromLTWH(10, 10, 20, 20));
      expect(PathUtil.lerpPath(start, end, 0, 3, controller), same(start));
      expect(PathUtil.lerpPath(start, end, 1, 3, controller), same(end));
    });
  }

  test('Alimama Hello / Flutter keeps every contour closed in both directions', () async {
    final font = ByteData.sublistView(
      await File('example/assets/fonts/alimama_700.ttf').readAsBytes(),
    );
    final hello = await 'Hello'.toPath(fontData: font, fontSize: 80);
    final flutter = await 'Flutter'.toPath(fontData: font, fontSize: 80);
    final count = flutter.computeMetrics().length;
    for (final method in CombineMethod.values) {
      final controller = PathCombineController()..combineMethod = method;
      for (final paths in [
        [hello, flutter],
        [flutter, hello],
      ]) {
        for (final progress in [0.01, 0.25, 0.5, 0.75, 0.99]) {
          final metrics = PathUtil.lerpPath(paths[0], paths[1], progress, 1.5, controller)!
              .computeMetrics()
              .toList();
          expect(metrics, hasLength(count));
          expect(
            metrics.every((metric) => metric.isClosed),
            isTrue,
            reason: '$method at $progress must not break glyph contours',
          );
        }
      }
    }
  });
}
