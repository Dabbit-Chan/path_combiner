import 'package:flutter/material.dart';
import 'package:path_combiner/path_combiner.dart';

const studioInk = Color(0xFF192C29);
const studioGreen = Color(0xFF257864);
const studioMint = Color(0xFFCAEFDF);

class StudioPanel extends StatelessWidget {
  const StudioPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE1E7E2)),
        ),
        child: child,
      );
}

class StudioHeading extends StatelessWidget {
  const StudioHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
  });
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: studioGreen,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: studioInk,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(color: Color(0xFF697A73), height: 1.6)),
        ],
      );
}

class PreviewStage extends StatelessWidget {
  const PreviewStage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF213F38), Color(0xFF102722)],
          ),
        ),
        child: CustomPaint(
          painter: const _GridPainter(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DefaultTextStyle.merge(style: const TextStyle(color: studioMint), child: child),
          ),
        ),
      );
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x164FE3AC)
      ..strokeWidth = 1;
    for (var horizontal = 0.0; horizontal < size.width; horizontal += 28) {
      for (var vertical = 0.0; vertical < size.height; vertical += 28) {
        canvas.drawCircle(Offset(horizontal, vertical), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class MotionControls extends StatelessWidget {
  const MotionControls({
    super.key,
    required this.duration,
    required this.method,
    required this.onDurationChanged,
    required this.onMethodChanged,
  });
  final double duration;
  final CombineMethod method;
  final ValueChanged<double> onDurationChanged;
  final ValueChanged<CombineMethod> onMethodChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('动画设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Text(
            'DURATION  /  ${duration.round()} ms',
            style: const TextStyle(fontSize: 12, letterSpacing: 1),
          ),
          Slider(
            key: const ValueKey('duration-slider'),
            value: duration,
            min: 200,
            max: 2000,
            divisions: 9,
            label: '${duration.round()} ms',
            onChanged: onDurationChanged,
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: '采样点补齐方式'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CombineMethod>(
                key: const ValueKey('combine-method'),
                value: method,
                isExpanded: true,
                items: [
                  for (final option in CombineMethod.values)
                    DropdownMenuItem(value: option, child: Text(option.name)),
                ],
                onChanged: (value) {
                  if (value != null) onMethodChanged(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '相同的 Path，不同的运动方式。\n调整参数，再次切换即可体验。',
            style: TextStyle(fontSize: 12, color: Color(0xFF697A73), height: 1.7),
          ),
        ],
      );
}

class CodePanel extends StatelessWidget {
  const CodePanel({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => StudioPanel(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('查看实现代码', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('UNDER THE HOOD', style: TextStyle(fontSize: 10, letterSpacing: 2)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SelectableText(
                    code,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
