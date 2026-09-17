import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

const exampleCanvasSize = 240.0;
const _pathSize = 180.0;
const _pathOffset = Offset(30, 30);

class PathExample {
  const PathExample({
    required this.title,
    required this.description,
    required this.startLabel,
    required this.endLabel,
    required this.loadPaths,
    required this.code,
  });

  final String title;
  final String description;
  final String startLabel;
  final String endLabel;
  final Future<List<Path>> Function() loadPaths;
  final String code;
}

const pathExamples = [
  PathExample(
    title: 'Material 图标',
    description: '内置图标：房屋 ↔ 爱心。直接将 IconData 转为 Path，无需手写轮廓。',
    startLabel: 'home',
    endLabel: 'favorite',
    loadPaths: _materialPaths,
    code: '''final home = await Icons.home.toPath(
  size: 180, offset: const Offset(30, 30),
);
final heart = await Icons.favorite.toPath(
  size: 180, offset: const Offset(30, 30),
);''',
  ),
  PathExample(
    title: '菜单切换',
    description: '多轮廓图标：菜单 ↔ 关闭。试试不同的采样点补齐方式。',
    startLabel: 'menu',
    endLabel: 'close',
    loadPaths: _menuPaths,
    code: '''final menu = await Icons.menu.toPath(size: 180);
final close = await Icons.close.toPath(size: 180);

PathCombiner(
  path: isOpen ? close : menu,
  color: Colors.deepPurple,
  duration: const Duration(milliseconds: 800),
  combineMethod: CombineMethod.space,
);''',
  ),
  PathExample(
    title: 'Cupertino 字体',
    description: '第三方字体包：爱心 ↔ 星形。通过 fontPackage 自动查找 cupertino_icons 字体。',
    startLabel: 'Cupertino heart',
    endLabel: 'Cupertino star',
    loadPaths: _cupertinoPaths,
    code: '''final heart = await CupertinoIcons.heart.toPath(
  size: 180, offset: const Offset(30, 30),
);
final star = await CupertinoIcons.star.toPath(
  size: 180, offset: const Offset(30, 30),
);''',
  ),
  PathExample(
    title: 'RTL 镜像',
    description: '同一个返回图标：LTR ↔ RTL。matchTextDirection 图标会按方向镜像轮廓。',
    startLabel: 'LTR · 向左',
    endLabel: 'RTL · 向右',
    loadPaths: _directionalPaths,
    code: '''final left = await Icons.arrow_back.toPath(
  size: 180,
  textDirection: TextDirection.ltr,
);
final right = await Icons.arrow_back.toPath(
  size: 180,
  textDirection: TextDirection.rtl,
);''',
  ),
  PathExample(
    title: '几何路径',
    description: '原有示例：五角星 ↔ 圆形。手写 Path 与字体转换出的 Path 使用相同的动画组件。',
    startLabel: '五角星',
    endLabel: '圆形',
    loadPaths: _geometricPaths,
    code: '''PathCombiner(
  path: showStar ? starPath : circlePath,
  color: Colors.deepPurple,
  duration: const Duration(milliseconds: 800),
);''',
  ),
];

Future<List<Path>> _materialPaths() async => [
      await Icons.home.toPath(size: _pathSize, offset: _pathOffset),
      await Icons.favorite.toPath(size: _pathSize, offset: _pathOffset),
    ];

Future<List<Path>> _menuPaths() async => [
      await Icons.menu.toPath(size: _pathSize, offset: _pathOffset),
      await Icons.close.toPath(size: _pathSize, offset: _pathOffset),
    ];

Future<List<Path>> _cupertinoPaths() async => [
      await CupertinoIcons.heart.toPath(size: _pathSize, offset: _pathOffset),
      await CupertinoIcons.star.toPath(size: _pathSize, offset: _pathOffset),
    ];

Future<List<Path>> _directionalPaths() async => [
      await Icons.arrow_back.toPath(size: _pathSize, offset: _pathOffset),
      await Icons.arrow_back.toPath(
        size: _pathSize,
        offset: _pathOffset,
        textDirection: TextDirection.rtl,
      ),
    ];

Future<List<Path>> _geometricPaths() async {
  const center = Offset(exampleCanvasSize / 2, exampleCanvasSize / 2);
  const radius = _pathSize / 2;
  final vertices = List.generate(5, (index) {
    final angle = -math.pi / 2 + index * math.pi * 2 / 5;
    return center + Offset(math.cos(angle), math.sin(angle)) * radius;
  });
  final star = Path();
  final circle = Path();
  for (var index = 0; index < 5; index++) {
    final start = vertices[(index * 2) % 5];
    final end = vertices[((index + 1) * 2) % 5];
    star
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    circle
      ..moveTo(start.dx, start.dy)
      ..arcToPoint(end, radius: const Radius.circular(radius));
  }
  return [star, circle];
}
