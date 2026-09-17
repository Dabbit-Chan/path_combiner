import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_combiner/src/fonts/cff_font.dart';

import 'font_fixture.dart';

void main() {
  test('CFF preserves subroutine stacks, hints, widths and closed contours',
      () {
    final font = CffFont(makeCff(
      charString: [
        ...cffNumbers([500, 0, 20]),
        1,
        19,
        0x80,
        ...cffNumbers([0, 0]),
        21,
        ...cffNumbers([100, 0, -107]),
        10,
        ...cffNumbers([0, 100, -107]),
        29,
        ...cffNumbers([-100, 0]),
        5,
        14,
      ],
      localSubroutines: const [
        [5, 11]
      ],
      globalSubroutines: const [
        [5, 11]
      ],
    ));
    final path = font.pathForGlyph(1);
    expect(path.getBounds(), const Rect.fromLTWH(0, 0, 100, 100));
    expect(path.contains(const Offset(50, 50)), isTrue);
    expect(path.computeMetrics().single.isClosed, isTrue);
    expect(path.computeMetrics().single.length, closeTo(400, 0.001));
  });

  test('CFF cubic operators preserve their endpoints', () {
    final cases = <(int, List<int>, Offset)>[
      (8, [10, 20, 30, 40, 50, 60], const Offset(90, 120)),
      (24, [10, 20, 30, 40, 50, 60, 10, 10], const Offset(100, 130)),
      (25, [10, 10, 10, 20, 30, 40, 50, 60], const Offset(100, 130)),
      (26, [10, 20, 30, 40], const Offset(20, 80)),
      (27, [10, 20, 30, 40], const Offset(70, 30)),
      (30, [10, 20, 30, 40, 50], const Offset(60, 90)),
      (31, [10, 20, 30, 40, 50], const Offset(80, 70)),
    ];
    for (final entry in cases) {
      final font = CffFont(makeCff(charString: [
        ...cffNumbers([0, 0]),
        21,
        ...cffNumbers(entry.$2),
        entry.$1,
        14,
      ]));
      final path = font.pathForGlyph(1);
      expect(path.getBounds().bottomRight, entry.$3, reason: '${entry.$1}');
      expect(path.computeMetrics().single.isClosed, isTrue);
    }
  });

  test('CFF flex operators produce two cubic segments', () {
    final cases = <(int, List<int>)>[
      (34, [10, 10, 20, 10, 10, 10, 10]),
      (35, [10, 0, 10, 20, 10, 0, 10, 0, 10, -20, 10, 0, 50]),
      (36, [10, 0, 10, 20, 10, 10, 10, -20, 10]),
      (37, [10, 0, 10, 20, 10, 0, 10, 0, 10, -20, 10]),
    ];
    for (final entry in cases) {
      final font = CffFont(makeCff(charString: [
        ...cffNumbers([0, 0]),
        21,
        ...cffNumbers(entry.$2),
        12,
        entry.$1,
        14,
      ]));
      final path = font.pathForGlyph(1);
      expect(path.getBounds(), const Rect.fromLTWH(0, 0, 60, 20));
      expect(path.computeMetrics().single.isClosed, isTrue);
    }
  });

  test('CFF rejects malformed and recursive charstrings', () {
    final recursive = CffFont(makeCff(
      charString: [
        ...cffNumbers([-107]),
        10,
        14
      ],
      localSubroutines: [
        [
          ...cffNumbers([-107]),
          10,
          11
        ]
      ],
    ));
    expect(() => recursive.pathForGlyph(1), throwsFormatException);
    final invalid = CffFont(makeCff(charString: [139, 8, 14]));
    expect(() => invalid.pathForGlyph(1), throwsFormatException);
    final missingEnd = CffFont(makeCff(charString: [139, 139, 21]));
    expect(() => missingEnd.pathForGlyph(1), throwsFormatException);
    expect(() => invalid.pathForGlyph(100), throwsFormatException);
  });
}
