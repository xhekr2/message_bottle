import 'package:flutter/material.dart';

import '../theme.dart';

/// 유리병 그림. 60x110 좌표계로 그리고 위젯 크기에 맞춰 늘린다.
class BottleIcon extends StatelessWidget {
  const BottleIcon({super.key, this.width = 56, this.height = 100});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, height),
    painter: _BottlePainter(AppColors.current),
  );
}

class _BottlePainter extends CustomPainter {
  _BottlePainter(this.palette);
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) => paintBottle(canvas, size);

  @override
  bool shouldRepaint(covariant _BottlePainter oldDelegate) =>
      oldDelegate.palette != palette;
}

/// 유리병을 [size] 크기로 그린다(왼쪽 위가 원점). 낚싯줄에 매달린 유리병도 이 그림을 쓴다.
void paintBottle(Canvas canvas, Size size) {
  {
    canvas.save();
    canvas.scale(size.width / 60, size.height / 110);

    // 코르크
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 2, 16, 12),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFB98A5A),
    );

    // 유리병 몸통
    final body = Path()
      ..moveTo(24, 14)
      ..lineTo(36, 14)
      ..lineTo(36, 24)
      ..cubicTo(46, 30, 52, 38, 52, 52)
      ..lineTo(52, 92)
      ..cubicTo(52, 100, 46, 106, 38, 106)
      ..lineTo(22, 106)
      ..cubicTo(14, 106, 8, 100, 8, 92)
      ..lineTo(8, 52)
      ..cubicTo(8, 38, 14, 30, 24, 24)
      ..close();
    canvas.drawPath(body, Paint()..color = AppColors.bottleGlass);
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.bottleLine,
    );

    // 편지(기울어진 종이)
    canvas.save();
    canvas.translate(30, 68);
    canvas.rotate(-8 * 3.1415926535 / 180);
    canvas.translate(-30, -68);
    final paper = RRect.fromRectAndRadius(
      const Rect.fromLTWH(20, 46, 20, 44),
      const Radius.circular(4),
    );
    canvas.drawRRect(paper, Paint()..color = const Color(0xFFFFF8E7));
    canvas.drawRRect(
      paper,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFD9C9A0),
    );
    final line = Paint()
      ..color = const Color(0xFFC9B787)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(24, 56), const Offset(36, 56), line);
    canvas.drawLine(const Offset(24, 63), const Offset(36, 63), line);
    canvas.drawLine(const Offset(24, 70), const Offset(33, 70), line);
    canvas.restore();

    // 유리 반사
    canvas.drawLine(
      const Offset(14, 56),
      const Offset(14, 90),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }
}
