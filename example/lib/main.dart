import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

import 'path_examples.dart';
import 'studio_widgets.dart';
import 'text_path_example.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.examples = pathExamples});
  final List<PathExample> examples;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Path Studio',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F6F0),
          colorScheme: ColorScheme.fromSeed(seedColor: studioGreen, primary: studioGreen),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF5F7F3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        home: ExampleGallery(examples: examples),
      );
}

class ExampleGallery extends StatefulWidget {
  const ExampleGallery({super.key, required this.examples});
  final List<PathExample> examples;

  @override
  State<ExampleGallery> createState() => _ExampleGalleryState();
}

class _ExampleGalleryState extends State<ExampleGallery> {
  final _loaded = <String, Future<List<Path>>>{};
  int _selected = 0;
  IconChoice _start = iconChoices.first;
  IconChoice _end = iconChoices[6];
  IconChoice _directional = directionalChoices.first;
  bool _showEnd = false;
  bool _textMode = false;
  double _duration = 800;
  CombineMethod _method = CombineMethod.space;

  bool get _custom => !identical(widget.examples, pathExamples);
  bool get _rtl => _selected == 1;
  String get _cacheKey => _custom
      ? '$_selected'
      : _rtl
          ? 'rtl-${_directional.code}'
          : '${_start.code}-${_end.code}';
  String get _startLabel => _custom || _rtl
      ? widget.examples[_selected].startLabel
      : '${_start.family} · ${_start.label}';
  String get _endLabel =>
      _custom || _rtl ? widget.examples[_selected].endLabel : '${_end.family} · ${_end.label}';

