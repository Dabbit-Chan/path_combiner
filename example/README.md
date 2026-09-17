# Path Combiner 示例

## 运行

在仓库根目录执行：

```sh
cd example
flutter pub get
flutter run
```

## 示例列表

右上角文字按钮可打开 **Text → Path** 页面：输入起始和目标两个 String，
点击「生成两条 Path」，再点击「切换文字」播放动画。支持空格、换行、
动画时长与组合方式调节；修改输入后需要重新生成。

文本示例直接使用自研解析器，不依赖 glyph_path。使用随项目附带的完整
`assets/fonts/Roboto-Regular.ttf`，许可见同目录 `Roboto_LICENSE.txt`。
该字体支持英文、数字及常见符号，不含中文；中文需要自行替换为包含中文的
静态 TTF/OTF 字体。缺字会显示 Unicode 错误提示。此功能不提供复杂塑形、
双向排版、连字或 emoji 合成。空白文字没有轮廓，动画中点直接切换。

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
- `lib/text_path_example.dart`：双字符串输入、文本转换、统一缩放及动画预览。

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
