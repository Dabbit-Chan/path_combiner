import 'dart:math' as math;
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

/// 决定两条路径在插值前如何配对轮廓。
///
/// 默认推荐 [ordered]：开销最小，保持原有行为。
/// 当轮廓顺序不对应、需要按几何特征自动配对时，再显式选择 [greedy] 或 [hungarian]。
/// 匹配代价最小不一定意味着动画视觉效果最好，应结合实际路径选择。
enum ContourMatchMethod {
  /// 按轮廓的原始顺序配对，保持默认行为。
  ///
  /// 开销最小，适合两侧轮廓顺序本来就对应的路径，也是推荐的默认方式。
  ordered,

  /// 每次选择当前可用轮廓中匹配代价最小的一对。
  ///
  /// 适合轮廓顺序不一致、需要按几何特征自动配对的路径，但不保证总匹配代价最小。
  greedy,

  /// 最小化轮廓配对的总几何匹配代价。
  ///
  /// 适合更关注整体匹配成本、能接受额外预处理开销的场景。
  /// 无重复轮廓时使用匈牙利算法，有重复时使用等价的容量最小费用流求解。
  /// 总匹配代价最小不保证动画视觉效果最好。
  hungarian,
}

/// 保存可在动画运行期间调整的采样点补齐与轮廓匹配配置。
class PathCombineController {
  /// 影响轮廓内部的点对应关系；轮廓数量的配对另行处理。
  CombineMethod combineMethod = CombineMethod.space;

  /// 控制轮廓之间的配对方式，不影响轮廓内部的采样点补齐方式。
  ContourMatchMethod contourMatchMethod = ContourMatchMethod.ordered;
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

  /// 每次检查缓存时读取补齐与匹配配置，支持运行期间修改。
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
      controller.contourMatchMethod,
      paintingStyle
    );
    if (_preparedKey == key) return;
    _prepared = PathUtil._prepare(
      source,
      target,
      precision,
      controller.combineMethod,
      controller.contourMatchMethod,
      paintingStyle,
    );
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

class _ContourDescriptor {
  _ContourDescriptor({
    required this.centroid,
    required this.bounds,
    required this.length,
    required this.area,
    required this.direction,
    required this.closed,
  });

  final Offset centroid;
  final Rect bounds;
  final double length;
  final double area;
  final int direction;
  final bool closed;

  factory _ContourDescriptor.fromMetric(
    ui.PathMetric metric,
    double precision,
    Map<ui.PathMetric, List<Offset>> samples,
  ) {
    final points = samples.putIfAbsent(metric, () => PathUtil._sample(metric, precision));
    var minX = points.first.dx;
    var maxX = minX;
    var minY = points.first.dy;
    var maxY = minY;
    var twiceSignedArea = 0.0;
    var centroidNumeratorX = 0.0;
    var centroidNumeratorY = 0.0;
    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      minX = math.min(minX, current.dx);
      maxX = math.max(maxX, current.dx);
      minY = math.min(minY, current.dy);
      maxY = math.max(maxY, current.dy);
      final cross = current.dx * next.dy - next.dx * current.dy;
      twiceSignedArea += cross;
      centroidNumeratorX += (current.dx + next.dx) * cross;
      centroidNumeratorY += (current.dy + next.dy) * cross;
    }
    final area = twiceSignedArea.abs() / 2;
    final centroid = metric.isClosed && twiceSignedArea.abs() > 1e-9
        ? Offset(
            centroidNumeratorX / (3 * twiceSignedArea),
            centroidNumeratorY / (3 * twiceSignedArea),
          )
        : points.fold<Offset>(Offset.zero, (sum, point) => sum + point) / points.length.toDouble();
    return _ContourDescriptor(
      centroid: centroid,
      bounds: Rect.fromLTRB(minX, minY, maxX, maxY),
      length: metric.length,
      area: metric.isClosed ? area : 0,
      direction: metric.isClosed ? twiceSignedArea.sign.toInt() : 0,
      closed: metric.isClosed,
    );
  }
}

class _AssignmentCandidate {
  const _AssignmentCandidate(this.source, this.target, this.cost);

  final int source;
  final int target;
  final double cost;

  int compareTo(_AssignmentCandidate other) {
    final costOrder = cost.compareTo(other.cost);
    if (costOrder != 0) return costOrder;
    final sourceOrder = source.compareTo(other.source);
    return sourceOrder != 0 ? sourceOrder : target.compareTo(other.target);
  }
}

