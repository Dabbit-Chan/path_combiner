import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

const exampleCanvasSize = 240.0;
const textCanvasSize = Size(600, 240);
const baseFontAsset = 'assets/fonts/alimama_700.ttf';
final _textConverter = TextPathConverter();

Future<Path> convertExampleText(String text, {double fontSize = 80}) =>
    _textConverter.convert(text, fontAsset: baseFontAsset, fontSize: fontSize);

List<Path> fitExamplePaths(List<Path> paths, {bool uniformScale = true}) {
  double scaleFor(Path path) {
    final bounds = path.getBounds();
    return math.min(
      1.0,
      math.min(
        bounds.width == 0 ? 1.0 : 560 / bounds.width,
        bounds.height == 0 ? 1.0 : 200 / bounds.height,
      ),
    );
  }

  final sharedScale = paths.fold<double>(1, (scale, path) => math.min(scale, scaleFor(path)));
  return paths.map((path) {
    final scale = uniformScale ? sharedScale : scaleFor(path);
    final center = path.getBounds().center;
    return path.transform(
      Float64List(16)
        ..[0] = scale
        ..[5] = scale
        ..[10] = 1
        ..[12] = textCanvasSize.width / 2 - center.dx * scale
        ..[13] = textCanvasSize.height / 2 - center.dy * scale
        ..[15] = 1,
    );
  }).toList();
}

class IconChoice {
  const IconChoice(this.label, this.icon, this.code);

  final String label;
  final IconData icon;
  final String code;

  String get family => icon.fontPackage == null ? 'Material' : 'Cupertino';

  Future<Path> toPath({TextDirection direction = TextDirection.ltr}) => icon.toPath(
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
  IconChoice('Search', Icons.search_rounded, 'Icons.search_rounded'),
  IconChoice('Settings', Icons.settings_rounded, 'Icons.settings_rounded'),
  IconChoice('Person', Icons.person_rounded, 'Icons.person_rounded'),
  IconChoice('Notifications', Icons.notifications_rounded, 'Icons.notifications_rounded'),
  IconChoice('Camera', Icons.camera_alt_rounded, 'Icons.camera_alt_rounded'),
  IconChoice('Photo', Icons.photo_rounded, 'Icons.photo_rounded'),
  IconChoice('Music', Icons.music_note_rounded, 'Icons.music_note_rounded'),
  IconChoice('Play', Icons.play_arrow_rounded, 'Icons.play_arrow_rounded'),
  IconChoice('Pause', Icons.pause_rounded, 'Icons.pause_rounded'),
  IconChoice('Send', Icons.send_rounded, 'Icons.send_rounded'),
  IconChoice('Mail', Icons.mail_rounded, 'Icons.mail_rounded'),
  IconChoice('Chat', Icons.chat_bubble_rounded, 'Icons.chat_bubble_rounded'),
  IconChoice('Cloud', Icons.cloud_rounded, 'Icons.cloud_rounded'),
  IconChoice('Sun', Icons.wb_sunny_rounded, 'Icons.wb_sunny_rounded'),
  IconChoice('Flower', Icons.local_florist_rounded, 'Icons.local_florist_rounded'),
  IconChoice('Rocket', Icons.rocket_launch_rounded, 'Icons.rocket_launch_rounded'),
  IconChoice('Flight', Icons.flight_rounded, 'Icons.flight_rounded'),
  IconChoice('Explore', Icons.explore_rounded, 'Icons.explore_rounded'),
  IconChoice('Shopping bag', Icons.shopping_bag_rounded, 'Icons.shopping_bag_rounded'),
  IconChoice('Check', Icons.check_circle_rounded, 'Icons.check_circle_rounded'),
  IconChoice('Lock', Icons.lock_rounded, 'Icons.lock_rounded'),
  IconChoice('Home', CupertinoIcons.house, 'CupertinoIcons.house'),
  IconChoice('Search', CupertinoIcons.search, 'CupertinoIcons.search'),
  IconChoice('Settings', CupertinoIcons.gear, 'CupertinoIcons.gear'),
  IconChoice('Person', CupertinoIcons.person, 'CupertinoIcons.person'),
  IconChoice('Camera', CupertinoIcons.camera, 'CupertinoIcons.camera'),
  IconChoice('Photo', CupertinoIcons.photo, 'CupertinoIcons.photo'),
  IconChoice('Music', CupertinoIcons.music_note, 'CupertinoIcons.music_note'),
  IconChoice('Play', CupertinoIcons.play, 'CupertinoIcons.play'),
  IconChoice('Pause', CupertinoIcons.pause, 'CupertinoIcons.pause'),
  IconChoice('Send', CupertinoIcons.paperplane, 'CupertinoIcons.paperplane'),
  IconChoice('Mail', CupertinoIcons.envelope, 'CupertinoIcons.envelope'),
  IconChoice('Chat', CupertinoIcons.chat_bubble, 'CupertinoIcons.chat_bubble'),
  IconChoice('Cloud', CupertinoIcons.cloud, 'CupertinoIcons.cloud'),
  IconChoice('Sun', CupertinoIcons.sun_max, 'CupertinoIcons.sun_max'),
  IconChoice('Location', CupertinoIcons.location, 'CupertinoIcons.location'),
  IconChoice('Cart', CupertinoIcons.cart, 'CupertinoIcons.cart'),
  IconChoice('Check', CupertinoIcons.check_mark_circled, 'CupertinoIcons.check_mark_circled'),
  IconChoice('Lock', CupertinoIcons.lock, 'CupertinoIcons.lock'),
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
