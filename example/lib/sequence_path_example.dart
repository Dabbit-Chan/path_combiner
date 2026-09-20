import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

import 'path_examples.dart';
import 'studio_widgets.dart';

class SequenceStep {
  const SequenceStep.icon(this.icon) : text = null;
  const SequenceStep.text(this.text) : icon = null;

  final IconChoice? icon;
  final String? text;

  String get label =>
      icon == null ? (text!.trim().isEmpty ? '（空白文本）' : text!) : '${icon!.family} · ${icon!.label}';
}

Future<List<Path>> loadSequencePaths(List<SequenceStep> steps) async {
  final paths = <Path>[];
  for (var index = 0; index < steps.length; index++) {
    final step = steps[index];
    try {
      paths.add(
        step.icon == null
            ? await convertExampleText(step.text!, fontSize: 120)
            : await step.icon!.toPath(),
      );
    } catch (error) {
      throw StateError('阶段 $index（${step.label}）转换失败：$error');
    }
  }
  // 各阶段独立缩小并居中，长文字不会把其他图标一起缩得过小。
  return fitExamplePaths(paths, uniformScale: false);
}

class SequencePathExample extends StatefulWidget {
  const SequencePathExample({super.key, this.loadPaths = loadSequencePaths});

  final Future<List<Path>> Function(List<SequenceStep>) loadPaths;

  @override
  State<SequencePathExample> createState() => _SequencePathExampleState();
}

class _Draft {
  _Draft(this.id, {required this.icon, String? text})
      : isText = text != null,
        controller = TextEditingController(text: text ?? '你好');

  final int id;
  IconChoice icon;
  bool isText;
  final TextEditingController controller;

  SequenceStep get snapshot =>
      isText ? SequenceStep.text(controller.text) : SequenceStep.icon(icon);
}

class _SequencePathExampleState extends State<SequencePathExample> {
  final _drafts = [
    _Draft(0, icon: iconChoices[0]),
    _Draft(1, icon: iconChoices[0], text: '你好'),
    _Draft(2, icon: iconChoices[5]),
    _Draft(3, icon: iconChoices[0], text: '世界'),
    _Draft(4, icon: iconChoices[6]),
  ];
  int _nextId = 5;
  List<SequenceStep> _steps = [];
  List<Path>? _paths;
  int _index = 0;
  int _request = 0;
  int _revision = 0;
  int _editRevision = 0;
  int _loadedEditRevision = -1;
  bool _loading = false;
  bool _playing = false;
  bool _animating = false;
  Timer? _hold;
  String? _error;
  double _duration = 1000;
  CombineMethod _method = CombineMethod.space;
  PaintingStyle _paintingStyle = PaintingStyle.stroke;

