import 'dart:typed_data';
import 'dart:ui';

class CffFont {
  CffFont(ByteData data) {
    final reader = _Reader(data);
    if (reader.byte() != 1) {
      throw UnsupportedError('Only CFF version 1 is supported');
    }
    reader.byte();
    final headerSize = reader.byte();
    reader.position = headerSize;
    reader.index();
    final dictionaries = reader.index();
    if (dictionaries.length != 1) {
      throw const FormatException('Expected one CFF font dictionary');
    }
    final dictionary = _dictionary(dictionaries.single);
    if (dictionary.containsKey(1230)) {
      throw UnsupportedError('CID-keyed CFF fonts are not supported');
    }
    if ((dictionary[1206]?.single ?? 2) != 2) {
      throw UnsupportedError('Only Type 2 CFF charstrings are supported');
    }
    reader.index();
    _globalSubroutines = reader.index();
    final charStrings = dictionary[17];
    if (charStrings == null || charStrings.length != 1) {
      throw const FormatException('Missing CFF CharStrings');
    }
    reader.position = charStrings.single.toInt();
    _glyphs = reader.index();
    final private = dictionary[18];
    if (private != null) {
      if (private.length != 2) {
        throw const FormatException('Invalid CFF Private dictionary');
      }
      final offset = private[1].toInt();
      final local = _dictionary(reader.slice(offset, private[0].toInt()));
      if (local.containsKey(19)) {
        reader.position = offset + local[19]!.single.toInt();
        _localSubroutines = reader.index();
      }
    }
    final matrix = dictionary[1207];
    if (matrix != null) {
      if (matrix.length != 6) {
        throw const FormatException('Invalid CFF FontMatrix');
      }
      _matrix = Float64List(16)
        ..[0] = matrix[0]
        ..[1] = matrix[1]
        ..[4] = matrix[2]
        ..[5] = matrix[3]
        ..[10] = 1
        ..[12] = matrix[4]
        ..[13] = matrix[5]
        ..[15] = 1;
    }
  }

  late final List<ByteData> _glyphs;
  late final List<ByteData> _globalSubroutines;
  List<ByteData> _localSubroutines = [];
  Float64List? _matrix;

  Path pathForGlyph(int glyph, {int? unitsPerEm}) {
    if (glyph < 0 || glyph >= _glyphs.length) {
      throw const FormatException('CFF glyph index outside font');
    }
    final interpreter = _Type2(_localSubroutines, _globalSubroutines);
    interpreter.run(_glyphs[glyph]);
    final path = _matrix == null
        ? interpreter.path
        : interpreter.path.transform(_matrix!);
    if (unitsPerEm == null) return path;
    final scale = _matrix == null ? unitsPerEm / 1000 : unitsPerEm.toDouble();
    return path.transform(Float64List(16)
      ..[0] = scale
      ..[5] = scale
      ..[10] = 1
      ..[15] = 1);
  }
}

Map<int, List<double>> _dictionary(ByteData data) {
  final reader = _Reader(data);
  final result = <int, List<double>>{};
  var operands = <double>[];
  while (!reader.done) {
    final value = reader.byte();
    if (value >= 32 || value == 28 || value == 29 || value == 30) {
      if (value == 29) {
        operands.add(reader.signed32().toDouble());
      } else if (value == 30) {
        final number = StringBuffer();
        var finished = false;
        while (!finished) {
          final packed = reader.byte();
          for (final nibble in [packed >> 4, packed & 15]) {
            if (nibble == 15) {
              finished = true;
              break;
            }
            if (nibble <= 9) {
              number.write(nibble);
            } else if (nibble == 10) {
              number.write('.');
            } else if (nibble == 11 || nibble == 12) {
              number.write(nibble == 11 ? 'e' : 'e-');
            } else if (nibble == 14) {
              number.write('-');
            } else {
              throw const FormatException('Invalid CFF real number');
            }
          }
        }
        operands.add(double.parse(number.toString()));
      } else {
        operands.add(reader.number(value));
      }
    } else {
      final operator = value == 12 ? 1200 + reader.byte() : value;
      result[operator] = operands;
      operands = [];
    }
  }
  return result;
}

class _Type2 {
  _Type2(this.localSubroutines, this.globalSubroutines);
  final List<ByteData> localSubroutines;
  final List<ByteData> globalSubroutines;
  final path = Path();
  final stack = <double>[];
  Offset position = Offset.zero;
  int stems = 0;
  int operations = 0;
  bool open = false;
  bool ended = false;
  bool widthSeen = false;

