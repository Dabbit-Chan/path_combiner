import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

class TextPathExample extends StatefulWidget {
  const TextPathExample({super.key});

  @override
  State<TextPathExample> createState() => _TextPathExampleState();
}

class _TextPathExampleState extends State<TextPathExample> {
  static const _canvasSize = Size(600, 240);
  final _first = TextEditingController(text: 'Hello');
  final _second = TextEditingController(text: 'Flutter');
  final _converter = TextPathConverter();
  List<Path>? _paths;
  List<String> _labels = [];
  bool _showSecond = false;
  bool _loading = false;
  String? _error;
  int _request = 0;
  int _revision = 0;
  double _duration = 800;
  CombineMethod _method = CombineMethod.space;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _request++;
    _first.dispose();
    _second.dispose();
    _converter.clearCache();
    super.dispose();
  }

  Future<void> _generate() async {
    final request = ++_request;
    final labels = [_first.text, _second.text];
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final paths = <Path>[];
      for (final text in labels) {
        paths.add(await _converter.convert(
          text,
          fontAsset: 'assets/fonts/Roboto-Regular.ttf',
          fontSize: 80,
        ));
      }
      var width = 0.0;
      var height = 0.0;
      for (final path in paths) {
        final bounds = path.getBounds();
        width = math.max(width, bounds.width);
        height = math.max(height, bounds.height);
      }
      final scale = math.min(
        1.0,
        math.min(
            width == 0 ? 1.0 : 560 / width, height == 0 ? 1.0 : 200 / height),
      );
      final fitted = paths.map((path) {
        final center = path.getBounds().center;
        return path.transform(Float64List(16)
          ..[0] = scale
          ..[5] = scale
          ..[10] = 1
          ..[12] = _canvasSize.width / 2 - center.dx * scale
          ..[13] = _canvasSize.height / 2 - center.dy * scale
          ..[15] = 1);
      }).toList();
      if (!mounted || request != _request) return;
      setState(() {
        _paths = fitted;
        _labels = labels;
        _showSecond = false;
        _loading = false;
        _revision++;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = '转换失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = _showSecond ? 1 : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Text → Path')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('输入两段文字，生成轮廓后切换播放动画。'),
                  const SizedBox(height: 12),
                  const Text(
                    '示例内置 Roboto：适合英文、数字和常见符号，不含中文字形。'
                    '中文需在项目中换用包含中文的静态 TTF/OTF 字体。'
                    '支持换行；不进行阿拉伯文塑形、双向排版或 emoji 合成。',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('text-start'),
                    controller: _first,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: '起始 String',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('text-end'),
                    controller: _second,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: '目标 String',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('generate-text'),
                    onPressed: _loading ? null : _generate,
                    icon: const Icon(Icons.draw),
                    label: Text(_loading ? '正在生成…' : '生成两条 Path'),
                  ),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          key: const ValueKey('text-error'),
                          style: TextStyle(color: colors.error)),
                    ),
                  const SizedBox(height: 16),
                  if (_paths != null) ...[
                    Card(
                      color: colors.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              _labels[selected].trim().isEmpty
                                  ? '（空白文本）'
                                  : _labels[selected],
                              key: const ValueKey('text-current'),
                            ),
                            const SizedBox(height: 12),
                            AspectRatio(
                              aspectRatio: _canvasSize.aspectRatio,
                              child: FittedBox(
                                child: SizedBox.fromSize(
                                  size: _canvasSize,
                                  child: PathCombiner(
                                    key: ValueKey('text-preview-$_revision'),
                                    path: _paths![selected],
                                    color: colors.onPrimaryContainer,
                                    strokeWidth: 1.5,
                                    precision: 1.5,
                                    duration: Duration(
                                        milliseconds: _duration.round()),
                                    combineMethod: _method,
                                    curve: Curves.easeInOutCubic,
                                  ),
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              key: const ValueKey('toggle-text'),
                              onPressed: _loading
                                  ? null
                                  : () => setState(() {
                                        _showSecond = !_showSecond;
                                      }),
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('切换文字'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text('动画时长：${_duration.round()} ms'),
                    Slider(
                      value: _duration,
                      min: 200,
                      max: 2000,
                      divisions: 9,
                      onChanged: (value) => setState(() => _duration = value),
                    ),
                    DropdownButton<CombineMethod>(
                      value: _method,
                      isExpanded: true,
                      items: [
                        for (final method in CombineMethod.values)
                          DropdownMenuItem(
                              value: method, child: Text(method.name)),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _method = value);
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('先按真实字宽排版，再使用相同比例缩小两段文本并居中。'
                      '编辑后需重新生成。空白文本没有轮廓，与非空文本在动画中点直接切换。'),
                  const SizedBox(height: 12),
                  const SelectableText(
                    "final first = await 'Hello'.toPath(\n"
                    "  fontAsset: 'assets/fonts/Roboto-Regular.ttf',\n"
                    "  fontSize: 80,\n"
                    ");\n"
                    "final second = await 'Flutter'.toPath(\n"
                    "  fontAsset: 'assets/fonts/Roboto-Regular.ttf',\n"
                    "  fontSize: 80,\n"
                    ");",
                    style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
