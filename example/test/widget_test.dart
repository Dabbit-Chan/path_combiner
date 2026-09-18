import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_combiner/path_combiner.dart';
import 'package:path_combiner/src/path_lerp.dart';
import 'package:path_combiner_example/main.dart';
import 'package:path_combiner_example/path_examples.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loadedPaths = <List<Path>>[];
  late List<PathExample> readyExamples;

  setUpAll(() async {
    for (final choice in [...iconChoices, ...directionalChoices]) {
      await choice.toPath();
    }
    for (final example in pathExamples) {
      loadedPaths.add(await example.loadPaths());
    }
    readyExamples = [
      for (var index = 0; index < pathExamples.length; index++)
        _copyExample(pathExamples[index], () async => loadedPaths[index]),
    ];
  });

  test('both icon examples load actual font paths', () {
    expect(loadedPaths, hasLength(2));
    for (final paths in loadedPaths) {
      expect(paths, hasLength(2));
      for (final path in paths) {
        expect(path.computeMetrics(), isNotEmpty);
        final bounds = path.getBounds();
        expect(bounds.left, greaterThanOrEqualTo(-0.001));
        expect(bounds.top, greaterThanOrEqualTo(-0.001));
        expect(bounds.right, lessThanOrEqualTo(exampleCanvasSize + 0.001));
        expect(bounds.bottom, lessThanOrEqualTo(exampleCanvasSize + 0.001));
      }
    }
    final left = loadedPaths[1][0];
    final right = loadedPaths[1][1];
    var mirroredDifferences = 0;
    for (var horizontal = 35.37; horizontal < 205; horizontal += 10) {
      for (var vertical = 35.19; vertical < 205; vertical += 10) {
        final point = Offset(horizontal, vertical);
        expect(
          left.contains(point),
          right.contains(Offset(exampleCanvasSize - horizontal, vertical)),
        );
        if (left.contains(point) != right.contains(point)) {
          mirroredDifferences++;
        }
      }
    }
    expect(mirroredDifferences, greaterThan(0));
  });

  test('menu and heart fill converges without losing the heart hole', () async {
    final menu = await iconChoices[2].toPath();
    final heart = await iconChoices[5].toPath();
    expect(menu.computeMetrics(), hasLength(3));
    expect(heart.computeMetrics(), hasLength(2));
    const center = Offset(120, 120);
    expect(heart.contains(center), isFalse);
    for (final method in CombineMethod.values) {
      final controller = PathCombineController()..combineMethod = method;
      for (final pair in [
        [menu, heart],
        [heart, menu],
      ]) {
        for (final progress in [0.0001, 0.9999]) {
          final expected = progress < 0.5 ? pair.first : pair.last;
          final actual = PathUtil.lerpPath(
            pair.first,
            pair.last,
            progress,
            1,
            controller,
            paintingStyle: PaintingStyle.fill,
          )!;
          var differences = 0;
          for (var horizontal = 35.37; horizontal < 205; horizontal += 5) {
            for (var vertical = 35.19; vertical < 205; vertical += 5) {
              final point = Offset(horizontal, vertical);
              if (actual.contains(point) != expected.contains(point)) differences++;
            }
          }
          expect(differences, lessThan(10), reason: '$method at $progress');
          if (identical(expected, heart)) expect(actual.contains(center), isFalse);
        }
      }
      for (final progress in [0.8, 0.9, 0.95, 0.99]) {
        final actual = PathUtil.lerpPath(
          menu,
          heart,
          progress,
          1,
          controller,
          paintingStyle: PaintingStyle.fill,
        )!;
        expect(actual.contains(center), isFalse, reason: '$method at $progress');
        final reverse = PathUtil.lerpPath(
          heart,
          menu,
          1 - progress,
          1,
          controller,
          paintingStyle: PaintingStyle.fill,
        )!;
        expect(reverse.contains(center), isFalse, reason: '$method reverse at ${1 - progress}');
      }
    }
  });

  test('menu morphs converge to other outlined icons in both directions', () async {
    final menu = await iconChoices[2].toPath();
    for (final choice in iconChoices.skip(6)) {
      final icon = await choice.toPath();
      for (final method in CombineMethod.values) {
        final controller = PathCombineController()..combineMethod = method;
        for (final pair in [
          [menu, icon],
          [icon, menu],
        ]) {
          for (final progress in [0.0001, 0.9999]) {
            final expected = progress < 0.5 ? pair.first : pair.last;
            final actual = PathUtil.lerpPath(
              pair.first,
              pair.last,
              progress,
              1,
              controller,
              paintingStyle: PaintingStyle.fill,
            )!;
            var differences = 0;
            for (var horizontal = 35.37; horizontal < 205; horizontal += 5) {
              for (var vertical = 35.19; vertical < 205; vertical += 5) {
                final point = Offset(horizontal, vertical);
                if (actual.contains(point) != expected.contains(point)) differences++;
              }
            }
            expect(differences, lessThan(10), reason: '${choice.label} $method at $progress');
          }
        }
      }
    }
  });

  testWidgets('all examples switch and animate both directions', (tester) async {
    _setView(tester, const Size(900, 1200));
    await tester.pumpWidget(MyApp(examples: readyExamples));
    await tester.pumpAndSettle();
    expect(find.text('path / studio'), findsOneWidget);

    for (var index = 0; index < readyExamples.length; index++) {
      final chip = find.byKey(ValueKey('example-$index'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(_label(tester), readyExamples[index].startLabel);
      expect(
        tester.widget<PathCombiner>(find.byType(PathCombiner)).path,
        same(loadedPaths[index][0]),
      );
      final toggle = find.byKey(const ValueKey('toggle-path'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(_label(tester), readyExamples[index].endLabel);
      expect(
        tester.widget<PathCombiner>(find.byType(PathCombiner)).path,
        same(loadedPaths[index][1]),
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(_label(tester), readyExamples[index].startLabel);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('start and end independently select either icon family', (tester) async {
    _setView(tester, const Size(1100, 1500));
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(_label(tester), 'Material · Home');
    await tester.tap(find.byKey(const ValueKey('start-icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cupertino · Heart').last);
    await tester.pumpAndSettle();
    expect(_label(tester), 'Cupertino · Heart');
    await tester.tap(find.byKey(const ValueKey('end-icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Material · Close').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-path')));
    await tester.pumpAndSettle();
    expect(_label(tester), 'Material · Close');
    await tester.tap(find.byKey(const ValueKey('example-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('directional-icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Material · Reply').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-path')));
    await tester.pumpAndSettle();
    expect(_label(tester), 'RTL · 从右到左');
    expect(tester.takeException(), isNull);
  });

  testWidgets('real icon pickers fit a narrow screen with large text', (tester) async {
    _setView(tester, const Size(320, 780));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('start-icon')));
    await tester.tap(find.byKey(const ValueKey('start-icon')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('motion and painting controls update the animator', (tester) async {
    _setView(tester, const Size(900, 1200));
    await tester.pumpWidget(MyApp(examples: readyExamples));
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('duration-slider'));
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(150, 0));
    await tester.pumpAndSettle();
    final selectedDuration = tester.widget<Slider>(slider).value.round();
    expect(selectedDuration, isNot(800));
    expect(
      tester.widget<PathCombiner>(find.byType(PathCombiner)).duration,
      Duration(milliseconds: selectedDuration),
    );
    final dropdown = find.byKey(const ValueKey('combine-method'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('center').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PathCombiner>(find.byType(PathCombiner)).combineMethod,
      CombineMethod.center,
    );
    final paintingStyle = find.byKey(const ValueKey('painting-style'));
    await tester.ensureVisible(paintingStyle);
    await tester.tap(find.descendant(of: paintingStyle, matching: find.text('fill')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PathCombiner>(find.byType(PathCombiner)).paintingStyle,
      PaintingStyle.fill,
    );
  });

  testWidgets('paths are loaded once per example, not during rebuilds', (tester) async {
    _setView(tester, const Size(900, 1200));
    final loads = [0, 0];
    final examples = [
      for (var index = 0; index < 2; index++)
        _copyExample(pathExamples[index], () async {
          loads[index]++;
          return loadedPaths[index];
        }),
    ];
    await tester.pumpWidget(MyApp(examples: examples));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-path')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('example-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('example-0')));
    await tester.pumpAndSettle();
    expect(loads, [1, 1]);
    expect(_label(tester), examples.first.startLabel);
  });

  testWidgets('loading, error and retry states are actionable', (tester) async {
    _setView(tester, const Size(900, 1200));
    final pending = Completer<List<Path>>();
    var attempts = 0;
    final example = _copyExample(pathExamples.first, () {
      attempts++;
      return attempts == 1 ? pending.future : Future.value(loadedPaths.first);
    });
    await tester.pumpWidget(MyApp(examples: [example]));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('toggle-path')), findsNothing);
    pending.completeError(StateError('font unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('字体加载失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(PathCombiner), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screens and larger text do not overflow', (tester) async {
    _setView(tester, const Size(320, 780));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MyApp(examples: readyExamples));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('toggle-path')));
    await tester.tap(find.byKey(const ValueKey('toggle-path')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_label(tester), readyExamples.first.endLabel);
  });
}

String? _label(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('current-shape'))).data;

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

PathExample _copyExample(
  PathExample example,
  Future<List<Path>> Function() loadPaths,
) =>
    PathExample(
      title: example.title,
      description: example.description,
      startLabel: example.startLabel,
      endLabel: example.endLabel,
      loadPaths: loadPaths,
      code: example.code,
    );
