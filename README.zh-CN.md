# Path Combiner

**为 Flutter 形状、图标和文字添加变形动画。**

[English](README.md) · 简体中文

**[在线试用 →](https://dabbit-chan.github.io/path_combiner/)**

将 `Path` 传给 `PathCombiner`，更新路径即可自动播放形状之间的过渡动画。

## 安装

```sh
flutter pub add path_combiner
```

```dart
import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';
```

## 基本用法

在组件的 `State` 中准备两条路径和一个切换状态：

```dart
final circle = Path()..addOval(const Rect.fromLTWH(20, 20, 160, 160));
final square = Path()..addRect(const Rect.fromLTWH(20, 20, 160, 160));
bool showSquare = false;
```

在 `build()` 中使用，点击形状即可切换：

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

需要描边效果时，使用 `PaintingStyle.stroke`，并通过 `strokeWidth` 调整线宽。
请为组件设置能容纳路径的尺寸，它不会自动缩放或居中路径。
切换时传入另一个 `Path` 实例，不要直接修改当前路径。

## PathCombiner 字段说明

| 字段 | 默认值 | 怎么用 |
| --- | --- | --- |
| `path` | 必填 | 传入目标 `Path`，通过 `setState()` 切换路径即可播放动画。 |
| `color` | 必填 | 设置填充或描边颜色，例如 `Colors.indigo`。 |
| `duration` | 必填 | 设置过渡时长，例如 `Duration(milliseconds: 700)`。 |
| `curve` | `Curves.linear` | 设置动画曲线，例如 `Curves.easeInOut`。 |
| `paintingStyle` | `PaintingStyle.stroke` | `PaintingStyle.fill` 为实心填充，`PaintingStyle.stroke` 为描边。 |
| `strokeWidth` | `5` | 设置描边宽度，单位为逻辑像素，仅描边模式使用。 |
| `strokeCap` | `StrokeCap.round` | 设置开放线条的端点样式：`butt` 平头、`round` 圆头、`square` 方头。 |
| `strokeJoin` | `StrokeJoin.round` | 设置描边转角样式：`miter` 尖角、`round` 圆角、`bevel` 斜角。 |
| `combineMethod` | `CombineMethod.space` | 选择变形方式，可选值见下表。 |
| `precision` | `1` | 设置采样间距，必须为有限正数。越小越精细，但开销越大，建议先用 `1`。 |
| `controller` | `null` | 可选，传入保存在 `State` 中的 `PathCombineController()`。通常省略，直接设置 `combineMethod` 即可；它不是控制播放的 `AnimationController`。 |
| `onEnd` | `null` | 动画结束时执行回调，例如 `() => debugPrint('完成')`。 |
| `key` | `null` | 可选的 Flutter 组件标识；保持稳定可保留当前动画状态。 |

`combineMethod` 决定两条路径采样点数量不同时，从哪里补齐点。
可以在在线示例中切换，选择更适合的变形效果：

| 可选值 | 效果 |
| --- | --- |
| `CombineMethod.start` | 在起点补齐。 |
| `CombineMethod.end` | 在终点补齐。 |
| `CombineMethod.center` | 在中间位置补齐。 |
| `CombineMethod.space` | 均匀分布补齐位置，默认方式。 |

## 图标动画

在应用的 `pubspec.yaml` 中启用 Material Icons：

```yaml
flutter:
  uses-material-design: true
```

在异步初始化流程中转换图标并保存结果：

```dart
WidgetsFlutterBinding.ensureInitialized();
final homePath = await Icons.home.toPath(size: 200);
final favoritePath = await Icons.favorite.toPath(size: 200);
```

和前面的形状示例一样，将转换结果传给 `PathCombiner.path` 即可。
不要在 `build()` 中发起转换。

自定义图标字体可以显式指定字体资源：

```dart
const icon = IconData(0xe800, fontFamily: 'MyIcons');
final iconPath = await icon.toPath(
  size: 200,
  fontAsset: 'assets/fonts/my_icons.ttf',
);
```

### IconData.toPath() 字段说明

| 字段 | 默认值 | 怎么用 |
| --- | --- | --- |
| `size` | `24` | 将图标等比缩放并居中放入该尺寸的正方形，须为有限正数。 |
| `offset` | `Offset.zero` | 设置正方形左上角的位置，例如 `Offset(20, 20)`。 |
| `textDirection` | `TextDirection.ltr` | 设为 `TextDirection.rtl` 时，镜像启用了 `matchTextDirection` 的图标。 |
| `fontAsset` | `null` | 显式指定已声明的字体资源路径。Material Icons 或已在 `fonts` 下声明的自定义字体通常可省略。 |
| `fontData` | `null` | 直接传入 `ByteData` 字体数据，替代资源路径；不能与 `fontAsset` 同时使用。 |

## 文字动画

将字体文件放入应用，并在 `pubspec.yaml` 中声明：

```yaml
flutter:
  assets:
    - assets/fonts/Roboto-Regular.ttf
```

在异步初始化流程中转换文字，保存路径后通过 `PathCombiner` 切换：

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

### String.toPath() 字段说明

| 字段 | 默认值 | 怎么用 |
| --- | --- | --- |
| `fontAsset` | `null` | 指定已在 `pubspec.yaml` 中声明的字体资源路径。 |
| `fontData` | `null` | 改用 `ByteData` 字体数据；与 `fontAsset` 必须且只能提供一个。 |
| `fontSize` | `48` | 设置字号，例如 `80`，须为有限正数。 |
| `letterSpacing` | `0` | 设置字符间距，单位为逻辑像素，例如 `2`。 |
| `lineHeight` | `1.2` | 设置行距倍数，实际行距为 `fontSize × lineHeight`，须为有限正数。 |
| `offset` | `Offset.zero` | 移动文字排版原点，例如 `Offset(20, 20)`；该位置不是首行基线。 |

请使用包含所需字符的受支持静态字体。转换中文时，需要提供含中文字形的字体，
示例自带的 Roboto 不包含中文。目前支持基础文字布局，不支持复杂文字塑形或自动字体回退。

## 更多示例

打开 **[在线示例](https://dabbit-chan.github.io/path_combiner/)** 体验动画，
也可以在 **Text → Path** 中尝试文字转换，或查看[示例代码](example)。

如需本地运行，从仓库根目录执行：

```sh
cd example
flutter pub get
flutter run -d chrome
```
