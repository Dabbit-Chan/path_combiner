import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';

import 'open_type_font.dart';

/// Converts Unicode code points to font outlines using basic left-to-right
/// layout. This is not a text shaping engine: kerning, ligatures, bidi ordering,
/// combining-mark positioning and automatic font fallback are not performed.
class TextPathConverter {
  TextPathConverter({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, OpenTypeFont> _fonts = {};

  /// Returns a fresh path using exactly one of [fontAsset] or [fontData].
  ///
  /// [fontSize] scales the font's em square, not each glyph's visible bounds.
  /// [offset] is the top-left of the layout; the first baseline is offset by
  /// the font's hhea ascender. [letterSpacing] is added between code points,
  /// and [lineHeight] is the baseline-to-baseline distance in fontSize units.
  /// Spaces retain their font advance. CRLF/CR normalize to LF; tabs expand to
  /// four spaces. Empty input returns an empty path after argument validation.
  /// Missing glyphs throw StateError with the missing Unicode code point.
  Future<Path> convert(
    String text, {
    String? fontAsset,
    ByteData? fontData,
    double fontSize = 48,
    double letterSpacing = 0,
    double lineHeight = 1.2,
    Offset offset = Offset.zero,
  }) async {
    if ((fontAsset == null) == (fontData == null)) {
      throw ArgumentError('Specify exactly one of fontAsset or fontData');
    }
    if (!fontSize.isFinite || fontSize <= 0) {
      throw ArgumentError.value(
          fontSize, 'fontSize', 'Must be finite and positive');
    }
    if (!letterSpacing.isFinite) {
      throw ArgumentError.value(
          letterSpacing, 'letterSpacing', 'Must be finite');
    }
    if (!lineHeight.isFinite || lineHeight <= 0) {
      throw ArgumentError.value(
          lineHeight, 'lineHeight', 'Must be finite and positive');
    }
    if (!offset.dx.isFinite || !offset.dy.isFinite) {
      throw ArgumentError.value(offset, 'offset', 'Must be finite');
    }
    if (text.isEmpty) return Path();
    final font =
        fontData != null ? OpenTypeFont(fontData) : await _loadFont(fontAsset!);
    final scale = fontSize / font.unitsPerEm;
    final result = Path();
    final outlines = <int, Path>{};
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', '    ');
    var baseline = offset.dy + font.ascender * scale;
    for (final line in normalized.split('\n')) {
      var cursor = offset.dx;
      var first = true;
      for (final codePoint in line.runes) {
        final advance = font.advanceForCodePoint(codePoint);
        if (advance == null) {
          throw StateError(
            'Font has no glyph for U+${codePoint.toRadixString(16).toUpperCase()}. '
            'Choose a font containing this character.',
          );
        }
        if (!first) cursor += letterSpacing;
        first = false;
        final outline = outlines.putIfAbsent(
          codePoint,
          () => font.textPathForCodePoint(codePoint)!,
        );
        final matrix = Float64List(16)
          ..[0] = scale
          ..[5] = -scale
          ..[10] = 1
          ..[12] = cursor
          ..[13] = baseline
          ..[15] = 1;
        result.addPath(outline.transform(matrix), Offset.zero);
        cursor += advance * scale;
      }
      baseline += fontSize * lineHeight;
    }
    return result;
  }

  Future<OpenTypeFont> _loadFont(String asset) async {
    final cached = _fonts[asset];
    if (cached != null) return cached;
    final font = OpenTypeFont(await _bundle.load(asset));
    _fonts[asset] = font;
    return font;
  }

  void clearCache() => _fonts.clear();
}

final _textPathConverter = TextPathConverter();

extension StringPathExtension on String {
  /// Converts this text using [TextPathConverter.convert].
  Future<Path> toPath({
    String? fontAsset,
    ByteData? fontData,
    double fontSize = 48,
    double letterSpacing = 0,
    double lineHeight = 1.2,
    Offset offset = Offset.zero,
  }) =>
      _textPathConverter.convert(
        this,
        fontAsset: fontAsset,
        fontData: fontData,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        lineHeight: lineHeight,
        offset: offset,
      );
}