  void run(ByteData data, [int depth = 0]) {
    if (depth > 10) {
      throw const FormatException('Excessive CFF subroutine nesting');
    }
    final reader = _Reader(data);
    while (!reader.done && !ended) {
      if (++operations > 100000) {
        throw const FormatException('Excessive CFF charstring operations');
      }
      final operator = reader.byte();
      if (operator >= 32 || operator == 28) {
        stack.add(reader.number(operator));
        if (stack.length > 48) {
          throw const FormatException('CFF operand stack overflow');
        }
        continue;
      }
      if (operator == 10 || operator == 29) {
        if (stack.isEmpty) {
          throw const FormatException('Missing subroutine index');
        }
        final subroutines =
            operator == 10 ? localSubroutines : globalSubroutines;
        final bias = subroutines.length < 1240
            ? 107
            : subroutines.length < 33900
                ? 1131
                : 32768;
        final index = stack.removeLast().toInt() + bias;
        if (index < 0 || index >= subroutines.length) {
          throw const FormatException('Invalid CFF subroutine index');
        }
        run(subroutines[index], depth + 1);
        continue;
      }
      if (operator == 11) {
        if (depth == 0) {
          throw const FormatException('CFF return outside subroutine');
        }
        return;
      }
      switch (operator) {
        case 1:
        case 3:
        case 18:
        case 23:
        case 19:
        case 20:
          _width(stack.length.isOdd ? stack.length - 1 : stack.length);
          if (stack.length.isOdd) {
            throw const FormatException('Invalid CFF stems');
          }
          stems += stack.length ~/ 2;
          if (operator == 19 || operator == 20) reader.skip((stems + 7) ~/ 8);
          break;
        case 4:
        case 21:
        case 22:
          _width(operator == 21 ? 2 : 1);
          _count(operator == 21 ? 2 : 1);
          if (open) path.close();
          position += operator == 21
              ? Offset(stack[0], stack[1])
              : operator == 4
                  ? Offset(0, stack[0])
                  : Offset(stack[0], 0);
          path.moveTo(position.dx, position.dy);
          open = true;
          break;
        case 5:
          _multiple(2);
          for (var index = 0; index < stack.length; index += 2) {
            _line(stack[index], stack[index + 1]);
          }
          break;
        case 6:
        case 7:
          if (stack.isEmpty) throw const FormatException('Missing CFF line');
          var horizontal = operator == 6;
          for (final delta in stack) {
            _line(horizontal ? delta : 0, horizontal ? 0 : delta);
            horizontal = !horizontal;
          }
          break;
        case 8:
          _multiple(6);
          for (var index = 0; index < stack.length; index += 6) {
            _curve(stack.sublist(index, index + 6));
          }
          break;
        case 24:
          if (stack.length < 8 || (stack.length - 2) % 6 != 0) {
            throw const FormatException('Invalid rcurveline');
          }
          for (var index = 0; index < stack.length - 2; index += 6) {
            _curve(stack.sublist(index, index + 6));
          }
          _line(stack[stack.length - 2], stack.last);
          break;
        case 25:
          if (stack.length < 8 || (stack.length - 6) % 2 != 0) {
            throw const FormatException('Invalid rlinecurve');
          }
          for (var index = 0; index < stack.length - 6; index += 2) {
            _line(stack[index], stack[index + 1]);
          }
          _curve(stack.sublist(stack.length - 6));
          break;
        case 26:
        case 27:
          if (stack.length < 4 || stack.length % 4 > 1) {
            throw const FormatException('Invalid vvcurveto/hhcurveto');
          }
          var index = stack.length.isOdd ? 1 : 0;
          var initial = index == 1 ? stack[0] : 0.0;
          while (index < stack.length) {
            final values = stack.sublist(index, index + 4);
            _curve(operator == 26
                ? [initial, values[0], values[1], values[2], 0, values[3]]
                : [values[0], initial, values[1], values[2], values[3], 0]);
            initial = 0;
            index += 4;
          }
          break;
        case 30:
        case 31:
          if (stack.length < 4 || stack.length % 4 > 1) {
            throw const FormatException('Invalid vhcurveto/hvcurveto');
          }
          var horizontal = operator == 31;
          var index = 0;
          while (index + 4 <= stack.length) {
            final values = stack.sublist(index, index + 4);
            index += 4;
            final last = stack.length - index == 1 ? stack[index++] : 0.0;
            _curve(horizontal
                ? [values[0], 0, values[1], values[2], last, values[3]]
                : [0, values[0], values[1], values[2], values[3], last]);
            horizontal = !horizontal;
          }
          break;
        case 12:
          _flex(reader.byte());
          break;
        case 14:
          _width(stack.length == 1 || stack.length == 5
              ? stack.length - 1
              : stack.length);
          if (stack.isNotEmpty) {
            throw UnsupportedError('CFF seac composites are not supported');
          }
          if (open) path.close();
          ended = true;
          break;
        default:
          throw UnsupportedError(
              'Unsupported CFF charstring operator $operator');
      }
      stack.clear();
    }
    if (depth == 0 && !ended) {
      throw const FormatException('CFF charstring has no endchar');
    }
  }

