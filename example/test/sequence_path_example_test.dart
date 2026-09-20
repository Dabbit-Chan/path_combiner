import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_combiner/path_combiner.dart';
import 'package:path_combiner_example/main.dart';
import 'package:path_combiner_example/path_examples.dart';
import 'package:path_combiner_example/sequence_path_example.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Path> actualPaths;
  final steps = [
    SequenceStep.icon(iconChoices[0]),
    const SequenceStep.text('你好'),
    SequenceStep.icon(iconChoices[5]),
    const SequenceStep.text('世界'),
    SequenceStep.icon(iconChoices[6]),
  ];

  setUpAll(() async {
    actualPaths = await loadSequencePaths(steps);
  });

  test('mixed sequence loads real centered Chinese and icon paths', () async {
    expect(actualPaths, hasLength(5));
    for (final path in actualPaths) {
      expect(path.computeMetrics(), isNotEmpty);
      final bounds = path.getBounds();
      expect(bounds.left, greaterThanOrEqualTo(19.99));
      expect(bounds.top, greaterThanOrEqualTo(19.99));
      expect(bounds.right, lessThanOrEqualTo(580.01));
      expect(bounds.bottom, lessThanOrEqualTo(220.01));
      expect(bounds.center.dx, closeTo(300, 0.01));
      expect(bounds.center.dy, closeTo(120, 0.01));
    }
    final mixed = await loadSequencePaths([
      const SequenceStep.text('中文 Flutter\n你好 2026！'),
      const SequenceStep.text(''),
      const SequenceStep.text('这是用于测试长文字自动缩放的中文内容'),
    ]);
    expect(mixed[0].computeMetrics(), isNotEmpty);
    expect(mixed[1].computeMetrics(), isEmpty);
    expect(mixed[2].getBounds().width, lessThanOrEqualTo(560.01));
    await expectLater(
      loadSequencePaths([const SequenceStep.text('\u{10FFFF}')]),
      throwsA(isA<StateError>().having((error) => error.message, 'message', contains('阶段 0'))),
    );
  });

  testWidgets('gallery opens the sequence example', (tester) async {
    _view(tester);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await _tap(tester, 'open-sequence-example');
    expect(find.byType(SequencePathExample), findsOneWidget);
    expect(_label(tester), startsWith('0 / 4'));
    await _tap(tester, 'sequence-play', settle: false);
    await tester.ensureVisible(find.byKey(const ValueKey('open-text-example')));
    await tester.tap(find.byKey(const ValueKey('open-text-example')));
    await tester.pumpAndSettle();
    expect(find.byType(SequencePathExample), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual next visits 0-1-2-3-4-0 without remounting the animator', (tester) async {
    _view(tester);
    await tester.pumpWidget(_host((_) async => actualPaths));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(PathCombiner));
    for (final index in [1, 2, 3, 4, 0]) {
      await _tap(tester, 'sequence-next');
      expect(_label(tester), startsWith('$index / 4'));
      expect(tester.widget<PathCombiner>(find.byType(PathCombiner)).path, same(actualPaths[index]));
      expect(tester.element(find.byType(PathCombiner)), same(element));
      expect(tester.takeException(), isNull);
    }
    await _tap(tester, 'sequence-step-3');
    expect(_label(tester), contains('世界'));
    await _tap(tester, 'sequence-reset');
    expect(_label(tester), startsWith('0 / 4'));
  });

  testWidgets('autoplay waits for animation end, wraps, pauses and disposes', (tester) async {
    _view(tester);
    await tester.pumpWidget(_host((_) async => actualPaths));
    await tester.pumpAndSettle();
    await _tap(tester, 'sequence-play', settle: false);
    for (final index in [1, 2, 3, 4, 0]) {
      expect(_label(tester), startsWith('$index / 4'));
      await tester.pump(const Duration(milliseconds: 1001));
      final animation = tester
          .state<ImplicitlyAnimatedWidgetState<PathCombiner>>(find.byType(PathCombiner))
          .animation;
      expect(
        animation.status,
        AnimationStatus.completed,
        reason: '阶段 $index，动画进度 ${animation.value}',
      );
      expect(find.text('暂停连播'), findsOneWidget);
      expect(_label(tester), startsWith('$index / 4'));
      await tester.pump(const Duration(milliseconds: 449));
      expect(_label(tester), startsWith('$index / 4'));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
    }
    await _tap(tester, 'sequence-play');
    final paused = _label(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(_label(tester), paused);
    await _tap(tester, 'sequence-play', settle: false);
    await tester.pump(const Duration(milliseconds: 1001));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing supports type, order, unlimited stages and regenerating', (tester) async {
    _view(tester);
    List<SequenceStep> generated = [];
    await tester.pumpWidget(
      _host((steps) async {
        generated = steps;
        return _fakePaths(steps.length);
      }),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sequence-text-1')), '中文 Path');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(const ValueKey('sequence-play'))).onPressed,
      isNull,
    );
    await _tap(tester, 'sequence-up-1');
    await _tap(tester, 'sequence-type-text-0');
    await _tap(tester, 'sequence-type-icon-0');
    await _tap(tester, 'sequence-remove-2');
    await _tap(tester, 'sequence-add-text');
    await _tap(tester, 'generate-sequence');
    expect(generated, hasLength(5));
    expect(generated.first.text, '中文 Path');
    expect(generated[1].icon, iconChoices[0]);
    expect(generated.last.text, '你好');
    expect(_label(tester), startsWith('0 / 4 · 中文 Path'));
    for (var index = 0; index < 3; index++) {
      await _tap(tester, 'sequence-add-icon');
    }
    // 阶段数量无上限：达到 8 个后仍可继续添加。
    expect(find.text('编辑序列 · 8 个阶段'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const ValueKey('sequence-add-icon'))).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(const ValueKey('sequence-add-text'))).onPressed,
      isNotNull,
    );
    await _tap(tester, 'sequence-add-text');
    expect(find.text('编辑序列 · 9 个阶段'), findsOneWidget);
    for (final id in [9, 8, 7, 6, 5, 4, 3]) {
      await _tap(tester, 'sequence-remove-$id');
    }
    expect(find.text('编辑序列 · 2 个阶段'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const ValueKey('sequence-remove-0'))).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading snapshot remains dirty after edits and failures can retry', (tester) async {
    _view(tester);
    final pending = Completer<List<Path>>();
    var attempts = 0;
    await tester.pumpWidget(
      _host((steps) {
        attempts++;
        if (attempts == 1) return pending.future;
        if (attempts == 2) return Future.error(StateError('字体加载失败'));
        return Future.value(_fakePaths(steps.length));
      }),
    );
    await tester.enterText(find.byKey(const ValueKey('sequence-text-1')), '新文字');
    pending.complete(_fakePaths(5));
    await tester.pumpAndSettle();
    expect(find.text('序列已修改，请生成后播放。'), findsOneWidget);
    await _tap(tester, 'generate-sequence');
    expect(find.byKey(const ValueKey('sequence-error')), findsOneWidget);
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sequence-error')), findsNothing);
    expect(find.text('轮廓已就绪，点击上方播放。'), findsOneWidget);
    expect(attempts, 3);
  });

  testWidgets('narrow screen with large text has no overflow', (tester) async {
    _view(tester, size: const Size(320, 780));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_host((_) async => actualPaths));
    await tester.pumpAndSettle();
    await _tap(tester, 'sequence-next');
    await _tap(tester, 'sequence-type-text-0');
    expect(tester.takeException(), isNull);
  });
}

Widget _host(Future<List<Path>> Function(List<SequenceStep>) loader) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SequencePathExample(loadPaths: loader)),
      ),
    );

List<Path> _fakePaths(int count) =>
    List.generate(count, (index) => Path()..addRect(Rect.fromLTWH(100, 80, 30.0 + index * 10, 60)));

String _label(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('sequence-current'))).data!;

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

void _view(WidgetTester tester, {Size size = const Size(1000, 1800)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
