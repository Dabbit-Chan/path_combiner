import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

import 'studio_widgets.dart';

class TextPathExample extends StatefulWidget {
  const TextPathExample({super.key, this.embedded = false});

  final bool embedded;

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
  bool _dirty = false;
  String? _error;
  int _request = 0;
  int _revision = 0;
  double _duration = 800;
  CombineMethod _method = CombineMethod.space;
  PaintingStyle _paintingStyle = PaintingStyle.stroke;

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
        paths.add(
          await _converter.convert(
            text,
            fontAsset: 'assets/fonts/Roboto-Regular.ttf',
            fontSize: 80,
          ),
        );
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
        math.min(width == 0 ? 1.0 : 560 / width, height == 0 ? 1.0 : 200 / height),
      );
      final fitted = paths.map((path) {
        final center = path.getBounds().center;
        return path.transform(
          Float64List(16)
            ..[0] = scale
            ..[5] = scale
            ..[10] = 1
            ..[12] = _canvasSize.width / 2 - center.dx * scale
            ..[13] = _canvasSize.height / 2 - center.dy * scale
            ..[15] = 1,
        );
      }).toList();
      if (!mounted || request != _request) return;
      setState(() {
        _paths = fitted;
        _labels = labels;
        _showSecond = false;
        _loading = false;
        _revision++;
        _dirty = _first.text != labels[0] || _second.text != labels[1];
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
    final selected = _showSecond ? 1 : 0;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StudioHeading(
          eyebrow: 'TEXT MORPH / 03',
          title: '让文字，也有流动感。',
          description: '输入两段文字，把想法变成轮廓，再看它们缓缓变形。',
        ),
        const SizedBox(height: 28),
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('写下你的起点与终点', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final start = _input(_first, 'text-start', 'START / 起始文字');
                  final end = _input(_second, 'text-end', 'END / 目标文字');
                  if (constraints.maxWidth < 560) {
                    return Column(children: [start, const SizedBox(height: 12), end]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: start),
                      const SizedBox(width: 20),
                      Expanded(child: end),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('generate-text'),
                    onPressed: _loading ? null : _generate,
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: Text(_loading ? '正在生成…' : '生成文字轮廓'),
                  ),
                  Text(
                    _dirty ? '文字已修改，点击生成更新预览' : '支持英文、数字、符号与换行',
                    style: const TextStyle(color: Color(0xFF697A73), fontSize: 12),
                  ),
                ],
              ),
              if (_loading)
                const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    key: const ValueKey('text-error'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_paths != null) ...[
          PreviewStage(
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('LIVE TYPOGRAPHY', style: TextStyle(fontSize: 11, letterSpacing: 2)),
                ),
                const SizedBox(height: 20),
                Text(
                  _labels[selected].trim().isEmpty ? '（空白文本）' : _labels[selected],
                  key: const ValueKey('text-current'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: '文字轮廓动画预览',
                  child: AspectRatio(
                    aspectRatio: _canvasSize.aspectRatio,
                    child: FittedBox(
                      child: SizedBox.fromSize(
                        size: _canvasSize,
                        child: PathCombiner(
                          key: ValueKey('text-preview-$_revision'),
                          path: _paths![selected],
                          color: studioMint,
                          paintingStyle: _paintingStyle,
                          strokeWidth: 1.5,
                          precision: 1.5,
                          duration: Duration(milliseconds: _duration.round()),
                          combineMethod: _method,
                          curve: Curves.easeInOutCubic,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('toggle-text'),
                  style: FilledButton.styleFrom(
                    backgroundColor: studioMint,
                    foregroundColor: studioInk,
                  ),
                  onPressed: _loading ? null : () => setState(() => _showSecond = !_showSecond),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('切换文字'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'STRING  →  PATH  →  MOTION',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, letterSpacing: 2, color: Color(0xFF93B6A7)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          StudioPanel(
            child: MotionControls(
              duration: _duration,
              method: _method,
              paintingStyle: _paintingStyle,
              onDurationChanged: (value) => setState(() => _duration = value),
              onMethodChanged: (value) => setState(() => _method = value),
              onPaintingStyleChanged: (value) => setState(() {
                _paintingStyle = value;
              }),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('关于字体与排版', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 10),
              Text(
                '内置 Roboto，支持英文、数字及常见符号，不含中文字形。'
                '中文需换用包含中文的静态 TTF / OTF 字体。\n'
                '两段文本按真实字宽排版、统一缩放并居中；支持换行，不提供复杂文字塑形、双向排版或 emoji 合成。'
                '空白文本没有轮廓，与非空文本在动画中点直接切换。',
                style: TextStyle(fontSize: 12, height: 1.8, color: Color(0xFF697A73)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        CodePanel(code: _code),
      ],
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Text / Studio')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController controller, String key, String label) => TextField(
        key: ValueKey(key),
        controller: controller,
        minLines: 1,
        maxLines: 3,
        maxLength: 40,
        onChanged: (_) => setState(() => _dirty = true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );

  String get _code {
    final labels = _labels.isEmpty ? ['Hello', 'Flutter'] : _labels;
    String literal(String value) => jsonEncode(value).replaceAll(r'$', r'\$');
    return 'final start = await ${literal(labels[0])}.toPath(\n'
        "  fontAsset: 'assets/fonts/Roboto-Regular.ttf',\n"
        '  fontSize: 80,\n);\n'
        'final end = await ${literal(labels[1])}.toPath(\n'
        "  fontAsset: 'assets/fonts/Roboto-Regular.ttf',\n"
        '  fontSize: 80,\n);\n\n'
        '// 预览中另将两条路径统一缩放，并平移至画布中心。\n\n'
        'PathCombiner(\n'
        '  path: showSecond ? end : start,\n'
        '  color: const Color(0xFFCAEFDF),\n'
        '  paintingStyle: PaintingStyle.${_paintingStyle.name},\n'
        '  duration: const Duration(milliseconds: 800),\n'
        ');';
  }
}
