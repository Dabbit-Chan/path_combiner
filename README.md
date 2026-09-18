# Path Combiner

**Animate between Flutter shapes, icons, and text.**

English · [简体中文](README.zh-CN.md)

**[Try the online demo →](https://dabbit-chan.github.io/path_combiner/)**

Pass a `Path` to `PathCombiner`, then change it to animate to the next shape.

## Install

```sh
flutter pub add path_combiner
```

```dart
import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';
```

## Basic usage

Create two paths and a toggle in your widget's `State`:

```dart
final circle = Path()..addOval(const Rect.fromLTWH(20, 20, 160, 160));
final square = Path()..addRect(const Rect.fromLTWH(20, 20, 160, 160));
bool showSquare = false;
```

Use this in `build()`. Tap the shape to switch:

```dart
GestureDetector(
  onTap: () => setState(() => showSquare = !showSquare),
  child: SizedBox.square(
    dimension: 200,
    child: PathCombiner(
      path: showSquare ? square : circle,
      color: Colors.indigo,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      paintingStyle: PaintingStyle.fill,
    ),
  ),
)
```

Use `PaintingStyle.stroke` and `strokeWidth` for an outlined shape.
Give the widget a size that fits your paths; it does not automatically scale or
center them. Switch to another `Path` instance instead of modifying the current one.

## PathCombiner options

| Field | Default | How to use it |
| --- | --- | --- |
| `path` | Required | Pass the target `Path`; switch paths with `setState()` to animate. |
| `color` | Required | Set the fill or stroke color, such as `Colors.indigo`. |
| `duration` | Required | Set the transition time, such as `Duration(milliseconds: 700)`. |
| `curve` | `Curves.linear` | Set the animation curve, such as `Curves.easeInOut`. |
| `paintingStyle` | `PaintingStyle.stroke` | Use `PaintingStyle.fill` for solid shapes or `PaintingStyle.stroke` for outlines. |
| `strokeWidth` | `5` | Set the outline width in logical pixels; used in stroke mode. |
| `strokeCap` | `StrokeCap.round` | Set open line endings: `butt`, `round`, or `square`. |
| `strokeJoin` | `StrokeJoin.round` | Set stroke corners: `miter`, `round`, or `bevel`. |
| `combineMethod` | `CombineMethod.space` | Choose a transition style from the options below. |
| `precision` | `1` | Set a finite positive sampling interval. Smaller values give finer detail but cost more; start with `1`. |
| `controller` | `null` | Optionally pass a `PathCombineController()` stored in your `State`. Usually omit it and set `combineMethod` directly; this is not an `AnimationController` for playback. |
| `onEnd` | `null` | Run a callback when the animation finishes, such as `() => debugPrint('Done')`. |
| `key` | `null` | Optional Flutter widget key. Keep it stable to preserve the current animation state. |

`combineMethod` controls where extra points are added when paths have different
sample counts. Try the options in the demo to choose the effect you prefer:

| Value | Behavior |
| --- | --- |
| `CombineMethod.start` | Repeat points at the start. |
| `CombineMethod.end` | Repeat points at the end. |
| `CombineMethod.center` | Repeat points around the middle. |
| `CombineMethod.space` | Distribute repeated points evenly; the default. |

## Animate icons

Enable Material Icons in your app's `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
```

Convert icons in an asynchronous initialization flow and save the results:

```dart
WidgetsFlutterBinding.ensureInitialized();
final homePath = await Icons.home.toPath(size: 200);
final favoritePath = await Icons.favorite.toPath(size: 200);
```

Pass either result to `PathCombiner.path`, just like the shapes above.
Do not start conversions inside `build()`.

For a custom icon font, specify its asset:

```dart
const icon = IconData(0xe800, fontFamily: 'MyIcons');
final iconPath = await icon.toPath(
  size: 200,
  fontAsset: 'assets/fonts/my_icons.ttf',
);
```

### IconData.toPath() options

| Field | Default | How to use it |
| --- | --- | --- |
| `size` | `24` | Fit and center the icon in a square of this size; use a finite positive value. |
| `offset` | `Offset.zero` | Position the square's top-left corner, such as `Offset(20, 20)`. |
| `textDirection` | `TextDirection.ltr` | Use `TextDirection.rtl` to mirror icons that enable `matchTextDirection`. |
| `fontAsset` | `null` | Override font lookup with a declared asset path. Omit it for Material Icons or custom fonts declared under `fonts`. |
| `fontData` | `null` | Pass font bytes as `ByteData` instead of an asset. Do not also supply `fontAsset`. |

## Animate text

Add a font file to your app and declare it in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/fonts/Roboto-Regular.ttf
```

Convert your strings in an asynchronous initialization flow, then save the paths
and switch between them with `PathCombiner`:

```dart
WidgetsFlutterBinding.ensureInitialized();
final helloPath = await 'Hello'.toPath(
  fontAsset: 'assets/fonts/Roboto-Regular.ttf',
  fontSize: 80,
);
final flutterPath = await 'Flutter'.toPath(
  fontAsset: 'assets/fonts/Roboto-Regular.ttf',
  fontSize: 80,
  letterSpacing: 2,
);
```

### String.toPath() options

| Field | Default | How to use it |
| --- | --- | --- |
| `fontAsset` | `null` | Set the font asset path declared in `pubspec.yaml`. |
| `fontData` | `null` | Supply font bytes as `ByteData` instead. Provide exactly one of `fontAsset` or `fontData`. |
| `fontSize` | `48` | Set the text size, such as `80`; use a finite positive value. |
| `letterSpacing` | `0` | Set spacing between characters in logical pixels, such as `2`. |
| `lineHeight` | `1.2` | Set line spacing as a multiplier of `fontSize`; use a finite positive value. |
| `offset` | `Offset.zero` | Move the text's layout origin, such as `Offset(20, 20)`; this is not the first baseline. |

Use a supported static font containing all your characters. For Chinese, provide
a font with Chinese glyphs; the example's Roboto does not include them. Basic
text layout is supported, but complex-script shaping and automatic font fallback
are not.

## Try more examples

Explore the **[online demo](https://dabbit-chan.github.io/path_combiner/)**,
including **Text → Path**, or browse the [example app](example).

To run it locally from the repository root:

```sh
cd example
flutter pub get
flutter run -d chrome
```
