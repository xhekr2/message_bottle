import 'package:flutter/material.dart';

import '../theme.dart';
// WaveClock은 sea_waves.dart에 있다.
import 'fishing_rig.dart';
import 'sea_waves.dart';

/// 바다 화면의 배경: 물빛 그라데이션, 빛 반사, 아래쪽 파도. [content]는 배경 위에, [overlay]는 파도 위에 그린다.
/// 내 바다와 다른 사람의 바다 방문 화면이 함께 쓴다.
class SeaBackdrop extends StatelessWidget {
  const SeaBackdrop({
    super.key,
    required this.clock,
    required this.content,
    this.overlay,
    this.header,
    this.rig,
  });

  final WaveClock clock;

  /// 위 가운데에 올리는 표시(홈 화면의 페이지 탭).
  final Widget? header;
  final Widget content;
  final Widget? overlay;

  /// 위쪽 표시([header]) 바로 아랫줄에 놓는 버튼의 위쪽 여백(SafeArea 안쪽 기준).
  /// 내 바다의 편지함 버튼과 공유 바다의 "편지 띄우기"가 같은 높이에서 시작한다.
  static const double chipTop = 62;

  /// 파도 사이에 그릴 낚싯줄(공유 바다).
  final FishingRig? rig;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.seaTop, AppColors.seaMiddle, AppColors.seaBottom],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Stack(
        children: [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.56, -0.76),
                  radius: 0.8,
                  colors: [
                    AppColors.seaGlow,
                    AppColors.seaGlow.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
          // 밤바다에는 별과 달이 뜬다.
          if (AppColors.night)
            const Positioned.fill(
              child: IgnorePointer(child: NightSky(key: Key('night-sky'))),
            ),
          Positioned.fill(child: content),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SeaWaves(clock: clock, rig: rig),
          ),
          if (overlay != null) Positioned.fill(child: overlay!),
          if (header != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(child: header),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 바다 화면 위에 올리는 둥근 버튼(아이콘 + 글자). 높이 48 이상.
class SeaChip extends StatelessWidget {
  const SeaChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chip,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppColors.text),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 밤바다의 하늘: 고정된 자리의 별과 초승달.
class NightSky extends StatelessWidget {
  const NightSky({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _NightSkyPainter(), size: Size.infinite);
}

class _NightSkyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final star = Paint();
    // 화면 위쪽 절반에만 별을 흩뿌린다(자리는 고정).
    for (var i = 0; i < 34; i++) {
      final x = ((i * 53 + 17) % 100) / 100 * size.width;
      final y = ((i * 37 + 11) % 100) / 100 * size.height * 0.5;
      star.color = Colors.white.withValues(alpha: 0.35 + (i % 5) * 0.12);
      canvas.drawCircle(Offset(x, y), i % 7 == 0 ? 1.6 : 1.0, star);
    }
    final moon = Offset(size.width * 0.2, size.height * 0.19);
    canvas.drawCircle(
      moon,
      34,
      Paint()
        ..color = const Color(0x33DCE6FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    final path = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moon, radius: 20)),
      Path()..addOval(
        Rect.fromCircle(center: moon + const Offset(-9, -5), radius: 18),
      ),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xFFF4F1DC));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