  bool get _dirty => _editRevision != _loadedEditRevision;
  bool get _ready => _paths != null && !_loading && !_dirty;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _request++;
    _hold?.cancel();
    for (final draft in _drafts) {
      draft.controller.dispose();
    }
    super.dispose();
  }

  void _stop() {
    _hold?.cancel();
    _playing = false;
  }

  void _edit(VoidCallback change) => setState(() {
        _stop();
        change();
        _editRevision++;
      });

  Future<void> _generate() async {
    final request = ++_request;
    final editRevision = _editRevision;
    final steps = _drafts.map((draft) => draft.snapshot).toList();
    setState(() {
      _stop();
      _loading = true;
      _error = null;
    });
    try {
      final paths = await widget.loadPaths(steps);
      if (!mounted || request != _request) return;
      if (paths.length != steps.length) throw StateError('阶段数与路径数不一致');
      setState(() {
        _paths = paths;
        _steps = steps;
        _index = 0;
        _animating = false;
        _loading = false;
        _loadedEditRevision = editRevision;
        _revision++;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _goTo(int index) {
    _hold?.cancel();
    if (!_ready || index == _index) return;
    setState(() {
      _index = index;
      _animating = true;
    });
  }

  void _next() => _goTo((_index + 1) % _steps.length);

  void _togglePlayback() {
    setState(() {
      if (_playing) {
        _stop();
      } else {
        _playing = true;
      }
    });
    if (_playing && !_animating) _next();
  }

  void _onEnd() {
    _animating = false;
    _hold?.cancel();
    // 动画真正结束后才安排下一段，后台标签页恢复时也不会跳过阶段。
    if (_playing && _ready) {
      _hold = Timer(const Duration(milliseconds: 450), () {
        if (mounted && _playing && _ready) _next();
      });
    }
  }

  void _manualStep(int index) {
    setState(_stop);
    _goTo(index);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StudioHeading(
            eyebrow: 'SEQUENCE / 04',
            title: '不止两端，串起每一种可能。',
            description: 'Icon → Text → Icon → Text，自由组合多个阶段，最后回到起点。',
          ),
          const SizedBox(height: 24),
          _preview(),
          const SizedBox(height: 20),
          StudioPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '编辑序列 · ${_drafts.length} 个阶段',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('每一阶段独立选择 Icon 或 Text，数量不限（至少 2 个）；'
                    '可选 ${iconChoices.length} 个图标，支持中文、中英混排和换行。'),
                const SizedBox(height: 16),
                for (var index = 0; index < _drafts.length; index++) _editor(index),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('sequence-add-icon'),
                      onPressed: () =>
                          _edit(() => _drafts.add(_Draft(_nextId++, icon: iconChoices[6]))),
                      icon: const Icon(Icons.add),
                      label: const Text('添加 Icon'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('sequence-add-text'),
                      onPressed: () => _edit(
                        () => _drafts.add(_Draft(_nextId++, icon: iconChoices[0], text: '你好')),
                      ),
                      icon: const Icon(Icons.text_fields),
                      label: const Text('添加 Text'),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('generate-sequence'),
                      onPressed: _loading ? null : _generate,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: Text(_loading ? '正在生成…' : '生成序列'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _dirty ? '序列已修改，请生成后播放。' : '轮廓已就绪，点击上方播放。',
                  key: const ValueKey('sequence-status'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF697A73)),
                ),
                const SizedBox(height: 8),
                const Text(
                  '中英文统一使用随站点部署的阿里妈妈数黑体（Bold）静态字体。'
                  '字库覆盖常用汉字，生僻字或 emoji 可能缺字；空白文本在动画中点切换。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF697A73)),
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
              onPaintingStyleChanged: (value) => setState(() => _paintingStyle = value),
            ),
          ),
          const SizedBox(height: 20),
          CodePanel(code: _code),
        ],
      );

  Widget _editor(int index) {
    final draft = _drafts[index];
    return Padding(
      key: ValueKey('sequence-editor-${draft.id}'),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$index', style: const TextStyle(fontWeight: FontWeight.w800)),
              ChoiceChip(
                key: ValueKey('sequence-type-icon-${draft.id}'),
                label: const Text('Icon'),
                selected: !draft.isText,
                onSelected: (_) => _edit(() => draft.isText = false),
              ),
              ChoiceChip(
                key: ValueKey('sequence-type-text-${draft.id}'),
                label: const Text('Text'),
                selected: draft.isText,
                onSelected: (_) => _edit(() => draft.isText = true),
              ),
              IconButton(
                key: ValueKey('sequence-up-${draft.id}'),
                tooltip: '前移',
                onPressed: index == 0
                    ? null
                    : () => _edit(() {
                          _drafts.removeAt(index);
                          _drafts.insert(index - 1, draft);
                        }),
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                key: ValueKey('sequence-down-${draft.id}'),
                tooltip: '后移',
                onPressed: index == _drafts.length - 1
                    ? null
                    : () => _edit(() {
                          _drafts.removeAt(index);
                          _drafts.insert(index + 1, draft);
                        }),
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
              IconButton(
                key: ValueKey('sequence-remove-${draft.id}'),
                tooltip: '减少一个阶段',
                onPressed: _drafts.length <= 2
                    ? null
                    : () => _edit(() {
                          _drafts.removeAt(index);
                          draft.controller.dispose();
                        }),
                icon: const Icon(Icons.remove_circle_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (draft.isText)
            TextField(
              key: ValueKey('sequence-text-${draft.id}'),
              controller: draft.controller,
              minLines: 1,
              maxLines: 3,
              maxLength: 20,
              decoration: InputDecoration(labelText: '阶段 $index / 文字'),
              onChanged: (_) => _edit(() {}),
            )
          else
            IconChoicePicker(
              key: ValueKey('sequence-icon-${draft.id}'),
              value: draft.icon,
              label: '阶段 $index / 图标',
              onChanged: (value) => _edit(() => draft.icon = value),
            ),
        ],
      ),
    );
  }

  Widget _preview() => PreviewStage(
        child: Column(
          children: [
            const Text('LOOP / 每段结束后停留 450 ms', style: TextStyle(fontSize: 11, letterSpacing: 1)),
            if (_loading) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(color: studioMint),
              const Text('正在加载字体并生成路径…'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const ValueKey('sequence-error')),
              TextButton(onPressed: _loading ? null : _generate, child: const Text('重试')),
            ],
            if (_paths != null) ...[
              const SizedBox(height: 20),
              Text(
                '$_index / ${_steps.length - 1} · ${_steps[_index].label}',
                key: const ValueKey('sequence-current'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Semantics(
                label: '多阶段轮廓动画预览',
                child: AspectRatio(
                  aspectRatio: textCanvasSize.aspectRatio,
                  child: FittedBox(
                    child: SizedBox.fromSize(
                      size: textCanvasSize,
                      child: PathCombiner(
                        key: ValueKey('sequence-preview-$_revision'),
                        path: _paths![_index],
                        color: studioMint,
                        paintingStyle: _paintingStyle,
                        strokeWidth: 1.5,
                        precision: 2,
                        duration: Duration(milliseconds: _duration.round()),
                        curve: Curves.easeInOutCubic,
                        combineMethod: _method,
                        onEnd: _onEnd,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < _steps.length; index++)
                    Tooltip(
                      message: _steps[index].label,
                      child: ChoiceChip(
                        key: ValueKey('sequence-step-$index'),
                        selected: index == _index,
                        label: Text('$index · ${_steps[index].icon == null ? 'Text' : 'Icon'}'),
                        onSelected: _ready ? (_) => _manualStep(index) : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('sequence-play'),
                    style: FilledButton.styleFrom(
                      backgroundColor: studioMint,
                      foregroundColor: studioInk,
                    ),
                    onPressed: _ready ? _togglePlayback : null,
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    label: Text(_playing ? '暂停连播' : '循环播放'),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey('sequence-next'),
                    onPressed: _ready ? () => _manualStep((_index + 1) % _steps.length) : null,
                    child: const Text('下一阶段'),
                  ),
                  FilledButton.tonal(
                    key: const ValueKey('sequence-reset'),
                    onPressed: _ready ? () => _manualStep(0) : null,
                    child: const Text('回到起点'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _orderLabel,
                key: const ValueKey('sequence-order'),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );

  // 阶段很多时省略中间序号，避免预览底部文本过长。
  String get _orderLabel {
    final count = _steps.length;
    final flow = count <= 8
        ? List.generate(count, (index) => index).join(' → ')
        : '0 → 1 → … → ${count - 1}';
    return '$flow → 0 → …';
  }

  String get _code {
    String literal(String value) => jsonEncode(value).replaceAll(r'$', r'\$');
    final steps = _steps.isEmpty ? _drafts.map((draft) => draft.snapshot) : _steps;
    final sources = steps.map(
      (step) => step.icon != null
          ? '  await ${step.icon!.code}.toPath(size: 180),'
          : '  await ${literal(step.text!)}.toPath(\n'
              "    fontAsset: '$baseFontAsset', fontSize: 120),",
    );
    return '// 在 State 中预先加载并缓存所有路径，统一居中后再播放。\n'
        'final paths = [\n${sources.join('\n')}\n];\n'
        'var index = 0;\n\n'
        'void next() => setState(() {\n'
        '  index = (index + 1) % paths.length;\n'
        '});\n\n'
        'PathCombiner(\n'
        '  path: paths[index],\n'
        '  color: const Color(0xFFCAEFDF),\n'
        '  duration: Duration(milliseconds: ${_duration.round()}),\n'
        '  paintingStyle: PaintingStyle.${_paintingStyle.name},\n'
        '  combineMethod: CombineMethod.${_method.name},\n'
        '  onEnd: onEnd,\n'
        ');\n\n'
        '// onEnd 中按需安排下一步：\n'
        '// if (playing) hold = Timer(const Duration(milliseconds: 450), next);\n'
        '// 暂停、编辑、重新生成和 dispose 时取消 hold。';
  }
}
