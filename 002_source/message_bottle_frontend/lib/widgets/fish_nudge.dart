import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'bottle_field.dart';

/// 유리병 하나가 [from] 자리에서 [to] 자리로 옮겨 가는 이동.
class SlotMove {
  const SlotMove(this.from, this.to);
  final int from;
  final int to;

  @override
  bool operator ==(Object other) =>
      other is SlotMove && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '$from→$to';
}

/// 물고기가 [start] 자리의 유리병을 [direction] 쪽으로 밀었을 때 일어나는 이동들(순수 계산).
///
/// 밀린 유리병은 밀린 방향 쪽에서 가장 가까운 자리로 간다. 그 자리에 다른 유리병이 있으면 그 유리병을
/// 밀치고 자리를 차지하고, 밀려난 유리병도 같은 규칙으로 다음 자리로 간다. 빈자리에 닿으면 끝난다.
/// 자리는 11곳이고 유리병은 최대 10개라 빈자리가 반드시 있으므로 항상 끝난다.
/// [occupied]는 유리병이 있는 자리들([start] 포함)이다. 이동은 일어나는 순서대로 돌려준다.
List<SlotMove> pushChain({
  required int start,
  required Offset direction,
  required Set<int> occupied,
  List<Offset> slots = BottleField.slots,
}) {
  final moves = <SlotMove>[];
  final visited = <int>{start};
  var current = start;
  var dir = direction.distance == 0
      ? const Offset(1, 0)
      : direction / direction.distance;
  while (true) {
    int? next;
    var nextLength = double.infinity;
    var nextAhead = false;
    for (var i = 0; i < slots.length; i++) {
      if (visited.contains(i)) continue;
      final v = slots[i] - slots[current];
      final length = v.distance;
      if (length == 0) continue;
      final ahead = (v.dx * dir.dx + v.dy * dir.dy) / length > 0.2;
      // 밀린 방향 쪽 자리를 먼저, 그중 가까운 자리를 고른다. 그쪽에 자리가 없으면 가장 가까운 자리.
      final better =
          next == null ||
          (ahead && !nextAhead) ||
          (ahead == nextAhead && length < nextLength);
      if (better) {
        next = i;
        nextLength = length;
        nextAhead = ahead;
      }
    }
    if (next == null) return moves; // 갈 자리가 없다(자리가 하나뿐일 때만)
    moves.add(SlotMove(current, next));
    if (!occupied.contains(next)) return moves;
    final v = slots[next] - slots[current];
    dir = v / v.distance;
    visited.add(next);
    current = next;
  }
}

/// 지나가는 물고기 한 번의 길. 화면 밖에서 와서 [slot] 자리의 유리병을 들이받고 반대쪽으로 나간다.
class FishRun {
  const FishRun({required this.slot, required this.direction});

  /// 들이받을 유리병의 자리.
  final int slot;

  /// 헤엄치는 방향(단위 벡터).
  final Offset direction;

  /// 들이받기 전까지와 지나간 뒤에 헤엄치는 거리(논리 픽셀).
  static const double approach = 520;
  static const double leave = 580;

  /// 들이받는 순간(0~1). 몸길이의 반만큼 앞서 닿는다.
  static const double hitAt = (approach - 30) / (approach + leave);

  static const Duration duration = Duration(milliseconds: 4400);
}

/// 물속을 지나가는 물고기 그림자. 유리병보다 아래에 그린다.
class FishLayer extends StatelessWidget {
  const FishLayer({super.key, required this.run, required this.progress});

  final FishRun run;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: Size.infinite,
      painter: _FishPainter(run, progress, AppColors.ink),
    ),
  );
}

class _FishPainter extends CustomPainter {
  _FishPainter(this.run, this.progress, this.color) : super(repaint: progress);
  final FishRun run;
  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final g = BottleGeometry(size);
    // 유리병 몸통 아래쪽(물에 잠긴 곳)을 들이받는다.
    final hit = g.topLeft(run.slot) + Offset(g.width / 2, g.height * 0.66);
    final t = progress.value;
    final travelled = t * (FishRun.approach + FishRun.leave);
    final at = hit + run.direction * (travelled - FishRun.approach);

    // 부딪힌 자리에서 번지는 물결.
    if (t > FishRun.hitAt) {
      final r = ((t - FishRun.hitAt) / 0.2).clamp(0.0, 1.0);
      if (r < 1) {
        canvas.drawCircle(
          hit,
          8 + 34 * Curves.easeOut.transform(r),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.8 * (1 - r)),
        );
      }
    }

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(run.direction.direction);
    // 오른쪽을 보는 그림이라 왼쪽으로 갈 때는 위아래를 뒤집어 등이 위로 오게 한다.
    if (run.direction.dx < 0) canvas.scale(1, -1);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    final s = g.scale;
    final body = Path()
      ..moveTo(-22 * s, 0)
      ..quadraticBezierTo(-4 * s, -17 * s, 30 * s, 0)
      ..quadraticBezierTo(-4 * s, 17 * s, -22 * s, 0)
      ..close();
    canvas.drawPath(body, paint);
    // 꼬리는 헤엄치며 좌우로 흔들린다.
    canvas.save();
    canvas.translate(-18 * s, 0);
    canvas.rotate(math.sin(travelled / 14) * 0.3);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(-14 * s, -12 * s)
        ..lineTo(-14 * s, 12 * s)
        ..close(),
      paint,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FishPainter old) =>
      old.run != run || old.progress != progress || old.color != color;
}
