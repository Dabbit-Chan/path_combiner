import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// 两侧元素数量不同时，在较短的一侧复制哪些元素来补齐。
enum CombineMethod {
  /// 在开头重复第一个元素。
  start,

  /// 在末尾重复最后一个元素。
  end,

  /// 在中间重复中央元素。
  center,

  /// 按相对位置均匀分配重复元素。
  space,
}

/// 保存可在动画运行期间调整的采样点补齐配置。
class PathCombineController {
  /// 影响轮廓内部的点对应关系；轮廓数量的配对另行处理。
  CombineMethod combineMethod = CombineMethod.space;
}

/// 缓存与进度无关的预处理结果，再按动画进度插值。
///
/// 数据流：prepare → PathUtil._prepare → _PreparedPaths → 每帧 lerp。
/// 缓存属于当前 Tween，不跨组件共享；更换输入后替换旧缓存。
class PathTween extends Tween<Path?> {
  PathTween({
    super.begin,
    required this.precision,
    required this.controller,
    this.paintingStyle = PaintingStyle.stroke,
  });

  /// 沿轮廓弧长采样的步长，不是采样点数量；越小，点越密。
  double precision;

  /// 每次检查缓存时读取其 combineMethod，支持运行期间修改。
  PathCombineController controller;

  /// fill 和 stroke 使用不同的轮廓数量补齐策略。
  PaintingStyle paintingStyle;

  /// 已配对、已采样、已补齐点数的轮廓，后续帧直接复用。
  _PreparedPaths? _prepared;

  /// 上一次成功预处理的输入快照；不包含每帧变化的 t。
  Object? _preparedKey;

  /// 计算当前帧；端点直接返回原路径，避免采样近似影响最终形状。
  @override
  Path? lerp(double t) {
    // 将继承自 Tween 的可变端点保存为本次调用的局部引用。
    final source = begin;
    final target = end;
    if (identical(source, target) || target == null) return source;
    if (source == null) return target;
    if (t == 0) return source;
    if (t == 1) return target;
    // 每帧只做一次轻量缓存检查；缓存未命中时才执行预处理。
    _ensurePrepared();
    return _prepared!.lerp(source, target, t);
  }

  /// 确保当前起终点和配置对应的预处理结果已经缓存。
  ///
  /// Path 的几何内容没有版本号，因此不能检测对同一对象的原地修改。
  /// 修改形状时应传入新的 Path；fillType 则单独记录在缓存键中。
  void _ensurePrepared() {
    final source = begin;
    final target = end;
    if (source == null || target == null || identical(source, target)) {
      _prepared = null;
      _preparedKey = null;
      return;
    }
    // 比较路径引用及所有影响点对应关系的配置，而不是 controller 的身份。
    // 即使 controller 对象没变，只要其补齐方式变了，也会重新准备。
    final key = (
      source,
      target,
      source.fillType,
      target.fillType,
      precision,
      controller.combineMethod,
      paintingStyle
    );
    if (_preparedKey == key) return;
    _prepared =
        PathUtil._prepare(source, target, precision, controller.combineMethod, paintingStyle);
    // 预处理成功后才更新键，失败时不会把旧数据误认为新输入的缓存。
    _preparedKey = key;
  }
}

/// 一对轮廓的插值模板：两组点已经等长，且同下标的点互相对应。
class _PreparedContour {
  _PreparedContour(this.begin, this.end, this.closed);

  /// 起始轮廓的点；准备完成后只读，不能被后续帧改写。
  final List<Offset> begin;

  /// 目标轮廓的点，与 begin 一一对应。
  final List<Offset> end;

  /// 仅当两侧原轮廓都闭合时，插值轮廓才显式闭合。
  final bool closed;

  /// 每帧只插值对应点并追加多边形，不再进行采样或补齐。
  void addTo(Path result, double progress) {
    result.addPolygon(
      List.generate(begin.length, (index) => Offset.lerp(begin[index], end[index], progress)!),
      closed,
    );
  }
}

/// 整对 Path 的预处理结果，包含本次变形需要绘制的所有轮廓模板。
class _PreparedPaths {
  _PreparedPaths(this.contours);

  /// 保留展开后的顺序和重复次数；相同配对可引用同一个模板。
  final List<_PreparedContour> contours;

