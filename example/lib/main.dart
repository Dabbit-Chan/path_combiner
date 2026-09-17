import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

import 'path_examples.dart';
import 'text_path_example.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.examples = pathExamples});

  final List<PathExample> examples;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Path Combiner Examples',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ExampleGallery(examples: examples),
    );
  }
}

class ExampleGallery extends StatefulWidget {
  const ExampleGallery({super.key, required this.examples});

  final List<PathExample> examples;

  @override
  State<ExampleGallery> createState() => _ExampleGalleryState();
}

class _ExampleGalleryState extends State<ExampleGallery> {
  final _loadedExamples = <int, Future<List<Path>>>{};
  int _selectedIndex = 0;
  bool _showEnd = false;
  double _durationMilliseconds = 800;
  CombineMethod _combineMethod = CombineMethod.space;
  late Future<List<Path>> _paths;

  PathExample get _example => widget.examples[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _loadSelectedExample();
  }

  void _loadSelectedExample() {
    _showEnd = false;
    _paths = _loadedExamples.putIfAbsent(
      _selectedIndex,
      () => Future<List<Path>>.sync(_example.loadPaths),
    );
  }

  void _selectExample(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      _loadSelectedExample();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Path Combiner Examples'),
        actions: [
          IconButton(
            key: const ValueKey('open-text-example'),
            tooltip: 'Text → Path',
            icon: const Icon(Icons.text_fields),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TextPathExample()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('IconData → Path',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('选择示例，观察字体轮廓如何转换并参与 Path 动画。'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var index = 0;
                          index < widget.examples.length;
                          index++)
                        ChoiceChip(
                          key: ValueKey('example-$index'),
                          label: Text(widget.examples[index].title),
                          selected: index == _selectedIndex,
                          onSelected: (_) => _selectExample(index),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(_example.description),
                  const SizedBox(height: 16),
                  Card(
                    color: colors.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FutureBuilder<List<Path>>(
                        future: _paths,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const SizedBox(
                              height: 300,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snapshot.hasError) {
                            return Column(
                              children: [
                                const Text('字体加载失败'),
                                const SizedBox(height: 8),
                                Text('${snapshot.error}'),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: () => setState(() {
                                    _loadedExamples.remove(_selectedIndex);
                                    _loadSelectedExample();
                                  }),
                                  child: const Text('重试'),
                                ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              Text(
                                _showEnd
                                    ? _example.endLabel
                                    : _example.startLabel,
                                key: const ValueKey('current-shape'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Semantics(
                                label: '轮廓动画预览',
                                child: SizedBox(
                                  height: exampleCanvasSize,
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: SizedBox.square(
                                      dimension: exampleCanvasSize,
                                      child: PathCombiner(
                                        key: ValueKey(_selectedIndex),
                                        path: snapshot.data![_showEnd ? 1 : 0],
                                        color: colors.onPrimaryContainer,
                                        strokeWidth: 2,
                                        duration: Duration(
                                          milliseconds:
                                              _durationMilliseconds.round(),
                                        ),
                                        curve: Curves.easeInOutCubic,
                                        combineMethod: _combineMethod,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                key: const ValueKey('toggle-path'),
                                onPressed: () => setState(() {
                                  _showEnd = !_showEnd;
                                }),
                                icon: const Icon(Icons.swap_horiz),
                                label: const Text('切换形状'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('动画时长：${_durationMilliseconds.round()} ms'),
                  Slider(
                    key: const ValueKey('duration-slider'),
                    value: _durationMilliseconds,
                    min: 200,
                    max: 2000,
                    divisions: 9,
                    label: '${_durationMilliseconds.round()} ms',
                    onChanged: (value) => setState(() {
                      _durationMilliseconds = value;
                    }),
                  ),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '采样点补齐方式',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CombineMethod>(
                        key: const ValueKey('combine-method'),
                        value: _combineMethod,
                        isExpanded: true,
                        items: [
                          for (final method in CombineMethod.values)
                            DropdownMenuItem(
                              value: method,
                              child: Text(method.name),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _combineMethod = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('转换代码', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      _example.code,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '字体仅在首次选择时读取，转换结果会缓存。'
                    '图标轮廓等比居中，预览使用描边而非 Icon 的填充效果。',
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
