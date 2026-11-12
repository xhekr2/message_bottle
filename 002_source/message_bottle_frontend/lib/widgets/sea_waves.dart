import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

import 'package:flutter/scheduler.dart';

import '../sea_settings.dart';
import 'fishing_rig.dart';

/// 파도 한 겹의 모양과 위치.
class _Layer {
  const _Layer(
    this.color,
    this.baseFromBottom,
    this.amp,
    this.speed,
    this.offset,
  );
  final Color color;
  final double baseFromBottom;
  final double amp; // 이 겹의 높이 배율
  final double speed; // 이 겹의 속도 배율
  final double offset; // 처음 위상 차이(겹마다 다르게 시작)
}

/// 진행 파도 계산(순수 계산). 모든 파도는 왼쪽에서 오른쪽으로만 진행한다.
///
/// 수면 위의 점 하나하나를 파도가 지나가는 모양(Gerstner 파: 마루는 뾰족하고 골은 완만)으로
/// 계산하므로, 높이만 흔드는 것이 아니라 선 모양 자체가 오른쪽으로 이동하면서 바뀐다.
/// 가로 이동량의 합이 절대 1을 넘지 않게 제한해 선이 꺾이거나 겹치지 않는다.
class WaveField {
  WaveField._();

  static const layers = <_Layer>[
    _Layer(Color(0x6B60AAD7), 168, 0.7, 0.8, 0.0),
    _Layer(Color(0x8534869E), 138, 0.85, 0.95, 2.1),
    _Layer(Color(0x9E1B649B), 104, 1.0, 1.1, 4.3),
    _Layer(Color(0xCC145282), 70, 1.15, 1.25, 1.2),
  ];

  /// 파장(픽셀). 긴 파도 하나와 잔물결 둘이 겹친다.
  static const wavelengths = <double>[380, 210, 120];
  static const _speeds = <double>[70, 50, 36]; // 파도가 나아가는 속도(px/초)
  static const _calmAmp = <double>[3.0, 4.0, 3.2];
  static const _roughAmp = <double>[20.0, 10.0, 4.0];

  static int get componentCount => wavelengths.length;
  static int get layerCount => layers.length;

  /// [mood] 0은 잔잔, 1은 거센. 속도는 mood에 따라 1배에서 2.1배까지.
  static double speedFactor(double mood) => 1 + 1.1 * mood;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// [phases]는 겹마다 성분 수만큼의 진행량(라디안)이다. 시간이 지나면 늘어날 뿐 되돌아가지 않는다.
  static List<Offset> points({
    required double width,
    required double height,
    required int layer,
    required List<double> phases,
    required double mood,
    double step = 4,
  }) {
    final spec = layers[layer];
    final n = componentCount;
    final amps = List<double>.generate(
      n,
      (i) => _lerp(_calmAmp[i], _roughAmp[i], mood) * spec.amp,
    );
    final ks = [for (final w in wavelengths) 2 * math.pi / w];
    var sumAk = 0.0;
    for (var i = 0; i < n; i++) {
      sumAk += amps[i] * ks[i];
    }
    // 뾰족함: 잔잔하면 거의 사인파, 거세면 마루가 뾰족. 0.85를 넘지 않으므로 선이 꺾이지 않는다.
    final sharp = _lerp(0.12, 0.8, mood);
    final q = sumAk <= 0 ? 0.0 : sharp / sumAk;
    final base = height - spec.baseFromBottom;
    final out = <Offset>[];
    for (double u = -60; u <= width + 60 + step; u += step) {
      var dx = 0.0;
      var dy = 0.0;
      for (var i = 0; i < n; i++) {
        final theta = ks[i] * u - phases[layer * n + i] - spec.offset;
        dx -= q * amps[i] * math.sin(theta);
        dy += amps[i] * math.cos(theta);
      }
      out.add(Offset(u + dx, base - dy));
    }
    return out;
  }

  /// [points]로 얻은 수면 선에서 가로 위치 [x]의 높이(y).
  static double heightAt(List<Offset> points, double x) {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (b.dx >= x) {
        final span = b.dx - a.dx;
        final t = span <= 0 ? 0.0 : ((x - a.dx) / span).clamp(0.0, 1.0);
        return a.dy + (b.dy - a.dy) * t;
      }
    }
    return points.last.dy;
  }
}

