import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_combiner/path_combiner.dart';
import 'package:path_combiner/src/fonts/open_type_font.dart';

import 'font_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const triangle = IconData(0xe000, fontFamily: 'TestIcons');
  late ByteData font;

  setUp(() => font = makeFont());

  test('fits, centers, offsets and flips the font coordinate system', () async {
    final path = await triangle.toPath(
      fontData: font,
      size: 100,
      offset: const Offset(10, 20),
    );
    expect(path.getBounds(), const Rect.fromLTWH(10, 20, 100, 100));
    expect(path.contains(const Offset(20, 100)), isTrue);
    expect(path.contains(const Offset(100, 30)), isFalse);
    expect(path.computeMetrics().single.isClosed, isTrue);
  });

  test('retains separate contours and holes', () async {
    final path = await const IconData(0xe001).toPath(fontData: font, size: 100);
    expect(path.computeMetrics().length, 2);
    expect(path.contains(const Offset(10, 10)), isTrue);
    expect(path.contains(const Offset(50, 50)), isFalse);
  });

  test('retains quadratic curves and implied on-curve points', () async {
    final curve =
        await const IconData(0xe002).toPath(fontData: font, size: 100);
    expect(curve.contains(const Offset(50, 90)), isTrue);
    expect(curve.contains(const Offset(50, 10)), isFalse);
    final implied = await const IconData(0xe005).toPath(fontData: font);
    expect(implied.computeMetrics().single.isClosed, isTrue);
    expect(implied.computeMetrics().single.length, greaterThan(0));
  });

  test('reads scaled compound glyphs and point attachments', () async {
    final scaled =
        await const IconData(0xe003).toPath(fontData: font, size: 150);
    expect(scaled.getBounds(), const Rect.fromLTWH(0, 25, 150, 100));
    expect(scaled.computeMetrics().length, 2);
    final attached =
        await const IconData(0xe006).toPath(fontData: font, size: 200);
    expect(attached.getBounds(), const Rect.fromLTWH(0, 50, 200, 100));
    expect(attached.computeMetrics().length, 2);
  });

  test('supports short loca, cmap glyph arrays and repeated short flags',
      () async {
    font = makeFont(longLocations: false, glyphArray: true);
    final path = await triangle.toPath(fontData: font);
    final compact = await const IconData(0xe008).toPath(fontData: font);
    expect(path.getBounds(), const Rect.fromLTWH(0, 0, 24, 24));
    expect(compact.getBounds(), path.getBounds());
    expect(compact.computeMetrics().single.length,
        closeTo(path.computeMetrics().single.length, 0.001));
  });

  test('supports supplementary code points via cmap format 12', () async {
    final path = await const IconData(0x10000).toPath(fontData: font);
    expect(path.getBounds(), const Rect.fromLTWH(0, 0, 24, 24));
  });

  test('mirrors directional icons only in RTL', () async {
    const directional = IconData(0xe000, matchTextDirection: true);
    final rtl = await directional.toPath(
      fontData: font,
      size: 100,
      textDirection: TextDirection.rtl,
    );
    final unchanged = await triangle.toPath(
      fontData: font,
      size: 100,
      textDirection: TextDirection.rtl,
    );
    expect(rtl.contains(const Offset(90, 20)), isTrue);
    expect(unchanged.contains(const Offset(90, 20)), isFalse);
  });

  test('blank glyph returns an empty path; missing glyph throws', () async {
    final blank = await const IconData(0xe004).toPath(fontData: font);
    expect(blank.computeMetrics(), isEmpty);
    await expectLater(
        const IconData(0x1234).toPath(fontData: font), throwsStateError);
  });

  test('rejects invalid geometry and conflicting font sources', () async {
    for (final size in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
          triangle.toPath(fontData: font, size: size), throwsArgumentError);
    }
    await expectLater(triangle.toPath(offset: const Offset(double.nan, 0)),
        throwsArgumentError);
    await expectLater(triangle.toPath(fontAsset: 'font.ttf', fontData: font),
        throwsArgumentError);
    await expectLater(const IconData(1).toPath(), throwsArgumentError);
  });

  test('rejects malformed, unsupported and cyclic fonts', () async {
    await expectLater(
        triangle.toPath(fontData: ByteData(3)), throwsFormatException);
    await expectLater(
        triangle.toPath(fontData: ByteData(4)..setUint32(0, 0x774f4646)),
        throwsUnsupportedError);
    await expectLater(
        const IconData(0xe007).toPath(fontData: font), throwsFormatException);
    final truncated = ByteData.sublistView(font.buffer.asUint8List(), 0, 100);
    await expectLater(
        triangle.toPath(fontData: truncated), throwsFormatException);
  });

  test('honors ByteData views with nonzero buffer offsets', () async {
    final padded = Uint8List(font.lengthInBytes + 16);
    padded.setRange(8, font.lengthInBytes + 8, font.buffer.asUint8List());
    final path = await triangle.toPath(
      fontData: ByteData.sublistView(padded, 8, font.lengthInBytes + 8),
    );
    expect(path.getBounds(), const Rect.fromLTWH(0, 0, 24, 24));
  });

  test('resolves Material font, caches data and returns independent paths',
      () async {
    final bundle = _Bundle({'fonts/MaterialIcons-Regular.otf': font});
    final converter = IconPathConverter(bundle: bundle);
    const icon = IconData(0xe000, fontFamily: 'MaterialIcons');
    final first = await converter.convert(icon);
    first.reset();
    expect((await converter.convert(icon)).computeMetrics(), isNotEmpty);
    expect(bundle.loads['fonts/MaterialIcons-Regular.otf'], 1);
    converter.clearCache();
    await converter.convert(icon);
    expect(bundle.loads['fonts/MaterialIcons-Regular.otf'], 2);
  });

  test('resolves package fonts and explicit assets', () async {
    final bundle = _Bundle({
      'FontManifest.json': _json([
        {
          'family': 'packages/my_icons/TestIcons',
          'fonts': [
            {'asset': 'packages/my_icons/icons.ttf'}
          ],
        },
      ]),
      'packages/my_icons/icons.ttf': font,
    });
    final converter = IconPathConverter(bundle: bundle);
    const icon =
        IconData(0xe000, fontFamily: 'TestIcons', fontPackage: 'my_icons');
    expect((await converter.convert(icon)).computeMetrics(), isNotEmpty);
    await converter.convert(icon);
    expect(bundle.loads['FontManifest.json'], 1);
    expect(
        (await converter.convert(triangle,
                fontAsset: 'packages/my_icons/icons.ttf'))
            .computeMetrics(),
        isNotEmpty);
    await expectLater(converter.convert(triangle), throwsStateError);
  });

  test('asset load failures can be retried', () async {
    final bundle = _Bundle({});
    final converter = IconPathConverter(bundle: bundle);
    await expectLater(
        converter.convert(triangle, fontAsset: 'font.ttf'), throwsStateError);
    bundle.assets['font.ttf'] = font;
    expect(
        (await converter.convert(triangle, fontAsset: 'font.ttf'))
            .computeMetrics(),
        isNotEmpty);
  });

  test('converts real Material Icons from the Flutter SDK', () async {
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await configFile.readAsString());
    final flutterPackage = (config['packages'] as List<dynamic>)
        .singleWhere((package) => package['name'] == 'flutter');
    final rootUri = flutterPackage['rootUri'] as String;
    final flutterRoot = configFile.uri.resolve(
      rootUri.endsWith('/') ? rootUri : '$rootUri/',
    );
    final fontFile = File.fromUri(flutterRoot.resolve(
      '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ));
    final fontData = ByteData.sublistView(await fontFile.readAsBytes());
    for (final icon in [
      Icons.home,
      Icons.favorite,
      Icons.star,
      Icons.menu,
      Icons.arrow_back,
      Icons.settings,
      Icons.add,
      Icons.circle_outlined
    ]) {
      final path = await icon.toPath(fontData: fontData, size: 200);
      expect(path.computeMetrics(), isNotEmpty);
      final bounds = path.getBounds();
      expect(bounds.width, lessThanOrEqualTo(200.001));
      expect(bounds.height, lessThanOrEqualTo(200.001));
      expect(bounds.center.dx, closeTo(100, 0.001));
      expect(bounds.center.dy, closeTo(100, 0.001));
    }
    final parser = OpenTypeFont(fontData);
    final codePoints =
        await File.fromUri(fontFile.uri.resolve('codepoints')).readAsLines();
    final uniqueCodePoints = codePoints
        .where((line) => line.trim().isNotEmpty)
        .map((line) =>
            int.parse(line.trim().split(RegExp(r'\s+')).last, radix: 16))
        .toSet();
    for (final codePoint in uniqueCodePoints) {
      final outline = parser.pathForCodePoint(codePoint);
      expect(outline, isNotNull, reason: 'U+${codePoint.toRadixString(16)}');
      expect(outline!.getBounds().isFinite, isTrue);
    }
  });

  testWidgets('converted outlines animate in PathCombiner', (tester) async {
    final first = await triangle.toPath(fontData: font, size: 100);
    final second =
        await const IconData(0xe001).toPath(fontData: font, size: 100);
    Widget widget(Path path) => Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 100,
            height: 100,
            child: PathCombiner(
              path: path,
              color: Colors.black,
              duration: const Duration(milliseconds: 200),
            ),
          ),
        );
    await tester.pumpWidget(widget(first));
    await tester.pumpWidget(widget(second));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

ByteData _json(Object value) =>
    ByteData.sublistView(Uint8List.fromList(utf8.encode(jsonEncode(value))));

class _Bundle extends CachingAssetBundle {
  _Bundle(this.assets);
  final Map<String, ByteData> assets;
  final loads = <String, int>{};

  @override
  Future<ByteData> load(String key) async {
    loads.update(key, (count) => count + 1, ifAbsent: () => 1);
    return assets[key] ?? (throw StateError('Missing asset: $key'));
  }
}
