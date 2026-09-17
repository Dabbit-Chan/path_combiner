import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

const exampleCanvasSize = 240.0;

class IconChoice {
  const IconChoice(this.label, this.icon, this.code);

  final String label;
  final IconData icon;
  final String code;

  String get family => icon.fontPackage == null ? 'Material' : 'Cupertino';

  Future<Path> toPath({TextDirection direction = TextDirection.ltr}) =>
      icon.toPath(
        size: 180,
        offset: const Offset(30, 30),
        textDirection: direction,
      );
}

const iconChoices = [
  IconChoice('Home', Icons.home_rounded, 'Icons.home_rounded'),
  IconChoice('Favorite', Icons.favorite_rounded, 'Icons.favorite_rounded'),
  IconChoice('Menu', Icons.menu, 'Icons.menu'),
  IconChoice('Close', Icons.close, 'Icons.close'),
  IconChoice('Bolt', Icons.bolt, 'Icons.bolt'),
  IconChoice('Heart', CupertinoIcons.heart, 'CupertinoIcons.heart'),
  IconChoice('Star', CupertinoIcons.star, 'CupertinoIcons.star'),
  IconChoice('Bell', CupertinoIcons.bell, 'CupertinoIcons.bell'),
  IconChoice('Moon', CupertinoIcons.moon, 'CupertinoIcons.moon'),
];

const directionalChoices = [
  IconChoice('Back', Icons.arrow_back, 'Icons.arrow_back'),
  IconChoice('Forward', Icons.arrow_forward, 'Icons.arrow_forward'),
  IconChoice('Reply', Icons.reply, 'Icons.reply'),
  IconChoice('Undo', Icons.undo, 'Icons.undo'),
];

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
    title: 'Icon 变形',
    description: '从 Material 到 Cupertino，让不同字体的轮廓自然相遇。',
    startLabel: 'Material · Home',
    endLabel: 'Cupertino · Star',
    loadPaths: _iconPaths,
    code: '',
  ),
  PathExample(
    title: 'RTL 镜像',
    description: '同一个图标，两种阅读方向。观察轮廓如何左右镜像。',
    startLabel: 'LTR · 从左到右',
    endLabel: 'RTL · 从右到左',
    loadPaths: _directionalPaths,
    code: '',
  ),
];

Future<List<Path>> _iconPaths() async => [
      await iconChoices.first.toPath(),
      await iconChoices[6].toPath(),
    ];

Future<List<Path>> _directionalPaths() async => [
      await directionalChoices.first.toPath(),
      await directionalChoices.first.toPath(direction: TextDirection.rtl),
    ];
