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

With `PaintingStyle.fill` and two `PathFillType.nonZero` paths, unequal contour
counts are expanded to their least common multiple. Every contour on each side
is repeated equally, preserving the balance between outer boundaries and holes
while retaining one-to-many splitting and merging. Stroke mode keeps the original
contour alignment; all four sample-padding methods are unchanged. This is not a
topology-aware morph: intermediate contours may still overlap or self-intersect.
Balanced repetition does not apply to `evenOdd` or mixed fill rules.
For coprime contour counts the common count is their product, so complex paths
can require substantially more interpolation work than stroke mode. Matching
remains positional, not a semantic matching of glyphs or holes.

## Convert text to Path

Text conversion uses the built-in font parser, with no glyph_path dependency:

```dart
final first = await 'Hello'.toPath(
  fontAsset: 'assets/fonts/Roboto-Regular.ttf',
  fontSize: 80,
);
final second = await 'Flutter'.toPath(
  fontAsset: 'assets/fonts/Roboto-Regular.ttf',
  fontSize: 80,
  letterSpacing: 2,
);
```

Import `package:path_combiner/path_combiner.dart` and initialize Flutter's binding
before loading assets. Declare your font under `flutter: assets:` in your app's
pubspec, or pass `fontData: ByteData` instead. Exactly one font source is required;
the converter cannot extract the bytes of an arbitrary system/TextStyle font.
Package font assets use their full `packages/package_name/...` asset key.

- `fontSize` defaults to 48 and scales the font's em square. Characters keep
  their individual advance widths; they are not separately stretched to fit.
- `letterSpacing` defaults to 0, in logical pixels between code points.
- `lineHeight` defaults to 1.2; the baseline spacing is `fontSize * lineHeight`.
- `offset` defaults to zero and specifies the layout origin; the first baseline
  uses the font's ascender. Visible ink may extend beyond the layout origin.
- Spaces preserve their advance width, tabs expand to four spaces, and
  CRLF/CR normalize to LF. An empty/blank string produces an empty path.
- Fonts loaded from assets are cached. Use `TextPathConverter(bundle: bundle)`
  for custom bundles and `clearCache()` to release its font cache.

This is **basic left-to-right code-point layout**, not a replacement for
Flutter's text shaping engine: no kerning, ligatures, combining-mark positioning,
Arabic/Indic shaping, bidi reordering, automatic line wrapping or font fallback.
Chinese characters work when the supplied supported static font contains them;
the bundled example Roboto does not contain Chinese. Missing glyphs throw a
`StateError` identifying their Unicode code point, rather than substituting boxes.
The same static TrueType/CFF format limitations as icon conversion apply.

Pass the generated paths to `PathCombiner`. When either path has no contours,
the widget switches directly at the animation midpoint instead of trying to
interpolate an empty contour list. Non-empty text uses the existing contour
animation; it does not perform semantic letter-to-letter matching.

The example's top-right **Text → Path** button opens two editable String inputs.
Generate the paths, then toggle between them. The preview fits both strings
using one shared scale and centers their visible outlines.

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
