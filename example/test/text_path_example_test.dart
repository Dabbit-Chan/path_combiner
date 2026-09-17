import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_combiner/path_combiner.dart';
import 'package:path_combiner_example/main.dart';
import 'package:path_combiner_example/path_examples.dart';
import 'package:path_combiner_example/text_path_example.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  });

  testWidgets('opens text example from existing gallery', (tester) async {
    final paths = [Path()..addRect(const Rect.fromLTWH(0, 0, 50, 50)), Path()];
    await tester.pumpWidget(MyApp(examples: [
      PathExample(
          title: 'Test',
          description: 'Test',
          startLabel: 'A',
          endLabel: 'B',
          loadPaths: () async => paths,
          code: ''),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-text-example')));
    await tester.pumpAndSettle();
    expect(find.byType(TextPathExample), findsOneWidget);
    expect(find.byKey(const ValueKey('text-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('text-end')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two strings generate separate paths and animate',
      (tester) async {
    _largeView(tester);
    await tester.pumpWidget(const MaterialApp(home: TextPathExample()));
    await tester.pumpAndSettle();
    expect(_label(tester), 'Hello');
    await tester.enterText(find.byKey(const ValueKey('text-start')), 'AB 12');
    await tester.enterText(find.byKey(const ValueKey('text-end')), 'Path\nOK');
    await tester.tap(find.byKey(const ValueKey('generate-text')));
    await tester.pumpAndSettle();
    expect(_label(tester), 'AB 12');
    final first = tester.widget<PathCombiner>(find.byType(PathCombiner)).path;
    final toggle = find.byKey(const ValueKey('toggle-text'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(_label(tester), 'Path\nOK');
    final second = tester.widget<PathCombiner>(find.byType(PathCombiner)).path;
    expect(identical(first, second), isFalse);
    expect(second.computeMetrics(), isNotEmpty);
    expect(second.getBounds().left, greaterThanOrEqualTo(19.99));
    expect(second.getBounds().bottom, lessThanOrEqualTo(220.01));
  });

  testWidgets('blank text and missing glyphs can be recovered from',
      (tester) async {
    _largeView(tester);
    await tester.pumpWidget(const MaterialApp(home: TextPathExample()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('text-start')), '');
    await tester.tap(find.byKey(const ValueKey('generate-text')));
    await tester.pumpAndSettle();
    expect(_label(tester), '（空白文本）');
    await tester.tap(find.byKey(const ValueKey('toggle-text')));
    await tester.pumpAndSettle();
    expect(_label(tester), 'Flutter');
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byKey(const ValueKey('text-start')), '中');
    await tester.tap(find.byKey(const ValueKey('generate-text')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('text-error')), findsOneWidget);
    expect(find.textContaining('U+4E2D'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('text-start')), 'Fixed');
    await tester.tap(find.byKey(const ValueKey('generate-text')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('text-error')), findsNothing);
    expect(_label(tester), 'Fixed');
  });

  testWidgets('narrow screen remains usable with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MaterialApp(home: TextPathExample()));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('toggle-text'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(_label(tester), 'Flutter');
    expect(tester.takeException(), isNull);
  });
}

String? _label(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('text-current'))).data;

void _largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
