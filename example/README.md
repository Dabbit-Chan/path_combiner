# Path Studio

一个可交互的轮廓动画实验台：暖白背景、深绿点阵预览、薄荷色轮廓，以及适配窄屏和桌面的控制面板。

## 运行

```sh
cd example
flutter pub get
flutter run
```

## 三个实验

- **Icon 变形**：起点和终点独立选择 Material / Cupertino 图标，可同字体或跨字体组合，默认 Material Home → Cupertino Star。
- **RTL 镜像**：选择 Back、Forward、Reply 或 Undo，同一图标在 LTR / RTL 之间切换。只有 `matchTextDirection` 为 true 的图标会镜像。
- **Text 变形**：输入两段文字，点击「生成文字轮廓」后往返播放。支持空格、换行及空白输入；编辑后提示重新生成，失败时显示错误并可修改重试。

所有实验都支持 200–2000 ms 动画时长，以及 `start` / `end` / `center` / `space` 采样点补齐方式。折叠代码区展示当前选择对应的转换代码。

预览使用轮廓描边，不是实心 Icon。图标路径等比居中于 240 × 240 画布；图标组合按首次选择加载并缓存，失败可重试。所有图标引用均为静态常量。

文本使用内置 `assets/fonts/Roboto-Regular.ttf`，支持英文、数字及常见符号，不含中文。中文需要换用包含中文字形的静态 TTF / OTF 字体；不提供复杂塑形、双向排版或 emoji 合成。两段文字按真实字宽排版、统一缩放并居中。空白文字与非空文字在动画中点直接切换。

## 代码结构

- `lib/main.dart`：工作台导航、图标选择、RTL、异步缓存与动画控制。
- `lib/path_examples.dart`：静态图标目录与两组默认示例。
- `lib/text_path_example.dart`：可编辑文本、转换与预览；可独立使用或嵌入工作台。
- `lib/studio_widgets.dart`：共享面板、点阵画布、动画设置与代码区。

## 验证

```sh
flutter test
flutter analyze
```
