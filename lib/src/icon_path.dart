import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show IconData;

import 'open_type_font.dart';

/// Extracts vector outlines from static OpenType/TrueType icon fonts.
///
/// Supports `glyf` and non-CID CFF Type 2 outlines.
/// CFF2, variable and bitmap fonts are not supported.
class IconPathConverter {
  IconPathConverter({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, OpenTypeFont> _fonts = {};
  List<dynamic>? _manifest;

  /// Converts [icon] into a new path, fitted proportionally and centered inside
  /// a [size] square whose top-left corner is [offset].
  ///
  /// Font assets are resolved from FontManifest.json, including package fonts.
  /// Material Icons use Flutter's bundled font. Supply [fontAsset] or [fontData]
  /// for fonts not declared in the manifest (for example FontLoader fonts).
  /// RTL mirroring is applied only when [IconData.matchTextDirection] is true.
  /// Missing fonts/glyphs and unsupported formats throw rather than returning
  /// a replacement character. Blank glyphs return an empty path.
  Future<Path> convert(
    IconData icon, {
    double size = 24,
    Offset offset = Offset.zero,
    TextDirection textDirection = TextDirection.ltr,
    String? fontAsset,
    ByteData? fontData,
  }) async {
    if (!size.isFinite || size <= 0) {
      throw ArgumentError.value(size, 'size', 'Must be finite and positive');
    }
    if (!offset.dx.isFinite || !offset.dy.isFinite) {
      throw ArgumentError.value(offset, 'offset', 'Must be finite');
    }
    if (fontAsset != null && fontData != null) {
      throw ArgumentError('Specify either fontAsset or fontData, not both');
    }

    Path? outline;
    if (fontData != null) {
      outline = OpenTypeFont(fontData).pathForCodePoint(icon.codePoint);
    } else {
      final assets = fontAsset != null ? [fontAsset] : await _assetsFor(icon);
      for (final asset in assets) {
        var font = _fonts[asset];
        if (font == null) {
          font = OpenTypeFont(await _bundle.load(asset));
          _fonts[asset] = font;
        }
        outline = font.pathForCodePoint(icon.codePoint);
        if (outline != null) break;
      }
    }
    if (outline == null) {
      throw StateError(
        'No glyph for U+${icon.codePoint.toRadixString(16).toUpperCase()} '
        'in font ${icon.fontFamily}.',
      );
    }
    final bounds = outline.getBounds();
    final extent = math.max(bounds.width, bounds.height);
    if (extent == 0) return Path();
    final scale = size / extent;
    final mirror =
        icon.matchTextDirection && textDirection == TextDirection.rtl;
    final scaleX = mirror ? -scale : scale;
    final matrix = Float64List(16)
      ..[0] = scaleX
      ..[5] = -scale
      ..[10] = 1
      ..[12] = offset.dx + size / 2 - bounds.center.dx * scaleX
      ..[13] = offset.dy + size / 2 + bounds.center.dy * scale
      ..[15] = 1;
    return outline.transform(matrix);
  }

  /// Releases cached font data; subsequent conversions reload the assets.
  void clearCache() {
    _fonts.clear();
    _manifest = null;
  }

  Future<List<String>> _assetsFor(IconData icon) async {
    final family = icon.fontFamily;
    if (family == null) {
      throw ArgumentError(
          'IconData.fontFamily or explicit font data is required');
    }
    if (family == 'MaterialIcons' && icon.fontPackage == null) {
      return ['fonts/MaterialIcons-Regular.otf'];
    }
    final qualifiedFamily = icon.fontPackage == null
        ? family
        : 'packages/${icon.fontPackage}/$family';
    _manifest ??=
        jsonDecode(await _bundle.loadString('FontManifest.json', cache: false))
            as List<dynamic>;
    final assets = <String>[];
    for (final entry in _manifest!) {
      if (entry['family'] == qualifiedFamily) {
        for (final font in entry['fonts'] as List<dynamic>) {
          assets.add(font['asset'] as String);
        }
      }
    }
    if (assets.isEmpty) {
      throw StateError(
        'No font asset registered for $qualifiedFamily. '
        'Supply fontAsset or fontData explicitly.',
      );
    }
    return assets;
  }
}

final _defaultIconPathConverter = IconPathConverter();

extension IconDataPathExtension on IconData {
  /// See [IconPathConverter.convert]. Initialize Flutter's binding before use.
  Future<Path> toPath({
    double size = 24,
    Offset offset = Offset.zero,
    TextDirection textDirection = TextDirection.ltr,
    String? fontAsset,
    ByteData? fontData,
  }) =>
      _defaultIconPathConverter.convert(
        this,
        size: size,
        offset: offset,
        textDirection: textDirection,
        fontAsset: fontAsset,
        fontData: fontData,
      );
}
