import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_combiner/path_combiner.dart';
import 'package:path_combiner/src/path_lerp.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final method in CombineMethod.values) {
    final controller = PathCombineController()..combineMethod = method;

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

  test('Roboto Hello / Flutter keeps every contour closed in both directions', () async {
    final font = ByteData.sublistView(
      await File('example/assets/fonts/Roboto-Regular.ttf').readAsBytes(),
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