  void _width(int expected) {
    if (!widthSeen) {
      if (stack.length > expected) stack.removeAt(0);
      widthSeen = true;
    }
  }

  void _count(int count) {
    if (stack.length != count) {
      throw const FormatException('Invalid CFF operand count');
    }
  }

  void _multiple(int count) {
    if (stack.isEmpty || stack.length % count != 0) {
      throw const FormatException('Invalid CFF operand count');
    }
  }

  void _line(double horizontal, double vertical) {
    if (!open) throw const FormatException('CFF line before moveto');
    position += Offset(horizontal, vertical);
    path.lineTo(position.dx, position.dy);
  }

  void _curve(List<double> values) {
    if (!open) throw const FormatException('CFF curve before moveto');
    final control1 = position + Offset(values[0], values[1]);
    final control2 = control1 + Offset(values[2], values[3]);
    position = control2 + Offset(values[4], values[5]);
    path.cubicTo(control1.dx, control1.dy, control2.dx, control2.dy,
        position.dx, position.dy);
  }

  void _flex(int operator) {
    switch (operator) {
      case 34:
        _count(7);
        _curve([stack[0], 0, stack[1], stack[2], stack[3], 0]);
        _curve([stack[4], 0, stack[5], -stack[2], stack[6], 0]);
        break;
      case 35:
        _count(13);
        _curve(stack.sublist(0, 6));
        _curve(stack.sublist(6, 12));
        break;
      case 36:
        _count(9);
        _curve([stack[0], stack[1], stack[2], stack[3], stack[4], 0]);
        _curve([
          stack[5],
          0,
          stack[6],
          stack[7],
          stack[8],
          -stack[1] - stack[3] - stack[7]
        ]);
        break;
      case 37:
        _count(11);
        final horizontal = stack[0] + stack[2] + stack[4] + stack[6] + stack[8];
        final vertical = stack[1] + stack[3] + stack[5] + stack[7] + stack[9];
        _curve(stack.sublist(0, 6));
        _curve([
          ...stack.sublist(6, 10),
          horizontal.abs() > vertical.abs() ? stack[10] : -horizontal,
          horizontal.abs() > vertical.abs() ? -vertical : stack[10],
        ]);
        break;
      default:
        throw UnsupportedError('Unsupported CFF escaped operator $operator');
    }
  }
}

class _Reader {
  _Reader(this.data);
  final ByteData data;
  int position = 0;
  bool get done => position == data.lengthInBytes;

  void _check(int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > data.lengthInBytes) {
      throw const FormatException('Truncated or invalid CFF data');
    }
  }

  int byte() {
    _check(position, 1);
    return data.getUint8(position++);
  }

  void skip(int count) {
    _check(position, count);
    position += count;
  }

  int unsigned(int count) {
    var value = 0;
    for (var index = 0; index < count; index++) {
      value = value * 256 + byte();
    }
    return value;
  }

  int signed32() {
    _check(position, 4);
    final value = data.getInt32(position);
    position += 4;
    return value;
  }

  double number(int first) {
    if (first == 28) {
      final value = unsigned(2);
      return (value >= 32768 ? value - 65536 : value).toDouble();
    }
    if (first == 255) return signed32() / 65536;
    if (first >= 32 && first <= 246) return (first - 139).toDouble();
    if (first >= 247 && first <= 250) {
      return ((first - 247) * 256 + byte() + 108).toDouble();
    }
    if (first >= 251 && first <= 254) {
      return (-(first - 251) * 256 - byte() - 108).toDouble();
    }
    throw const FormatException('Invalid CFF number');
  }

  ByteData slice(int offset, int length) {
    _check(offset, length);
    return ByteData.sublistView(data, offset, offset + length);
  }

  List<ByteData> index() {
    final count = unsigned(2);
    if (count == 0) return [];
    final offsetSize = byte();
    if (offsetSize < 1 || offsetSize > 4) {
      throw const FormatException('Invalid CFF INDEX offset size');
    }
    final offsets = List.generate(count + 1, (_) => unsigned(offsetSize));
    if (offsets.first != 1) {
      throw const FormatException('Invalid CFF INDEX start');
    }
    final start = position;
    final result = List.generate(
        count,
        (index) => slice(
              start + offsets[index] - 1,
              offsets[index + 1] - offsets[index],
            ));
    skip(offsets.last - 1);
    return result;
  }
}
