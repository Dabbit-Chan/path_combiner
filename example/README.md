# Path Combiner 示例

## 运行

在仓库根目录执行：

```sh
cd example
flutter pub get
flutter run
```

## 示例列表

| 示例 | 转换 | 展示内容 |
| --- | --- | --- |
| Material 图标 | `Icons.home` ↔ `Icons.favorite` | 内置字体轮廓转 Path |
| 菜单切换 | `Icons.menu` ↔ `Icons.close` | 不同轮廓数量的图标动画 |
| Cupertino 字体 | `CupertinoIcons.heart` ↔ `CupertinoIcons.star` | 自动解析 package 字体资源 |
| RTL 镜像 | `Icons.arrow_back` LTR ↔ RTL | `matchTextDirection` 与 `textDirection` |
| 几何路径 | 五角星 ↔ 圆形 | 原有手写 Path 动画 |

选择示例后，点击「切换形状」播放动画。可以调节动画时长（200–2000 ms）以及
`start` / `end` / `center` / `space` 四种采样点补齐方式。
页面底部展示当前示例对应的核心代码。

## 代码结构

- `lib/main.dart`：示例选择、异步加载/失败重试、动画控制和代码展示。
- `lib/path_examples.dart`：五组示例定义、字体转换调用与几何路径构造。

字体转换不会在 `build()` 中发起。每组示例首次选中时加载，并缓存得到的两个
`Path`；再次选择同组示例时复用结果，加载失败可以重试。

图标轮廓缩放到 180 × 180 的范围，并通过 `Offset(30, 30)` 居中放在
240 × 240 的画布内，为描边留出空间。实际显示的是轮廓描边，
不是 `Icon` 的实心填充效果，也不会保留字体原生留白。

本示例已经启用 `uses-material-design: true`，并使用现有的 `cupertino_icons`
依赖。所有图标均使用静态常量，保留正常的 release 图标字体裁剪流程。

## 验证

在 `example` 目录执行：

```sh
flutter test
flutter analyze
```