  /// 用模板构建一帧新路径，不修改缓存或原始路径。
  Path lerp(Path begin, Path end, double progress) {
    // 任意一侧没有有效轮廓时，沿用中点直接切换的行为。
    if (contours.isEmpty) return progress < 0.5 ? begin : end;
    // 相同填充规则全程保留；不同规则在动画中点切换。
    final result = Path()..fillType = progress < 0.5 ? begin.fillType : end.fillType;
    for (final contour in contours) {
      contour.addTo(result, progress);
    }
    return result;
  }
}

/// 轮廓预处理和一次性插值工具；跨帧缓存由 PathTween 管理。
class PathUtil {
  /// 无状态的一次性插值入口，每次调用都会重新准备。
  /// 连续动画通过 PathTween 复用缓存，不逐帧调用这个入口。
  static Path? lerpPath(
    Path? begin,
    Path? end,
    double t,
    double precision,
    PathCombineController controller, {
    PaintingStyle paintingStyle = PaintingStyle.stroke,
  }) {
    if (identical(begin, end)) {
      return begin;
    }
    if (begin == null) {
      return end;
    }
    if (end == null) {
      return begin;
    }
    if (t == 0) {
      return begin;
    }
    if (t == 1) {
      return end;
    }

    return _prepare(begin, end, precision, controller.combineMethod, paintingStyle)
        .lerp(begin, end, t);
  }

  /// 执行与 t 无关的工作：计算轮廓 → 对齐数量 → 采样 → 补齐点数。
  static _PreparedPaths _prepare(
    Path begin,
    Path end,
    double precision,
    CombineMethod combineMethod,
    PaintingStyle paintingStyle,
  ) {
    if (!precision.isFinite || precision <= 0) {
      throw ArgumentError.value(precision, 'precision', 'Must be finite and positive');
    }
    // PathMetric 表示一条子轮廓，提供长度、闭合状态和沿弧长取点的能力。
    // 零长度轮廓无法有效采样，因此两侧都先过滤。
    List<ui.PathMetric> beginMetrics =
        begin.computeMetrics().where((metric) => metric.length > 0).toList();
    List<ui.PathMetric> endMetrics =
        end.computeMetrics().where((metric) => metric.length > 0).toList();

    if (beginMetrics.isEmpty || endMetrics.isEmpty) {
      return _PreparedPaths([]);
    }

    if (beginMetrics.length != endMetrics.length) {
      if (paintingStyle == PaintingStyle.fill &&
          begin.fillType == PathFillType.nonZero &&
          end.fillType == PathFillType.nonZero) {
        // 取最小公倍数，让同一侧的每条轮廓被重复相同次数。
        // 例如 3 → 2 展开为 6 → 6，避免只多复制内/外轮廓之一而破坏镂空。
        final commonCount =
            beginMetrics.length ~/ beginMetrics.length.gcd(endMetrics.length) * endMetrics.length;
        beginMetrics = _repeatContours(beginMetrics, commonCount);
        endMetrics = _repeatContours(endMetrics, commonCount);
      } else {
        // 描边及其他填充规则沿用原来的均匀复制，不改动既有对应方式。
        combineList(beginMetrics, endMetrics, CombineMethod.space);
      }
    }

    // 本次准备期间的原始采样缓存：重复出现的同一轮廓只沿弧长采样一次。
    final samples = <ui.PathMetric, List<Offset>>{};
    // 本次准备期间的配对缓存：相同起始/目标轮廓不重复补齐采样点。
    final pairs = <(ui.PathMetric, ui.PathMetric), _PreparedContour>{};
    // 最终保留的模板列表；不能去重，否则会改变填充时的轮廓重复次数。
    final contours = <_PreparedContour>[];
    for (var index = 0; index < beginMetrics.length; index++) {
      final source = beginMetrics[index];
      final target = endMetrics[index];
      contours.add(
        pairs.putIfAbsent(
          (source, target),
          () => _prepareContour(
            source,
            target,
            precision,
            combineMethod,
            samples,
          ),
        ),
      );
    }
    return _PreparedPaths(contours);
  }

  /// 等次数展开轮廓引用；count 必须是原数量的整数倍。
  /// 例如 [A, B] 展开到 6 条后是 [A, A, A, B, B, B]，不复制几何数据。
  static List<ui.PathMetric> _repeatContours(List<ui.PathMetric> metrics, int count) {
    // 每条原始轮廓对应多少条连续的目标槽位。
    final repetitions = count ~/ metrics.length;
    return List.generate(count, (index) => metrics[index ~/ repetitions]);
  }

