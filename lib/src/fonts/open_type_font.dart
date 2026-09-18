import 'dart:typed_data';
import 'dart:ui';

import 'cff_font.dart';

class OpenTypeFont {
  OpenTypeFont(ByteData data) : _data = data {
    final signature = _uint32(0);
    if (signature != 0x00010000 && signature != 0x74727565 && signature != 0x4f54544f) {
      throw UnsupportedError('Only static OpenType/TrueType fonts are supported');
    }
    final tableCount = _uint16(4);
    for (var index = 0; index < tableCount; index++) {
      final record = 12 + index * 16;
      final tag = String.fromCharCodes(
        List.generate(4, (index) => _uint8(record + index)),
      );
      final offset = _uint32(record + 8);
      final length = _uint32(record + 12);
      _check(offset, length);
      _tables[tag] = _Table(offset, length);
    }
    if (_tables.containsKey('fvar')) {
      throw UnsupportedError('Variable font outlines are not supported');
    }
    for (final name in ['head', 'maxp', 'cmap']) {
      if (!_tables.containsKey(name)) {
        throw FormatException('Missing TrueType table: $name');
      }
    }
    _glyphCount = _uint16(_table('maxp', 6).offset + 4);
    _readCharacterMaps();
    if (_tables.containsKey('CFF ')) {
      final table = _tables['CFF ']!;
      _cff = CffFont(
        ByteData.sublistView(
          _data,
          table.offset,
          table.offset + table.length,
        ),
      );
      return;
    }
    if (!_tables.containsKey('glyf') || !_tables.containsKey('loca')) {
      throw UnsupportedError('Font has neither glyf nor CFF outlines');
    }
    final locationFormat = _int16(_table('head', 54).offset + 50);
    if (locationFormat != 0 && locationFormat != 1) {
      throw const FormatException('Invalid indexToLocFormat');
    }
    _longLocations = locationFormat == 1;
    _table('loca', (_glyphCount + 1) * (_longLocations ? 4 : 2));
  }

  final ByteData _data;
  final Map<String, _Table> _tables = {};
  final List<int> _characterMaps = [];
  late final int _glyphCount;
  late final bool _longLocations;
  CffFont? _cff;

  int get unitsPerEm {
    final value = _uint16(_table('head', 54).offset + 18);
    if (value < 16 || value > 16384) {
      throw const FormatException('Invalid font unitsPerEm');
    }
    return value;
  }

  int get ascender => _int16(_table('hhea', 36).offset + 4);

  double? advanceForCodePoint(int codePoint) {
    final glyph = _glyphIndex(codePoint);
    if (glyph == 0) return null;
    if (glyph >= _glyphCount) {
      throw const FormatException('Glyph index outside font');
    }
    final count = _uint16(_table('hhea', 36).offset + 34);
    if (count == 0 || count > _glyphCount) {
      throw const FormatException('Invalid numberOfHMetrics');
    }
    final metrics = _table('hmtx', count * 4 + (_glyphCount - count) * 2);
    final index = glyph < count ? glyph : count - 1;
    return _uint16(metrics.offset + index * 4).toDouble();
  }

  Path? textPathForCodePoint(int codePoint) {
    if (_cff == null) return pathForCodePoint(codePoint);
    final glyph = _glyphIndex(codePoint);
    return glyph == 0 ? null : _cff!.pathForGlyph(glyph, unitsPerEm: unitsPerEm);
  }

  Path? pathForCodePoint(int codePoint) {
    final glyph = _glyphIndex(codePoint);
    if (glyph == 0) return null;
    if (_cff != null) return _cff!.pathForGlyph(glyph);
    final contours = _readGlyph(glyph, <int>{});
    final path = Path();
    for (final contour in contours) {
      if (contour.isEmpty) continue;
      final first = contour.first;
      final last = contour.last;
      final start = first.onCurve
          ? first.position
          : last.onCurve
              ? last.position
              : (last.position + first.position) / 2;
      path.moveTo(start.dx, start.dy);
      Offset? control;
      for (var index = first.onCurve ? 1 : 0; index < contour.length; index++) {
        final point = contour[index];
        if (point.onCurve) {
          if (control == null) {
            path.lineTo(point.position.dx, point.position.dy);
          } else {
            path.quadraticBezierTo(control.dx, control.dy, point.position.dx, point.position.dy);
            control = null;
          }
        } else {
          if (control != null) {
            final middle = (control + point.position) / 2;
            path.quadraticBezierTo(control.dx, control.dy, middle.dx, middle.dy);
          }
          control = point.position;
        }
      }
      if (control != null) {
        path.quadraticBezierTo(control.dx, control.dy, start.dx, start.dy);
      }
      path.close();
    }
    return path;
  }

