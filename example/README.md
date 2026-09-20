# Path Studio

一个可交互的轮廓动画实验台：暖白背景、深绿点阵预览、薄荷色轮廓，以及适配窄屏和桌面的控制面板。

## 运行

```sh
cd example
flutter pub get
flutter run
```

## 四个实验

- **Icon 变形**：起点和终点独立选择 Material / Cupertino 图标，可同字体或跨字体组合，默认 Material Home → Cupertino Star。
- **RTL 镜像**：选择 Back、Forward、Reply 或 Undo，同一图标在 LTR / RTL 之间切换。只有 `matchTextDirection` 为 true 的图标会镜像。
- **Text 变形**：输入两段文字，点击「生成文字轮廓」后往返播放。支持中文、中英混排、空格、换行及空白输入；编辑后提示重新生成，失败时显示错误并可修改重试。
- **多阶段循环**：编辑不限数量的阶段序列（至少 2 个），每个阶段独立选择 Icon 或 Text，默认 Icon → 中文 → Icon → 中文 → Icon，循环播放时按 0 → 1 → 2 → … → 0 回到起点，每段结束后停留约 450 ms。支持单步、跳转与暂停。

所有实验都支持 200–2000 ms 动画时长，以及 `start` / `end` / `center` / `space` 采样点补齐方式。折叠代码区展示当前选择对应的转换代码。

预览使用轮廓描边，不是实心 Icon。图标路径等比居中于 240 × 240 画布；图标组合按首次选择加载并缓存，失败可重试。图标预设有 48 个（Material 与 Cupertino 各 24），全部为静态常量。

文本内置 `assets/fonts/alimama_700.ttf`（阿里妈妈数黑体 Bold，静态 TTF，随站点部署，不依赖系统字体或第三方字体服务），中文、英文与数字共用同一套字形与基线。字库覆盖常用汉字（GB2312 范围），生僻字或 emoji 可能不在字库中，缺字会提示对应的 Unicode 编码；不提供复杂塑形、双向排版或 emoji 合成。两段文字按真实字宽排版、统一缩放并居中。空白文字与非空文字在动画中点直接切换。

## 代码结构

- `lib/main.dart`：工作台导航、图标选择、RTL、异步缓存与动画控制。
- `lib/path_examples.dart`：图标目录、共享文本转换与缩放工具、两组默认示例。
- `lib/text_path_example.dart`：可编辑文本、转换与预览；可独立使用或嵌入工作台。
- `lib/sequence_path_example.dart`：多阶段 Icon / Text 序列编辑、加载与循环播放。
- `lib/studio_widgets.dart`：共享面板、点阵画布、图标下拉选择、动画设置与代码区。

## 验证

```sh
flutter test
flutter analyze
```
