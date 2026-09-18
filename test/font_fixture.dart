import 'dart:typed_data';
import 'dart:ui';

ByteData makeCff({
  required List<int> charString,
  List<List<int>> localSubroutines = const [],
  List<List<int>> globalSubroutines = const [],
}) {
  List<int> index(List<List<int>> entries) {
    final output = _Writer()..uint16(entries.length);
    if (entries.isEmpty) return output.bytes;
    output.bytes.add(2);
    var offset = 1;
    output.uint16(offset);
    for (final entry in entries) {
      offset += entry.length;
      output.uint16(offset);
    }
    for (final entry in entries) {
      output.bytes.addAll(entry);
    }
    return output.bytes;
  }

  List<int> integer(int value) => [29, ...(_Writer()..uint32(value)).bytes];
  final names = index([
    [65],
  ]);
  final strings = index([]);
  final global = index(globalSubroutines);
  final glyphs = index([
    [14],
    charString,
  ]);
  final private = [...integer(6), 19];
  final topLength = index([List.filled(17, 0)]).length;
  final glyphOffset = 4 + names.length + topLength + strings.length + global.length;
  final top = index([
    [
      ...integer(glyphOffset),
      17,
      ...integer(private.length),
      ...integer(glyphOffset + glyphs.length),
      18,
    ],
  ]);
  return ByteData.sublistView(
    Uint8List.fromList([
      1,
      0,
      4,
      4,
      ...names,
      ...top,
      ...strings,
      ...global,
      ...glyphs,
      ...private,
      ...index(localSubroutines),
    ]),
  );
}

List<int> cffNumbers(List<int> values) => values.expand((value) {
      if (value >= -107 && value <= 107) return [value + 139];
      return [28, ...(_Writer()..int16(value)).bytes];
    }).toList();