  void _readCharacterMaps() {
    final table = _table('cmap', 4);
    final count = _uint16(table.offset + 2);
    _within(table, table.offset + 4, count * 8);
    for (var index = 0; index < count; index++) {
      final record = table.offset + 4 + index * 8;
      final platform = _uint16(record);
      final encoding = _uint16(record + 2);
      if (platform != 0 && !(platform == 3 && (encoding == 1 || encoding == 10))) {
        continue;
      }
      final offset = table.offset + _uint32(record + 4);
      _within(table, offset, 2);
      final format = _uint16(offset);
      if (format != 4 && format != 12) continue;
      _within(table, offset, format == 12 ? 16 : 14);
      final length = format == 12 ? _uint32(offset + 4) : _uint16(offset + 2);
      _within(table, offset, length);
      final subtable = _Table(offset, length);
      if (format == 12) {
        _within(subtable, offset + 16, _uint32(offset + 12) * 12);
        _characterMaps.insert(0, offset);
      } else {
        final segments = _uint16(offset + 6) ~/ 2;
        _within(subtable, offset, 16 + segments * 8);
        _characterMaps.add(offset);
      }
    }
    if (_characterMaps.isEmpty) {
      throw UnsupportedError('Font requires a Unicode cmap format 4 or 12');
    }
  }

  int _glyphIndex(int codePoint) {
    for (final offset in _characterMaps) {
      if (_uint16(offset) == 12) {
        var low = 0;
        var high = _uint32(offset + 12) - 1;
        while (low <= high) {
          final middle = (low + high) ~/ 2;
          final group = offset + 16 + middle * 12;
          if (codePoint < _uint32(group)) {
            high = middle - 1;
          } else if (codePoint > _uint32(group + 4)) {
            low = middle + 1;
          } else {
            final glyph = _uint32(group + 8) + codePoint - _uint32(group);
            if (glyph != 0) return glyph;
            break;
          }
        }
      } else if (codePoint <= 0xffff) {
        final count = _uint16(offset + 6) ~/ 2;
        for (var index = 0; index < count; index++) {
          if (codePoint > _uint16(offset + 14 + index * 2)) continue;
          final start = _uint16(offset + 16 + count * 2 + index * 2);
          if (codePoint < start) break;
          final delta = _int16(offset + 16 + count * 4 + index * 2);
          final rangeAddress = offset + 16 + count * 6 + index * 2;
          final range = _uint16(rangeAddress);
          var glyph = 0;
          if (range == 0) {
            glyph = (codePoint + delta) & 0xffff;
          } else {
            final address = rangeAddress + range + (codePoint - start) * 2;
            _within(_Table(offset, _uint16(offset + 2)), address, 2);
            glyph = _uint16(address);
            if (glyph != 0) glyph = (glyph + delta) & 0xffff;
          }
          if (glyph != 0) return glyph;
          break;
        }
      }
    }
    return 0;
  }

  List<List<_Point>> _readGlyph(int glyph, Set<int> ancestors) {
    if (glyph < 0 || glyph >= _glyphCount) {
      throw const FormatException('Glyph index outside font');
    }
    if (ancestors.length >= 32 || !ancestors.add(glyph)) {
      throw const FormatException('Cyclic or excessively nested compound glyph');
    }
    try {
      final locations = _tables['loca']!.offset;
      final start =
          _longLocations ? _uint32(locations + glyph * 4) : _uint16(locations + glyph * 2) * 2;
      final end = _longLocations
          ? _uint32(locations + (glyph + 1) * 4)
          : _uint16(locations + (glyph + 1) * 2) * 2;
      final table = _tables['glyf']!;
      _within(table, table.offset + start, end - start);
      if (start == end) return [];
      final reader = _GlyphReader(_data, table.offset + start, end - start);
      final count = reader.int16();
      reader.skip(8);
      if (count >= 0) return _simpleGlyph(reader, count);
      return _compoundGlyph(reader, ancestors);
    } finally {
      ancestors.remove(glyph);
    }
  }

  List<List<_Point>> _simpleGlyph(_GlyphReader reader, int count) {
    final ends = List.generate(count, (_) => reader.uint16());
    reader.skip(reader.uint16());
    if (count == 0) return [];
    for (var index = 1; index < count; index++) {
      if (ends[index] <= ends[index - 1]) {
        throw const FormatException('Invalid contour endpoints');
      }
    }
    final pointCount = ends.last + 1;
    final flags = <int>[];
    while (flags.length < pointCount) {
      final flag = reader.uint8();
      final repeat = (flag & 8) != 0 ? reader.uint8() : 0;
      if (flags.length + repeat + 1 > pointCount) {
        throw const FormatException('Invalid repeated glyph flags');
      }
      flags.addAll(List.filled(repeat + 1, flag));
    }
    List<int> coordinates(int shortMask, int sameMask) {
      var current = 0;
      return flags.map((flag) {
        if ((flag & shortMask) != 0) {
          final delta = reader.uint8();
          current += (flag & sameMask) != 0 ? delta : -delta;
        } else if ((flag & sameMask) == 0) {
          current += reader.int16();
        }
        return current;
      }).toList();
    }

    final horizontal = coordinates(2, 16);
    final vertical = coordinates(4, 32);
    var start = 0;
    return ends.map((end) {
      final contour = <_Point>[];
      for (var index = start; index <= end; index++) {
        contour.add(
          _Point(
            Offset(horizontal[index].toDouble(), vertical[index].toDouble()),
            (flags[index] & 1) != 0,
          ),
        );
      }
      start = end + 1;
      return contour;
    }).toList();
  }

