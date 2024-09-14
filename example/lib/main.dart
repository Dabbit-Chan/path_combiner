import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Path starPath = Path();
  Path circlePath = Path();

  bool showStar = true;

  @override
  void initState() {
    super.initState();
    createPath(const Size(200, 200));
  }

  void createPath(Size size) {
    starPath.reset();
    circlePath.reset();
    double angle = 72;

    Offset middle = Offset(size.width / 2, size.height / 2);
    double radius = (size.width < size.height ? size.width : size.height) / 2;

    Offset top = middle.translate(0, -radius);
    Offset left = middle.translate(-radius * sin(angle.curve), -radius * cos(angle.curve));
    Offset right = middle.translate(radius * sin(angle.curve), -radius * cos(angle.curve));
    Offset leftBottom = middle.translate(-radius * sin((angle / 2).curve), radius * cos((angle / 2).curve));
    Offset rightBottom = middle.translate(radius * sin((angle / 2).curve), radius * cos((angle / 2).curve));

    // Create circlePath in segments
    circlePath.moveToPoint(left);
    circlePath.arcToPoint(right, radius: Radius.circular(radius));

    circlePath.moveToPoint(right);
    circlePath.arcToPoint(leftBottom, radius: Radius.circular(radius));

    circlePath.moveToPoint(leftBottom);
    circlePath.arcToPoint(top, radius: Radius.circular(radius));

    circlePath.moveToPoint(top);
    circlePath.arcToPoint(rightBottom, radius: Radius.circular(radius));

    circlePath.moveToPoint(rightBottom);
    circlePath.arcToPoint(left, radius: Radius.circular(radius));

    // Create starPath in segments
    starPath.moveToPoint(left);
    starPath.lineToPoint(right);

    starPath.moveToPoint(right);
    starPath.lineToPoint(leftBottom);

    starPath.moveToPoint(leftBottom);
    starPath.lineToPoint(top);

    starPath.moveToPoint(top);
    starPath.lineToPoint(rightBottom);

    starPath.moveToPoint(rightBottom);
    starPath.lineToPoint(left);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: PathCombiner(
            duration: const Duration(seconds: 1),
            path: showStar ? starPath : circlePath,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            showStar = !showStar;
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

extension RadiuExtension on num {
  double get curve => this * pi / 180;
}

extension PathExtension on Path {
  void moveToPoint(Offset offset) {
    moveTo(offset.dx, offset.dy);
  }

  void lineToPoint(Offset offset) {
    lineTo(offset.dx, offset.dy);
  }
}
