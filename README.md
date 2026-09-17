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

## Convert IconData to Path

Import the library to use the asynchronous `IconData.toPath()` extension:

```dart
import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final homePath = await Icons.home.toPath(size: 200);
  final favoritePath = await Icons.favorite.toPath(size: 200);
  // Store the paths in your widget state, then pass the selected path
  // to PathCombiner. Avoid starting conversions inside build().
  runApp(MyApp(homePath: homePath, favoritePath: favoritePath));
}
```

`MyApp` above represents your own application widget. Material Icons require
`flutter: uses-material-design: true` in the application's `pubspec.yaml`.

- `size` (default `24`): proportionally fits and centers the visible outline in
  a square. This uses outline bounds, not the font's advance width or native
  `Icon` padding; the result is not a pixel-identical layout of an `Icon` widget.
- `offset` (default `Offset.zero`): the top-left of that square.
- `textDirection` (default `TextDirection.ltr`): mirrors icons marked with
  `matchTextDirection` when set to `TextDirection.rtl`.
- `fontAsset`: overrides automatic font lookup with an asset key.
- `fontData`: supplies raw `ByteData` instead, useful for fonts loaded using
  `FontLoader`. Do not pass both `fontAsset` and `fontData`.

Custom fonts declared in `pubspec.yaml` are resolved through `FontManifest.json`
using `IconData.fontFamily` and `fontPackage`:

```dart
const icon = IconData(0xe800, fontFamily: 'MyIcons');
final path = await icon.toPath(size: 120);

// Alternatively, select the font asset explicitly.
final explicitPath = await icon.toPath(
  size: 120,
  fontAsset: 'assets/fonts/my_icons.ttf',
);

// For a custom AssetBundle or explicit cache lifetime:
final converter = IconPathConverter(bundle: myAssetBundle);
final bundledPath = await converter.convert(icon, size: 120);
converter.clearCache();
```

The converter extracts actual vector outlines, including quadratic/cubic curves,
multiple contours, holes, and compound glyphs; it does not trace a bitmap.
Static TrueType `glyf` and non-CID OpenType CFF Type 2 fonts are supported,
with Unicode cmap formats 4 and 12. This includes Flutter's CFF Material Icons.
CFF2, CID-keyed CFF, CFF seac composites/arithmetic operators, variable fonts,
bitmap-only fonts and color-layer rendering are not supported. Missing fonts or
characters throw an error; blank glyphs produce an empty path. Font assets are
cached by each converter, and every call returns an independent `Path`.

The converter only sees the font bytes shipped in your app. Keep icon code
points statically declared as `const IconData`/`Icons.*` for release font
tree-shaking. If icons are selected dynamically and Flutter cannot determine
which glyphs to keep, build with `--no-tree-shake-icons`.
