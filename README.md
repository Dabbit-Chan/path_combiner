# Path Combiner

A Flutter package for the animation of the combination of two paths

## Showcase

<img src="https://raw.githubusercontent.com/Dabbit-Chan/path_combiner/main/gifs/example.gif" width=60%>


## Getting started

`import 'package:path_combiner/path_combiner.dart';`

## Usage

First you need to create two paths that need to convert and a boolean to control them.

Here is a minimalist example.

```dart
PathCombiner(
  duration: const Duration(seconds: 1),
  path: showStar ? starPath : circlePath,
  color: Theme.of(context).colorScheme.onPrimaryContainer,
)
```

Check [example](https://github.com/Dabbit-Chan/path_combiner/tree/main/example) for more.