  List<List<_Point>> _compoundGlyph(_GlyphReader reader, Set<int> ancestors) {
    final contours = <List<_Point>>[];
    int flags;
    do {
      flags = reader.uint16();
      final glyph = reader.uint16();
      final words = (flags & 1) != 0;
      final xyArguments = (flags & 2) != 0;
      int argument() => words
          ? (xyArguments ? reader.int16() : reader.uint16())
          : (xyArguments ? reader.int8() : reader.uint8());
      final argument1 = argument();
      final argument2 = argument();
      var scaleX = 1.0;
      var scaleY = 1.0;
      var skewX = 0.0;
      var skewY = 0.0;
      if ((flags & 8) != 0) {
        scaleX = scaleY = reader.int16() / 16384;
      } else if ((flags & 64) != 0) {
        scaleX = reader.int16() / 16384;
        scaleY = reader.int16() / 16384;
      } else if ((flags & 128) != 0) {
        scaleX = reader.int16() / 16384;
        skewY = reader.int16() / 16384;
        skewX = reader.int16() / 16384;
        scaleY = reader.int16() / 16384;
      }
      Offset transform(Offset point) => Offset(
            point.dx * scaleX + point.dy * skewX,
            point.dx * skewY + point.dy * scaleY,
          );
      final component = _readGlyph(glyph, ancestors)
          .map(
            (contour) =>
                contour.map((point) => _Point(transform(point.position), point.onCurve)).toList(),
          )
          .toList();
      Offset translation;
      if (xyArguments) {
        translation = Offset(argument1.toDouble(), argument2.toDouble());
        if ((flags & 0x800) != 0) translation = transform(translation);
        if ((flags & 4) != 0) {
          translation = Offset(
            translation.dx.roundToDouble(),
            translation.dy.roundToDouble(),
          );
        }
      } else {
        final parentPoints = contours.expand((contour) => contour).toList();
        final childPoints = component.expand((contour) => contour).toList();
        if (argument1 >= parentPoints.length || argument2 >= childPoints.length) {
          throw const FormatException('Invalid compound glyph point attachment');
        }
        translation = parentPoints[argument1].position - childPoints[argument2].position;
      }
      contours.addAll(
        component.map(
          (contour) =>
              contour.map((point) => _Point(point.position + translation, point.onCurve)).toList(),
        ),
      );
    } while ((flags & 32) != 0);
    return contours;
  }

  _Table _table(String name, int minimumLength) {
    final table = _tables[name];
    if (table == null) throw FormatException('Missing font table: $name');
    _within(table, table.offset, minimumLength);
    return table;
  }

  void _within(_Table table, int offset, int length) {
    if (offset < table.offset || length < 0 || offset + length > table.offset + table.length) {
      throw const FormatException('Truncated or invalid TrueType table');
    }
  }

  void _check(int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > _data.lengthInBytes) {
      throw const FormatException('Truncated or invalid TrueType font');
    }
  }

  int _uint8(int offset) {
    _check(offset, 1);
    return _data.getUint8(offset);
  }

  int _uint16(int offset) {
    _check(offset, 2);
    return _data.getUint16(offset);
  }

  int _int16(int offset) {
    _check(offset, 2);
    return _data.getInt16(offset);
  }

  int _uint32(int offset) {
    _check(offset, 4);
    return _data.getUint32(offset);
  }
}

class _Table {
  const _Table(this.offset, this.length);
  final int offset;
  final int length;
}

class _Point {
  const _Point(this.position, this.onCurve);
  final Offset position;
  final bool onCurve;
}

class _GlyphReader {
  _GlyphReader(this.data, this.position, int length) : end = position + length;
  final ByteData data;
  int position;
  final int end;

  int _take(int length) {
    final start = position;
    if (length < 0 || position + length > end) {
      throw const FormatException('Truncated glyph data');
    }
    position += length;
    return start;
  }

  void skip(int length) => _take(length);
  int uint8() => data.getUint8(_take(1));
  int int8() => data.getInt8(_take(1));
  int uint16() => data.getUint16(_take(2));
  int int16() => data.getInt16(_take(2));
}
