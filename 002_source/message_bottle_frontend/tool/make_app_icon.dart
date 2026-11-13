// 앱 아이콘을 그려서 Android·iOS 리소스 폴더에 PNG로 저장한다.
// 앱의 유리병 그림(paintBottle)을 그대로 써서 화면 속 유리병과 같은 모양이다.
//
// 실행: flutter test tool/make_app_icon.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:message_bottle_frontend/widgets/bottle_icon.dart';

enum Layer { full, background, foreground }

const _skyTop = Color(0xFFCBE9F7);
const _skyBottom = Color(0xFF8CC6E8);
const _waveBack = Color(0xFF5AA5D6);
const _waveFront = Color(0xFF2F7FB8);
const _deep = Color(0xFF0B5FA5);

/// 물결 모양으로 위가 출렁이고 아래는 끝까지 채운 면.
Path _wave(Rect frame, double top, double amp, double length, double phase) {
  final path = Path();
  final from = frame.left - frame.width, to = frame.right + frame.width;
  for (var x = from; x <= to; x += frame.width / 64) {
    final y =
        frame.top +
        frame.height *
            (top +
                amp *
                    math.sin(
                      2 * math.pi * (x - frame.left) / (frame.width * length) +
                          phase,
                    ));
    x == from ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  return path
    ..lineTo(to, frame.bottom + frame.height)
    ..lineTo(from, frame.bottom + frame.height)
    ..close();
}

/// 한 변이 [size]인 정사각형에 아이콘을 그린다. [frame]은 그림의 기준 틀로,
/// Android 적응형 아이콘에서는 가운데 72/108만 보이므로 그만큼 안쪽으로 잡는다.
void paintAppIcon(Canvas canvas, double size, Layer layer) {
  final adaptive = layer != Layer.full;
  final inset = adaptive ? size * 18 / 108 : 0.0;
  final frame = Rect.fromLTWH(inset, inset, size - inset * 2, size - inset * 2);
  final all = Rect.fromLTWH(0, 0, size, size);
  canvas.clipRect(all);

  if (layer != Layer.foreground) {
    canvas.drawRect(
      all,
      Paint()
        ..shader = ui.Gradient.linear(
          frame.topCenter,
          frame.bottomCenter,
          const [_skyTop, _skyBottom],
        ),
    );
    canvas.drawPath(
      _wave(frame, 0.60, 0.022, 0.62, 0.6),
      Paint()..color = _waveBack,
    );
  }

  if (layer != Layer.background) {
    // 살짝 기울어 물에 떠 있는 유리병.
    final h = frame.height * 0.74, w = h * 60 / 110;
    canvas.save();
    canvas.translate(frame.center.dx, frame.top + frame.height * 0.46);
    canvas.rotate(16 * math.pi / 180);
    canvas.translate(-w / 2, -h / 2);
    paintBottle(canvas, Size(w, h));
    canvas.restore();

    // 유리병 아래쪽을 덮는 앞쪽 파도.
    final front = _wave(frame, 0.735, 0.026, 0.8, 2.4);
    canvas.drawPath(
      front,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, frame.top + frame.height * 0.70),
          Offset(0, frame.bottom),
          const [_waveFront, _deep],
        ),
    );
    // 물마루의 흰 선.
    canvas.drawPath(
      front,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = frame.width * 0.012
        ..color = Colors.white.withValues(alpha: 0.75),
    );
  }
}

Future<void> _save(String path, int size, Layer layer) async {
  final recorder = ui.PictureRecorder();
  paintAppIcon(Canvas(recorder), size.toDouble(), layer);
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('앱 아이콘을 그려 저장한다', (tester) async {
    await tester.runAsync(() async {
      // Android: 예전 방식 아이콘(48dp)과 적응형 아이콘의 두 겹(108dp).
      const densities = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      };
      const res = 'android/app/src/main/res';
      for (final MapEntry(key: name, value: scale) in densities.entries) {
        final dir = '$res/mipmap-$name';
        await _save('$dir/ic_launcher.png', (48 * scale).round(), Layer.full);
        await _save(
          '$dir/ic_launcher_background.png',
          (108 * scale).round(),
          Layer.background,
        );
        await _save(
          '$dir/ic_launcher_foreground.png',
          (108 * scale).round(),
          Layer.foreground,
        );
      }

      // iOS: 아이콘 세트에 있는 파일 이름(Icon-App-60x60@3x.png)에서 크기를 읽는다.
      final set = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      final name = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png$');
      for (final file in set.listSync().whereType<File>()) {
        final m = name.firstMatch(file.path);
        if (m == null) continue;
        final px = (double.parse(m[1]!) * int.parse(m[2]!)).round();
        await _save(file.path, px, Layer.full);
      }

      // 눈으로 확인할 큰 그림.
      await _save('build/app_icon_preview.png', 512, Layer.full);
    });
  });
}