class _FlowEdge {
  _FlowEdge(this.target, this.reverseIndex, this.capacity, this.cost);

  final int target;
  final int reverseIndex;
  int capacity;
  final double cost;
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

    return _prepare(
      begin,
      end,
      precision,
      controller.combineMethod,
      controller.contourMatchMethod,
      paintingStyle,
    ).lerp(begin, end, t);
  }

  /// 执行与 t 无关的工作：计算轮廓 → 对齐数量 → 采样 → 补齐点数。
  static _PreparedPaths _prepare(
    Path begin,
    Path end,
    double precision,
    CombineMethod combineMethod,
    ContourMatchMethod contourMatchingAlgorithm,
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
    final targetIndices = _matchContours(
      beginMetrics,
      endMetrics,
      precision,
      contourMatchingAlgorithm,
      samples,
    );
    // 本次准备期间的配对缓存：相同起始/目标轮廓不重复补齐采样点。
    final pairs = <(ui.PathMetric, ui.PathMetric), _PreparedContour>{};
    // 最终保留的模板列表；不能去重，否则会改变填充时的轮廓重复次数。
    final contours = <_PreparedContour>[];
    for (var index = 0; index < beginMetrics.length; index++) {
      final source = beginMetrics[index];
      final target = endMetrics[targetIndices[index]];
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

  /// 返回每条起始轮廓对应的目标轮廓下标。
  static List<int> _matchContours(
    List<ui.PathMetric> beginMetrics,
    List<ui.PathMetric> endMetrics,
    double precision,
    ContourMatchMethod algorithm,
    Map<ui.PathMetric, List<Offset>> samples,
  ) {
    final count = beginMetrics.length;
    if (count != endMetrics.length) {
      throw ArgumentError('Contour lists must have equal lengths before matching');
    }
    if (algorithm == ContourMatchMethod.ordered || count < 2) {
      return List<int>.generate(count, (index) => index);
    }

    final beginGroups = _groupContours(beginMetrics);
    final endGroups = _groupContours(endMetrics);
    final beginDescriptors = [
      for (final group in beginGroups)
        _ContourDescriptor.fromMetric(beginMetrics[group.first], precision, samples),
    ];
    final endDescriptors = [
      for (final group in endGroups)
        _ContourDescriptor.fromMetric(endMetrics[group.first], precision, samples),
    ];
    final allDescriptors = [...beginDescriptors, ...endDescriptors];
    final maxDimension = allDescriptors.fold<double>(1, (value, descriptor) {
      return math.max(value, math.max(descriptor.bounds.width, descriptor.bounds.height));
    });
    final maxLength = allDescriptors.fold<double>(1, (value, descriptor) {
      return math.max(value, descriptor.length);
    });
    final maxCenterDistance = maxDimension * math.sqrt2;
    final costs = List<List<double>>.generate(beginGroups.length, (sourceIndex) {
      return List<double>.generate(endGroups.length, (targetIndex) {
        final source = beginDescriptors[sourceIndex];
        final target = endDescriptors[targetIndex];
        final centerCost = (source.centroid - target.centroid).distance / maxCenterDistance;
        final sizeCost = ((source.bounds.width - target.bounds.width).abs() +
                (source.bounds.height - target.bounds.height).abs()) /
            (2 * maxDimension);
        final lengthCost = (source.length - target.length).abs() / maxLength;
        final areaCost = (math.sqrt(source.area) - math.sqrt(target.area)).abs() / maxDimension;
        final directionCost = source.direction == target.direction ? 0.0 : 1.0;
        final closureCost = source.closed == target.closed ? 0.0 : 1.0;
        return centerCost * 0.4 +
            sizeCost * 0.25 +
            lengthCost * 0.2 +
            areaCost * 0.1 +
            directionCost * 0.05 +
            closureCost * 0.5;
      });
    });

    if (algorithm == ContourMatchMethod.hungarian &&
        beginGroups.length == count &&
        endGroups.length == count) {
      return _hungarianAssignment(costs);
    }
    final sourceCapacities = [for (final group in beginGroups) group.length];
    final targetCapacities = [for (final group in endGroups) group.length];
    final flows = algorithm == ContourMatchMethod.greedy
        ? _greedyAssignment(costs, sourceCapacities, targetCapacities)
        : _minimumCostAssignment(costs, sourceCapacities, targetCapacities);
    final assignment = List<int>.filled(count, -1);
    final targetOffsets = List<int>.filled(endGroups.length, 0);
    for (var source = 0; source < beginGroups.length; source++) {
      var sourceOffset = 0;
      final targets = [
        for (var target = 0; target < endGroups.length; target++)
          if (flows[source][target] > 0) target,
      ];
      if (algorithm == ContourMatchMethod.greedy && targets.length > 1) {
        targets.sort((first, second) {
          final costOrder = costs[source][first].compareTo(costs[source][second]);
          return costOrder != 0 ? costOrder : first.compareTo(second);
        });
      }
      for (final target in targets) {
        for (var copy = 0; copy < flows[source][target]; copy++) {
          assignment[beginGroups[source][sourceOffset++]] =
              endGroups[target][targetOffsets[target]++];
        }
      }
    }
    return assignment;
  }

  /// 只合并补齐时重复引用的同一轮廓，不合并几何相同的独立轮廓。
  static List<List<int>> _groupContours(List<ui.PathMetric> metrics) {
    final groups = <ui.PathMetric, List<int>>{};
    for (var index = 0; index < metrics.length; index++) {
      groups.putIfAbsent(metrics[index], () => []).add(index);
    }
    return groups.values.toList();
  }

  /// 用最小堆按代价取边，按容量批量分配，不排序展开后的重复边。
  static List<List<int>> _greedyAssignment(
    List<List<double>> costs,
    List<int> sourceCapacities,
    List<int> targetCapacities,
  ) {
    final candidates = <_AssignmentCandidate>[
      for (var source = 0; source < sourceCapacities.length; source++)
        for (var target = 0; target < targetCapacities.length; target++)
          _AssignmentCandidate(source, target, costs[source][target]),
    ];
    void siftDown(int parent) {
      final candidate = candidates[parent];
      while (parent * 2 + 1 < candidates.length) {
        var child = parent * 2 + 1;
        if (child + 1 < candidates.length &&
            candidates[child + 1].compareTo(candidates[child]) < 0) {
          child++;
        }
        if (candidate.compareTo(candidates[child]) <= 0) break;
        candidates[parent] = candidates[child];
        parent = child;
      }
      candidates[parent] = candidate;
    }

    for (var parent = candidates.length ~/ 2 - 1; parent >= 0; parent--) {
      siftDown(parent);
    }
    final flows = [
      for (final _ in sourceCapacities) List<int>.filled(targetCapacities.length, 0),
    ];
    var remaining = sourceCapacities.fold<int>(0, (sum, capacity) => sum + capacity);
    while (remaining > 0) {
      final candidate = candidates.first;
      final last = candidates.removeLast();
      if (candidates.isNotEmpty) {
        candidates[0] = last;
        siftDown(0);
      }
      final amount =
          math.min(sourceCapacities[candidate.source], targetCapacities[candidate.target]);
      if (amount == 0) continue;
      flows[candidate.source][candidate.target] = amount;
      sourceCapacities[candidate.source] -= amount;
      targetCapacities[candidate.target] -= amount;
      remaining -= amount;
    }
    return flows;
  }

  /// 对重复行列采用等价的容量最小费用流，保留总匹配代价最优目标。
  static List<List<int>> _minimumCostAssignment(
    List<List<double>> costs,
    List<int> sourceCapacities,
    List<int> targetCapacities,
  ) {
    final sourceCount = sourceCapacities.length;
    final targetCount = targetCapacities.length;
    final sink = sourceCount + targetCount + 1;
    final graph = List.generate(sink + 1, (_) => <_FlowEdge>[]);
    _FlowEdge addEdge(int source, int target, int capacity, double cost) {
      final forward = _FlowEdge(target, graph[target].length, capacity, cost);
      final reverse = _FlowEdge(source, graph[source].length, 0, -cost);
      graph[source].add(forward);
      graph[target].add(reverse);
      return forward;
    }

    for (var source = 0; source < sourceCount; source++) {
      addEdge(0, source + 1, sourceCapacities[source], 0);
    }
    final pairEdges = [
      for (var source = 0; source < sourceCount; source++)
        [
          for (var target = 0; target < targetCount; target++)
            addEdge(
              source + 1,
              sourceCount + target + 1,
              math.min(sourceCapacities[source], targetCapacities[target]),
              costs[source][target],
            ),
        ],
    ];
    for (var target = 0; target < targetCount; target++) {
      addEdge(sourceCount + target + 1, sink, targetCapacities[target], 0);
    }
    final potentials = List<double>.filled(graph.length, 0);
    var remaining = sourceCapacities.fold<int>(0, (sum, capacity) => sum + capacity);
    while (remaining > 0) {
      final distances = List<double>.filled(graph.length, double.infinity)..[0] = 0;
      final visited = List<bool>.filled(graph.length, false);
      final parents = List<int>.filled(graph.length, -1);
      final parentEdges = List<int>.filled(graph.length, -1);
      for (var iteration = 0; iteration < graph.length; iteration++) {
        var closest = -1;
        for (var node = 0; node < graph.length; node++) {
          if (!visited[node] &&
              distances[node].isFinite &&
              (closest == -1 || distances[node] < distances[closest])) {
            closest = node;
          }
        }
        if (closest == -1) break;
        visited[closest] = true;
        for (var edgeIndex = 0; edgeIndex < graph[closest].length; edgeIndex++) {
          final edge = graph[closest][edgeIndex];
          if (edge.capacity == 0 || visited[edge.target]) continue;
          final reducedCost =
              math.max(0.0, edge.cost + potentials[closest] - potentials[edge.target]);
          final distance = distances[closest] + reducedCost;
          if (distance < distances[edge.target]) {
            distances[edge.target] = distance;
            parents[edge.target] = closest;
            parentEdges[edge.target] = edgeIndex;
          }
        }
      }
      if (parents[sink] == -1) throw StateError('No complete contour assignment');
      for (var node = 0; node < graph.length; node++) {
        if (distances[node].isFinite) potentials[node] += distances[node];
      }
      var amount = remaining;
      for (var node = sink; node != 0; node = parents[node]) {
        amount = math.min(amount, graph[parents[node]][parentEdges[node]].capacity);
      }
      for (var node = sink; node != 0; node = parents[node]) {
        final edge = graph[parents[node]][parentEdges[node]];
        edge.capacity -= amount;
        graph[node][edge.reverseIndex].capacity += amount;
      }
      remaining -= amount;
    }
    return [
      for (final row in pairEdges)
        [for (final edge in row) graph[edge.target][edge.reverseIndex].capacity],
    ];
  }

  /// 用经典 O(n³) 最小代价指派算法求解方阵。
  static List<int> _hungarianAssignment(List<List<double>> costs) {
    final count = costs.length;
    final rowPotentials = List<double>.filled(count + 1, 0);
    final columnPotentials = List<double>.filled(count + 1, 0);
    final matchedRow = List<int>.filled(count + 1, 0);
    final previousColumn = List<int>.filled(count + 1, 0);

    for (var row = 1; row <= count; row++) {
      matchedRow[0] = row;
      var currentColumn = 0;
      final minimumReducedCosts = List<double>.filled(count + 1, double.infinity);
      final usedColumns = List<bool>.filled(count + 1, false);
      do {
        usedColumns[currentColumn] = true;
        final currentRow = matchedRow[currentColumn];
        var delta = double.infinity;
        var nextColumn = 0;
        for (var column = 1; column <= count; column++) {
          if (usedColumns[column]) continue;
          final reducedCost = costs[currentRow - 1][column - 1] -
              rowPotentials[currentRow] -
              columnPotentials[column];
          if (reducedCost < minimumReducedCosts[column]) {
            minimumReducedCosts[column] = reducedCost;
            previousColumn[column] = currentColumn;
          }
          if (minimumReducedCosts[column] < delta) {
            delta = minimumReducedCosts[column];
            nextColumn = column;
          }
        }
        for (var column = 0; column <= count; column++) {
          if (usedColumns[column]) {
            rowPotentials[matchedRow[column]] += delta;
            columnPotentials[column] -= delta;
          } else {
            minimumReducedCosts[column] -= delta;
          }
        }
        currentColumn = nextColumn;
      } while (matchedRow[currentColumn] != 0);

      do {
        final nextColumn = previousColumn[currentColumn];
        matchedRow[currentColumn] = matchedRow[nextColumn];
        currentColumn = nextColumn;
      } while (currentColumn != 0);
    }

    final assignment = List<int>.filled(count, -1);
    for (var column = 1; column <= count; column++) {
      assignment[matchedRow[column] - 1] = column - 1;
    }
    return assignment;
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