/// 파도의 시간을 흘려 보내는 시계. 파도의 진행량(위상)은 시간에 따라 계속 더해지기만 하고,
/// 잔잔함·거셈이 바뀔 때도 모양이 튀지 않도록 부드럽게 따라간다.
class WaveClock extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  WaveClock({WaveType type = WaveType.both}) : _type = type {
    mood = _targetMood();
  }

  WaveType _type;
  double mood = 0;
  double _modeTime = 0;
  final List<double> phases = List<double>.filled(
    WaveField.layerCount * WaveField.componentCount,
    0,
  );
  Ticker? _ticker;
  Duration _last = Duration.zero;

  WaveType get type => _type;
  set type(WaveType value) {
    if (value == _type) return;
    _type = value;
  }

  void attach(TickerProvider provider) {
    _ticker ??= provider.createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _last = elapsed;
      advance(dt);
    })..start();
  }

  double _targetMood() {
    switch (_type) {
      case WaveType.calm:
        return 0;
      case WaveType.rough:
        return 1;
      case WaveType.both:
        // 약 31초 주기로 잔잔함과 거셈을 오간다(처음은 잔잔).
        final s = 0.5 - 0.5 * math.cos(0.2 * _modeTime);
        final v = ((s - 0.2) / 0.6).clamp(0.0, 1.0);
        return v * v * (3 - 2 * v);
    }
  }

  /// [dt]초만큼 시간을 흘린다(테스트에서도 직접 부른다).
  void advance(double dt) {
    _modeTime += dt;
    mood += (_targetMood() - mood) * (1 - math.exp(-dt * 1.5));
    final n = WaveField.componentCount;
    for (var l = 0; l < WaveField.layerCount; l++) {
      for (var i = 0; i < n; i++) {
        final k = 2 * math.pi / WaveField.wavelengths[i];
        phases[l * n + i] +=
            k *
            WaveField._speeds[i] *
            WaveField.layers[l].speed *
            WaveField.speedFactor(mood) *
            dt;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}

/// 화면 아래쪽에서 오른쪽으로 흘러가는 파도 네 겹.
class SeaWaves extends StatelessWidget {
  const SeaWaves({super.key, required this.clock, this.rig, this.shift});
  final WaveClock clock;

  /// 파도 겹 사이에 함께 그릴 낚싯줄(공유 바다).
  final FishingRig? rig;

  /// 파도를 옆으로 옮겨 그리는 값. 홈 화면에서 화면이 밀리는 만큼을 되돌려 파도를 화면에 고정한다
  /// ([SeaBackdrop.shift]). 낚싯줄은 화면의 UI와 함께 움직이도록 옮기지 않는다.
  final ValueListenable<double>? shift;

  static const height = 230.0;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _WavePainter(clock, rig, shift)),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.clock, this.rig, this.shift)
    : super(repaint: Listenable.merge([clock, rig, shift]));
  final WaveClock clock;
  final FishingRig? rig;
  final ValueListenable<double>? shift;

  @override
  void paint(Canvas canvas, Size size) {
    final dx = shift?.value ?? 0;
    // 파도는 dx만큼 옮겨 화면에 고정하고, 낚싯줄은 이 화면의 자리에 그대로 그린다.
    void withRig(void Function(FishingRig rig) draw) {
      final r = rig;
      if (r == null) return;
      canvas.save();
      canvas.translate(-dx, 0);
      draw(r);
      canvas.restore();
    }

    canvas.save();
    canvas.translate(dx, 0);
    for (var l = 0; l < WaveField.layerCount; l++) {
      // 낚싯줄은 뒤쪽 두 겹과 앞쪽 두 겹 사이에 그려서 물에 잠긴 부분이 가려진다.
      if (l == 2) withRig((r) => r.paintLine(canvas, size));
      final pts = WaveField.points(
        width: size.width,
        height: size.height,
        layer: l,
        phases: clock.phases,
        mood: clock.mood,
      );
      final path = Path()..moveTo(pts.first.dx, size.height);
      for (final p in pts) {
        path.lineTo(p.dx, p.dy);
      }
      path
        ..lineTo(pts.last.dx, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = AppColors.waves[l]);
      // 거셀 때는 마루에 흰 거품 선이 비친다.
      if (l >= 2 && clock.mood > 0.45) {
        final foam = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final p in pts.skip(1)) {
          foam.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          foam,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white.withValues(
              alpha: ((clock.mood - 0.45) / 0.55).clamp(0.0, 1.0) * 0.5,
            ),
        );
      }
      if (l == 2) withRig((r) => r.paintRings(canvas, size));
    }
    withRig((r) => r.paintDrops(canvas, size));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.clock != clock ||
      oldDelegate.rig != rig ||
      oldDelegate.shift != shift;
}
