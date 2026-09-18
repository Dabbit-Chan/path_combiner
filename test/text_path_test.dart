import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_combiner/path_combiner.dart';

import 'font_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ByteData font;
  setUp(() => font = makeFont());

  test('lays out using advances, font size, ascender and offset', () async {
    final path = await '\ue000\ue000'.toPath(
      fontData: font,
      fontSize: 1000,
      offset: const Offset(10, 20),
    );
    expect(path.getBounds(), const Rect.fromLTWH(10, 720, 300, 100));
    final smaller = await '\ue000'.toPath(fontData: font, fontSize: 500);
    expect(smaller.getBounds(), const Rect.fromLTWH(0, 350, 50, 50));
  });

  test('blank glyph advances the cursor without visible contours', () async {
    final path = await '\ue000\ue004\ue000'.toPath(
      fontData: font,
      fontSize: 1000,
      letterSpacing: 5,
    );
    expect(path.computeMetrics().length, 2);
    expect(path.getBounds(), const Rect.fromLTWH(0, 700, 460, 100));
  });

  test('normalizes line breaks and resets horizontal spacing each line', () async {
    for (final separator in ['\n', '\r\n', '\r']) {
      final path = await '\ue000$separator\ue000'.toPath(
        fontData: font,
        fontSize: 1000,
        lineHeight: 1.5,
        letterSpacing: 12,
      );
      expect(path.getBounds(), const Rect.fromLTWH(0, 700, 100, 1600));
    }
  });

  test('supports supplementary runes and repeated final hmtx advance', () async {
    final supplementary = await '\u{10000}\ue000'.toPath(fontData: font, fontSize: 1000);
    expect(supplementary.getBounds().width, 300);
    final shortMetrics = await '\ue001\ue000'.toPath(
      fontData: makeFont(metricCount: 2),
      fontSize: 1000,
    );
    expect(shortMetrics.getBounds().width, 300);
  });

  test('retains holes and returns empty paths for blank strings', () async {
    final ring = await '\ue001'.toPath(fontData: font, fontSize: 1000);
    expect(ring.contains(const Offset(10, 710)), isTrue);
    expect(ring.contains(const Offset(50, 750)), isFalse);
    expect((await ''.toPath(fontData: font)).computeMetrics(), isEmpty);
    expect((await '\ue004\n'.toPath(fontData: font)).computeMetrics(), isEmpty);
  });

  test('missing glyph reports code point; invalid arguments fail', () async {
    await expectLater(
      'A'.toPath(fontData: font),
      throwsA(
        isA<StateError>().having((error) => error.message, 'message', contains('U+41')),
      ),
    );
    await expectLater('A'.toPath(), throwsArgumentError);
    await expectLater(
      'A'.toPath(fontData: font, fontAsset: 'font.ttf'),
      throwsArgumentError,
    );
    for (final size in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
        ''.toPath(fontData: font, fontSize: size),
        throwsArgumentError,
      );
      await expectLater(
        ''.toPath(fontData: font, lineHeight: size),
        throwsArgumentError,
      );
    }
    await expectLater(
      ''.toPath(fontData: font, letterSpacing: double.nan),
      throwsArgumentError,
    );
    await expectLater(
      ''.toPath(fontData: font, offset: const Offset(double.infinity, 0)),
      throwsArgumentError,
    );
  });

  test('caches font assets and returns independent paths', () async {
    final bundle = _FontBundle(font);
    final converter = TextPathConverter(bundle: bundle);
    final first = await converter.convert('\ue000', fontAsset: 'font.ttf');
    first.reset();
    expect(
      (await converter.convert('\ue000', fontAsset: 'font.ttf')).computeMetrics(),
      isNotEmpty,
    );
    expect(bundle.loads, 1);
    converter.clearCache();
    await converter.convert('\ue000', fontAsset: 'font.ttf');
    expect(bundle.loads, 2);
  });

  test('real Roboto preserves spaces and tabs; CFF scales consistently', () async {
    final config = File('.dart_tool/package_config.json').absolute;
    final packages = jsonDecode(await config.readAsString())['packages'] as List;
    final root = packages.singleWhere(
      (package) => package['name'] == 'flutter',
    )['rootUri'] as String;
    final fontDirectory = config.uri
        .resolve(root.endsWith('/') ? root : '$root/')
        .resolve('../../bin/cache/artifacts/material_fonts/');
    final roboto = ByteData.sublistView(
      await File.fromUri(fontDirectory.resolve('Roboto-Regular.ttf')).readAsBytes(),
    );
    final compact = await 'AB'.toPath(fontData: roboto);
    final spaced = await 'A B'.toPath(fontData: roboto);
    expect(spaced.getBounds().width, greaterThan(compact.getBounds().width));
    expect(
      (await 'A\tB'.toPath(fontData: roboto)).getBounds(),
      (await 'A    B'.toPath(fontData: roboto)).getBounds(),
    );
    expect((await '   \n'.toPath(fontData: roboto)).computeMetrics(), isEmpty);
    final cff = ByteData.sublistView(
      await File.fromUri(fontDirectory.resolve('MaterialIcons-Regular.otf')).readAsBytes(),
    );
    final glyph = String.fromCharCode(Icons.favorite.codePoint);
    final small = await glyph.toPath(fontData: cff, fontSize: 24);
    final large = await glyph.toPath(fontData: cff, fontSize: 48);
    expect(small.getBounds().width, closeTo(20, 1));
    expect(large.getBounds().width, closeTo(small.getBounds().width * 2, 0.01));
  });

  testWidgets('empty text transitions do not crash any combine method', (tester) async {
    final visible = await '\ue000'.toPath(fontData: font);
    final blank = Path();
    for (final method in CombineMethod.values) {
      Widget widget(Path path) => Directionality(
            textDirection: TextDirection.ltr,
            child: PathCombiner(
              path: path,
              color: Colors.black,
              combineMethod: method,
              duration: const Duration(milliseconds: 200),
            ),
          );
      await tester.pumpWidget(widget(visible));
      await tester.pumpAndSettle();
      await tester.pumpWidget(widget(blank));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      await tester.pumpWidget(widget(visible));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

class _FontBundle extends CachingAssetBundle {
  _FontBundle(this.font);
  final ByteData font;
  int loads = 0;
  @override
  Future<ByteData> load(String key) async {
    loads++;
    return font;
  }
}
