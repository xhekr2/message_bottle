import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bottle_icon.dart';

/// 편지 id마다 자리(0~9)를 정한다. 이미 자리가 있는 유리병은 그 자리를 지키고,
/// 새로 온 유리병만 비어 있는 가장 앞 자리에 놓는다. [reserved]는 쓰지 못하는 자리(사라지는 중인 자리).
/// 그래서 한 병이 사라져도 나머지 병은 움직이지 않는다.
Map<int, int> assignSlots(
  Map<int, int> previous,
  List<int> ids, {
  Set<int> reserved = const {},
}) {
  final result = <int, int>{};
  final used = {...reserved};
  for (final id in ids) {
    final slot = previous[id];
    if (slot != null && !used.contains(slot)) {
      result[id] = slot;
      used.add(slot);
    }
  }
  for (final id in ids) {
    if (result.containsKey(id)) continue;
    var slot = 0;
    while (used.contains(slot)) {
      slot++;
    }
    result[id] = slot;
    used.add(slot);
  }
  return result;
}

/// 바다에 떠 있는 유리병들. 자리 10곳(390x844 기준 좌표)은 서로 겹치지 않고
/// 우상단 버튼·"편지 쓰기" 버튼과도 겹치지 않는다. [onTap]이 없으면 누를 수 없는 그림이다(다른 사람의 바다).
class BottleField extends StatelessWidget {
  const BottleField({
    super.key,
    required this.animation,
    required this.slotOf,
    this.keyOf,
    this.onTap,
    this.vanishing = const [],
    this.onVanished,
  });

  static const slots = <Offset>[
    Offset(60, 200),
    Offset(250, 260),
    Offset(130, 380),
    Offset(250, 490),
    Offset(30, 430),
    Offset(170, 560),
    Offset(300, 370),
    Offset(40, 310),
    Offset(150, 180),
    Offset(310, 610),
  ];

  final Animation<double> animation;

  /// 유리병마다 놓을 자리 번호(0~9). 길이가 그릴 유리병 수다.
  final List<int> slotOf;
  final Key Function(int index)? keyOf;
  final void Function(int index)? onTap;

  /// 버려서 사라지는 중인 자리들(물결이 번지고 병이 가라앉는다).
  final List<int> vanishing;
  final void Function(int slot)? onVanished;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final sx = c.maxWidth / 390;
        final sy = c.maxHeight / 844;
        final scale = sx.clamp(0.8, 1.2).toDouble();
        final bw = 56 * scale, bh = 100 * scale;
        double left(int slot) => (slots[slot].dx * sx).clamp(
          4.0,
          math.max(4.0, c.maxWidth - bw - 4),
        );
        double top(int slot) => slots[slot].dy * sy;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < slotOf.length; i++)
              if (slotOf[i] >= 0 && slotOf[i] < slots.length)
                Positioned(
                  left: left(slotOf[i]),
                  top: top(slotOf[i]),
                  child: _FloatingBottle(
                    key: keyOf?.call(i),
                    animation: animation,
                    phase: slotOf[i] * 0.13,
                    tilt: ((slotOf[i] % 5) - 2) * 0.07,
                    width: bw,
                    height: bh,
                    onTap: onTap == null ? null : () => onTap!(i),
                  ),
                ),
            for (final slot in vanishing)
              Positioned(
                key: ValueKey('vanish-$slot'),
                left: left(slot),
                top: top(slot),
                child: VanishEffect(
                  width: bw,
                  height: bh,
                  tilt: ((slot % 5) - 2) * 0.07,
                  onDone: () => onVanished?.call(slot),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 버린 유리병이 사라지는 효과: 병이 물속으로 가라앉고, 그 자리에서 물결 세 겹이 퍼져 나간다.
class VanishEffect extends StatefulWidget {
  const VanishEffect({
    super.key,
    required this.width,
    required this.height,
    required this.tilt,
    required this.onDone,
  });

  final double width;
  final double height;
  final double tilt;
  final VoidCallback onDone;

  @override
  State<VanishEffect> createState() => _VanishEffectState();
}

class _VanishEffectState extends State<VanishEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward().whenComplete(() => widget.onDone());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = widget.height;
    return IgnorePointer(
      child: SizedBox(
        width: w,
        height: h,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final ms = _c.value * 2600;
            // 가라앉는 병: 0.95초 동안 아래로 내려가며 작아지고 기울며 사라진다.
            final sink = Curves.easeIn.transform((ms / 950).clamp(0.0, 1.0));
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 물결은 병의 아래쪽(물에 닿는 곳)에서 퍼진다.
                Positioned(
                  left: w / 2,
                  top: h * 0.78,
                  child: CustomPaint(painter: _RipplePainter(ms, w)),
                ),
                Opacity(
                  opacity: 1 - sink,
                  child: Transform.translate(
                    offset: Offset(0, 26 * sink),
                    child: Transform.rotate(
                      angle: widget.tilt + 14 * math.pi / 180 * sink,
                      child: Transform.scale(
                        scale: 1 - 0.45 * sink,
                        child: BottleIcon(width: w, height: h),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.ms, this.bottleWidth);
  final double ms;
  final double bottleWidth;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final t = ((ms - 300.0 * i) / 2000).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeOut.transform(t);
      final radius = bottleWidth * 0.25 * (1 + 29 * eased) / 2;
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2,
        height: radius,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - t) + 0.5
          ..color = Colors.white.withValues(alpha: 0.75 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) => old.ms != ms;
}

/// 파도에 천천히 떠 있는 유리병. [onTap]이 있으면 누르면 편지를 연다.
class _FloatingBottle extends StatelessWidget {
  const _FloatingBottle({
    super.key,
    required this.animation,
    required this.phase,
    required this.tilt,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final Animation<double> animation;
  final double phase;
  final double tilt;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bottle = SizedBox(
      width: width,
      height: height,
      child: BottleIcon(width: width, height: height),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value * 2 * math.pi + phase * 2 * math.pi;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * 5),
          child: Transform.rotate(
            angle: tilt + math.sin(t) * 0.03,
            child: child,
          ),
        );
      },
      child: onTap == null
          ? Semantics(label: '유리병', child: bottle)
          : Semantics(
              button: true,
              label: '유리병 편지 열기',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: bottle,
              ),
            ),
    );
  }
}