  /// 单对轮廓的一次性准备和绘制入口，不持有跨帧缓存。
  static void computeMetric({
    required ui.PathMetric beginMetric,
    required ui.PathMetric endMetric,
    required Path result,
    required double t,
    required CombineMethod combineMethod,
    required double precision,
  }) {
    _prepareContour(beginMetric, endMetric, precision, combineMethod, {}).addTo(result, t);
  }

  /// 按弧长步长采样一条轮廓，并额外保留精确终点。
  /// 即使轮廓短于步长，也能得到起点和终点。
  static List<Offset> _sample(ui.PathMetric metric, double precision) {
    if (!precision.isFinite || precision <= 0) {
      throw ArgumentError.value(precision, 'precision', 'Must be finite and positive');
    }
    return [
      for (var distance = 0.0; distance < metric.length; distance += precision)
        metric.getTangentForOffset(distance)!.position,
      metric.getTangentForOffset(metric.length)!.position,
    ];
  }

  /// 取出两条轮廓的原始采样，按指定方式补齐，建立逐点对应关系。
  static _PreparedContour _prepareContour(
    ui.PathMetric beginMetric,
    ui.PathMetric endMetric,
    double precision,
    CombineMethod combineMethod,
    Map<ui.PathMetric, List<Offset>> samples,
  ) {
    // combineList 会原地修改较短列表，因此必须复制缓存中的原始采样。
    // 同一轮廓可能配对不同目标，不能让一个配对的补齐污染其他配对。
    final beginPointList =
        List<Offset>.of(samples.putIfAbsent(beginMetric, () => _sample(beginMetric, precision)));
    final endPointList =
        List<Offset>.of(samples.putIfAbsent(endMetric, () => _sample(endMetric, precision)));
    if (beginPointList.length != endPointList.length) {
      combineList(
        beginPointList,
        endPointList,
        combineMethod,
      );
    }

    return _PreparedContour(
      beginPointList,
      endPointList,
      beginMetric.isClosed && endMetric.isClosed,
    );
  }

  /// 原地扩充较短列表直到等长，不删元素，也不改变原元素顺序。
  /// T 可以是轮廓或采样点；调用方保证两侧非空且长度不同。
  static void combineList<T>(List<T> a, List<T> b, CombineMethod combineMethod) {
    assert(a.length != b.length, 'Only handle the case where two lists are not the same length');

    // 指向需要扩充的原列表，而不是新建副本。
    late List<T> shortList;
    // 仅用来确定补齐后的目标长度，本身不修改。
    late List<T> longList;
    if (a.length > b.length) {
      longList = a;
      shortList = b;
    } else {
      longList = b;
      shortList = a;
    }

    switch (combineMethod) {
      case CombineMethod.start:
        {
          shortList.insertAll(
            0,
            List.generate(
              (longList.length - shortList.length),
              (_) => shortList.first,
            ),
          );
          break;
        }
      case CombineMethod.end:
        {
          shortList.addAll(
            List.generate(
              (longList.length - shortList.length),
              (_) => shortList.last,
            ),
          );
          break;
        }
      case CombineMethod.center:
        {
          // 还需要补入的元素数量，以及按原顺序构建的补齐结果。
          final difference = longList.length - shortList.length;
          final result = <T>[];

          // 偶数长度有左右两个中心，分别承担补入数量；奇数长度两索引相同。
          final leftCenter = (shortList.length - 1) ~/ 2;
          final rightCenter = shortList.length ~/ 2;
          final leftExtra = difference ~/ 2;
          final rightExtra = difference - leftExtra;

          for (int i = 0; i < shortList.length; i++) {
            result.add(shortList[i]);
            if (leftCenter == rightCenter && i == leftCenter) {
              result.addAll(List<T>.filled(difference, shortList[i]));
            } else if (i == leftCenter) {
              result.addAll(List<T>.filled(leftExtra, shortList[i]));
            } else if (i == rightCenter) {
              result.addAll(List<T>.filled(rightExtra, shortList[i]));
            }
          }

          shortList
            ..clear()
            ..addAll(result);
          break;
        }
      case CombineMethod.space:
        {
          final result = List<T>.generate(longList.length, (i) {
            // 将目标槽位映射回原列表的相对位置，保证首尾准确对应，
            // 并把重复元素尽量均匀地分布，而不是全部堆在开头。
            final sourceIndex = (i * (shortList.length - 1) / (longList.length - 1)).round();
            return shortList[sourceIndex];
          });

          shortList
            ..clear()
            ..addAll(result);
          break;
        }
    }
  }
}