  Future<List<Path>> _paths() => _loaded.putIfAbsent(_cacheKey, () async {
        final start = _start;
        final end = _end;
        final directional = _directional;
        if (_custom) return widget.examples[_selected].loadPaths();
        if (_rtl) {
          return [
            await directional.toPath(),
            await directional.toPath(direction: TextDirection.rtl),
          ];
        }
        return [await start.toPath(), await end.toPath()];
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.blur_on_rounded, color: studioGreen, size: 32),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'path / studio',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              color: studioInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var index = 0; index < widget.examples.length; index++)
                          ChoiceChip(
                            key: ValueKey('example-$index'),
                            label: Text('0${index + 1}  ${widget.examples[index].title}'),
                            selected: !_textMode && _selected == index,
                            onSelected: (_) => setState(() {
                              _selected = index;
                              _showEnd = false;
                              _textMode = false;
                            }),
                          ),
                        ChoiceChip(
                          key: const ValueKey('open-text-example'),
                          label: const Text('03  Text 变形'),
                          selected: _textMode,
                          onSelected: (_) => setState(() => _textMode = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (_textMode)
                      const TextPathExample(embedded: true)
                    else ...[
                      StudioHeading(
                        eyebrow: _rtl ? 'DIRECTION / 02' : 'ICON MORPH / 01',
                        title: _rtl ? '换个方向，重新看见。' : '不同轮廓，自然过渡。',
                        description: widget.examples[_selected].description,
                      ),
                      const SizedBox(height: 28),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final preview = _preview();
                          final controls = StudioPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!_custom) ...[
                                  Text(
                                    _rtl ? '选择方向性图标' : '自由组合',
                                    style:
                                        const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _rtl ? '一个 Icon，分别生成 LTR / RTL 路径。' : '起点和终点都可以独立选择图标。',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF697A73)),
                                  ),
                                  const SizedBox(height: 20),
                                  if (_rtl)
                                    _picker(
                                      'directional-icon',
                                      'DIRECTIONAL ICON',
                                      _directional,
                                      directionalChoices,
                                      (value) => _directional = value,
                                    )
                                  else ...[
                                    _picker(
                                      'start-icon',
                                      'START / 起始图标',
                                      _start,
                                      iconChoices,
                                      (value) => _start = value,
                                    ),
                                    const SizedBox(height: 16),
                                    _picker(
                                      'end-icon',
                                      'END / 目标图标',
                                      _end,
                                      iconChoices,
                                      (value) => _end = value,
                                    ),
                                  ],
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Divider(),
                                  ),
                                ],
                                MotionControls(
                                  duration: _duration,
                                  method: _method,
                                  onDurationChanged: (value) => setState(() => _duration = value),
                                  onMethodChanged: (value) => setState(() => _method = value),
                                ),
                              ],
                            ),
                          );
                          if (constraints.maxWidth < 800) {
                            return Column(
                              children: [preview, const SizedBox(height: 20), controls],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: preview),
                              const SizedBox(width: 24),
                              Expanded(flex: 2, child: controls),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      CodePanel(code: _code),
                    ],
                    const SizedBox(height: 28),
                    const Text(
                      'PATH COMBINER  /  轮廓之间，探索更多可能',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: Color(0xFF697A73)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _picker(
    String key,
    String label,
    IconChoice value,
    List<IconChoice> choices,
    ValueChanged<IconChoice> update,
  ) =>
      DropdownButtonFormField<IconChoice>(
        key: ValueKey(key),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final choice in choices)
            DropdownMenuItem(
              value: choice,
              child: Row(
                children: [
                  Icon(choice.icon, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${choice.family} · ${choice.label}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onChanged: (choice) {
          if (choice != null) {
            setState(() {
              update(choice);
              _showEnd = false;
            });
          }
        },
      );

  Widget _preview() => PreviewStage(
        child: FutureBuilder<List<Path>>(
          key: ValueKey(_cacheKey),
          future: _paths(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                children: [
                  const Text('字体加载失败'),
                  const SizedBox(height: 12),
                  Text('${snapshot.error}'),
                  TextButton(
                    onPressed: () => setState(() {
                      _loaded.remove(_cacheKey);
                    }),
                    child: const Text('重试'),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 360,
                child: Center(child: CircularProgressIndicator(color: studioMint)),
              );
            }
            return Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('LIVE PREVIEW', style: TextStyle(fontSize: 11, letterSpacing: 2)),
                ),
                const SizedBox(height: 20),
                Text(
                  _showEnd ? _endLabel : _startLabel,
                  key: const ValueKey('current-shape'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: '轮廓动画预览',
                  child: SizedBox(
                    height: 240,
                    child: FittedBox(
                      child: SizedBox.square(
                        dimension: exampleCanvasSize,
                        child: PathCombiner(
                          path: snapshot.data![_showEnd ? 1 : 0],
                          color: studioMint,
                          strokeWidth: 2,
                          duration: Duration(milliseconds: _duration.round()),
                          curve: Curves.easeInOutCubic,
                          combineMethod: _method,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('toggle-path'),
                  style: FilledButton.styleFrom(
                    backgroundColor: studioMint,
                    foregroundColor: studioInk,
                  ),
                  onPressed: () => setState(() => _showEnd = !_showEnd),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(_rtl ? '切换阅读方向' : '播放变形'),
                ),
                const SizedBox(height: 20),
                Text(
                  _rtl ? 'LTR / RTL  ·  matchTextDirection' : 'START / END  ·  点击往返播放',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF93B6A7)),
                ),
                const SizedBox(height: 12),
                Text(
                  _rtl ? '仅 matchTextDirection 为 true 的图标会镜像。' : '预览为字体轮廓描边，不是实心 Icon。',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF93B6A7)),
                ),
              ],
            );
          },
        ),
      );

  String get _code => _custom
      ? widget.examples[_selected].code
      : 'final start = await ${_rtl ? _directional.code : _start.code}.toPath(\n'
          '  size: 180, offset: const Offset(30, 30),\n'
          '${_rtl ? '  textDirection: TextDirection.ltr,\n' : ''}'
          ');\n'
          'final end = await ${_rtl ? _directional.code : _end.code}.toPath(\n'
          '  size: 180, offset: const Offset(30, 30),\n'
          '${_rtl ? '  textDirection: TextDirection.rtl,\n' : ''}'
          ');\n\n'
          'PathCombiner(\n  path: showEnd ? end : start,\n'
          '  color: const Color(0xFFCAEFDF),\n'
          '  duration: Duration(milliseconds: ${_duration.round()}),\n'
          '  combineMethod: CombineMethod.${_method.name},\n);';
}