ByteData makeFont({
  bool longLocations = true,
  bool glyphArray = false,
  int? metricCount,
}) {
  final triangle = _simple([
    [const Offset(0, 0), const Offset(100, 0), const Offset(0, 100)],
  ]);
  final ring = _simple([
    [
      const Offset(0, 0),
      const Offset(100, 0),
      const Offset(100, 100),
      const Offset(0, 100),
    ],
    [
      const Offset(25, 25),
      const Offset(25, 75),
      const Offset(75, 75),
      const Offset(75, 25),
    ],
  ]);
  final curve = _simple(
    [
      [const Offset(0, 0), const Offset(50, 100), const Offset(100, 0)],
    ],
    flags: [
      1,
      0,
      1,
    ],
  );
  final offCurve = _simple(
    [
      [const Offset(0, 0), const Offset(100, 0), const Offset(50, 100)],
    ],
    flags: [
      0,
      0,
      0,
    ],
  );
  final compound = _Writer()
    ..int16(-1)
    ..zeros(8)
    ..uint16(0x23)
    ..uint16(1)
    ..int16(0)
    ..int16(0)
    ..uint16(0x0b)
    ..uint16(1)
    ..int16(100)
    ..int16(0)
    ..int16(8192);
  final attached = _Writer()
    ..int16(-1)
    ..zeros(8)
    ..uint16(0x23)
    ..uint16(1)
    ..int16(0)
    ..int16(0)
    ..uint16(1)
    ..uint16(1)
    ..uint16(1)
    ..uint16(0);
  final cyclic = _Writer()
    ..int16(-1)
    ..zeros(8)
    ..uint16(3)
    ..uint16(8)
    ..int16(0)
    ..int16(0);
  final compact = _Writer()
    ..int16(1)
    ..zeros(8)
    ..uint16(2)
    ..uint16(0)
    ..bytes.addAll([0x3f, 1, 0x27, 0, 100, 100, 0, 0, 100]);
  final glyphs = [
    <int>[],
    triangle,
    ring,
    curve,
    compound.bytes,
    <int>[],
    offCurve,
    attached.bytes,
    cyclic.bytes,
    compact.bytes,
  ];
  final outlines = _Writer();
  final locations = _Writer();
  for (final glyph in glyphs) {
    if (longLocations) {
      locations.uint32(outlines.bytes.length);
    } else {
      locations.uint16(outlines.bytes.length ~/ 2);
    }
    outlines.bytes.addAll(glyph);
    if (outlines.bytes.length.isOdd) outlines.zeros(1);
  }
  if (longLocations) {
    locations.uint32(outlines.bytes.length);
  } else {
    locations.uint16(outlines.bytes.length ~/ 2);
  }
  final head = ByteData(54)
    ..setUint16(18, 1000)
    ..setInt16(50, longLocations ? 1 : 0);
  final maxp = ByteData(6)..setUint16(4, glyphs.length);
  final count = metricCount ?? glyphs.length;
  final hhea = ByteData(36)
    ..setInt16(4, 800)
    ..setUint16(34, count);
  final hmtx = ByteData(count * 4 + (glyphs.length - count) * 2);
  for (var index = 0; index < count; index++) {
    hmtx.setUint16(index * 4, index == 5 ? 150 : 100 + index * 100);
  }
  final format4 = _Writer()
    ..uint16(4)
    ..uint16(glyphArray ? 32 + (glyphs.length - 1) * 2 : 32)
    ..uint16(0)
    ..uint16(4)
    ..zeros(6)
    ..uint16(0xe000 + glyphs.length - 2)
    ..uint16(0xffff)
    ..uint16(0)
    ..uint16(0xe000)
    ..uint16(0xffff)
    ..uint16(glyphArray ? 0 : (1 - 0xe000) & 0xffff)
    ..uint16(1)
    ..uint16(glyphArray ? 4 : 0)
    ..uint16(0);
  if (glyphArray) {
    for (var index = 1; index < glyphs.length; index++) {
      format4.uint16(index);
    }
  }
  final format12 = _Writer()
    ..uint16(12)
    ..uint16(0)
    ..uint32(28)
    ..uint32(0)
    ..uint32(1)
    ..uint32(0x10000)
    ..uint32(0x10000)
    ..uint32(1);
  final cmap = _Writer()
    ..uint16(0)
    ..uint16(2)
    ..uint16(3)
    ..uint16(1)
    ..uint32(20)
    ..uint16(3)
    ..uint16(10)
    ..uint32(20 + format4.bytes.length)
    ..bytes.addAll(format4.bytes)
    ..bytes.addAll(format12.bytes);
  final tables = <String, List<int>>{
    'head': head.buffer.asUint8List(),
    'maxp': maxp.buffer.asUint8List(),
    'hhea': hhea.buffer.asUint8List(),
    'hmtx': hmtx.buffer.asUint8List(),
    'loca': locations.bytes,
    'glyf': outlines.bytes,
    'cmap': cmap.bytes,
  };
  final output = _Writer()
    ..uint32(0x00010000)
    ..uint16(tables.length)
    ..zeros(6);
  var offset = 12 + tables.length * 16;
  for (final entry in tables.entries) {
    output.bytes.addAll(entry.key.codeUnits);
    output.uint32(0);
    output.uint32(offset);
    output.uint32(entry.value.length);
    offset += entry.value.length;
  }
  for (final table in tables.values) {
    output.bytes.addAll(table);
  }
  return ByteData.sublistView(Uint8List.fromList(output.bytes));
}

List<int> _simple(List<List<Offset>> contours, {List<int>? flags}) {
  final writer = _Writer()
    ..int16(contours.length)
    ..zeros(8);
  var count = 0;
  for (final contour in contours) {
    count += contour.length;
    writer.uint16(count - 1);
  }
  writer.uint16(0);
  writer.bytes.addAll(flags ?? List.filled(count, 1));
  var previousX = 0;
  for (final point in contours.expand((contour) => contour)) {
    writer.int16(point.dx.toInt() - previousX);
    previousX = point.dx.toInt();
  }
  var previousY = 0;
  for (final point in contours.expand((contour) => contour)) {
    writer.int16(point.dy.toInt() - previousY);
    previousY = point.dy.toInt();
  }
  return writer.bytes;
}

class _Writer {
  final bytes = <int>[];
  void zeros(int count) => bytes.addAll(List.filled(count, 0));
  void uint16(int value) => bytes.addAll([
        (value >> 8) & 255,
        value & 255,
      ]);
  void int16(int value) => uint16(value & 0xffff);
  void uint32(int value) => bytes.addAll([
        (value >> 24) & 255,
        (value >> 16) & 255,
        (value >> 8) & 255,
        value & 255,
      ]);
}
