import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'bottle_icon.dart';
import 'sea_waves.dart';

/// 낚시의 진행 단계.
enum FishingPhase {
  /// 낚싯줄이 없다.
  idle,

  /// 낚싯줄이 내려와 물에 닿는다.
  cast,

  /// 찌가 파도를 따라 흔들린다(서버 응답을 기다리는 동안).
  wait,

  /// 찌가 두 번 쑥 들어간다.
  bite,

  /// 유리병(또는 빈 바늘)이 올라온다.
  reel,

  /// 올라온 뒤 잠깐 매달려 흔들린다.
  hold,

  /// 유리병이 매달린 채 편지가 열리기를 기다린다.
  held,

  /// 빈 줄이 위로 사라진다.
  retract,
}

class _Drop {
  _Drop(this.x, this.y, this.vx, this.vy, this.life, this.r);
  double x, y, vx, vy, life;
  final double r;
}

class _Ring {
  _Ring(this.size);
  double age = 0;
  final double size;
}

/// 공유 바다의 "유리병 낚기" 움직임. 파도 그림([SeaWaves])이 파도 겹 사이에 그려 주므로
/// 물에 잠긴 부분은 앞쪽 파도에 가려진다. 좌표는 파도 상자(높이 [SeaWaves.height]) 기준이며
/// 상자 위쪽(하늘)은 음수 y다.
///
/// 쓰는 순서: [start] → (서버 응답) → [finish] → 편지를 열었거나 끝났으면 [reset].
class FishingRig extends ChangeNotifier {
  FishingRig(this.clock);

  final WaveClock clock;

  static const castSeconds = 0.5;
  static const waitMinSeconds = 0.9;
  static const biteSeconds = 0.45;
  static const reelSeconds = 0.9;
  static const holdSeconds = 0.5;
  static const emptyReelSeconds = 0.6;
  static const emptyHoldSeconds = 0.35;
  static const retractSeconds = 0.35;

  /// 올라온 유리병의 마개 위치(화면 높이에 대한 비율).
  static const bottleTopFraction = 0.32;
  static const _emptyTopFraction = 0.42;
  static const _layer = 2; // 찌가 떠 있는 파도 겹
  static const _hang = 46.0; // 찌에서 바늘까지의 줄 길이

  /// 파도 상자 위쪽의 화면 높이(화면 높이 - 파도 상자 높이).
  double skyHeight = 600;

  /// 화면 아래에 보여 줄 안내("낚는 중…", "뭔가 걸렸어요!"). 없으면 빈 글자.
  final ValueNotifier<String> status = ValueNotifier<String>('');

  FishingPhase get phase => _phase;
  FishingPhase _phase = FishingPhase.idle;
  double _pt = 0; // 이 단계에서 흐른 시간(초)
  double _swing = 0; // 물 밖으로 나온 뒤 흐른 시간(초)
  double _time = 0; // 낚시를 시작한 뒤 흐른 시간(초)
  bool? _caught;
  Completer<void>? _done;
  bool _disposed = false;

  final List<_Drop> _drops = [];
  final List<_Ring> _rings = [];
  final math.Random _random = math.Random(7);
  double _x = 195; // 마지막으로 그린 가운데 x
  double _surface = 126; // 마지막으로 그린 수면 y

  Ticker? _ticker;
  Duration _last = Duration.zero;

  void attach(TickerProvider provider) {
    _ticker ??= provider.createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.25);
      _last = elapsed;
      advance(dt);
    });
  }

  /// 낚싯줄을 던진다. 결과는 [finish]로 알려 준다.
  void start() {
    if (_disposed) return;
    _finishWaiters();
    _drops.clear();
    _rings.clear();
    _caught = null;
    _time = 0;
    _swing = 0;
    _enter(FishingPhase.cast);
    status.value = '낚는 중…';
    _last = Duration.zero;
    final ticker = _ticker;
    if (ticker != null && !ticker.isActive) ticker.start();
    notifyListeners();
  }

  /// 서버의 답을 알려 준다. 편지가 낚였으면([caught]) 유리병이 올라와 매달릴 때까지,
  /// 아니면 빈 바늘이 올라왔다가 줄이 사라질 때까지 기다리는 Future를 돌려준다.
  Future<void> finish({required bool caught}) {
    if (_disposed || _phase == FishingPhase.idle) return Future<void>.value();
    _caught = caught;
    return (_done ??= Completer<void>()).future;
  }

  /// 낚싯줄을 바로 치운다.
  void reset() {
    if (_disposed) return;
    _finishWaiters();
    _drops.clear();
    _rings.clear();
    _caught = null;
    _phase = FishingPhase.idle;
    status.value = '';
    _ticker?.stop();
    notifyListeners();
  }

  void _finishWaiters() {
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  void _enter(FishingPhase phase) {
    _phase = phase;
    _pt = 0;
  }

  /// [dt]초만큼 진행한다(테스트에서도 직접 부른다).
  void advance(double dt) {
    if (_disposed || _phase == FishingPhase.idle) return;
    var left = dt;
    while (left > 0) {
      final h = math.min(left, 0.016);
      _step(h);
      left -= h;
    }
    notifyListeners();
  }

  void _splash(int count, double power) {
    for (var i = 0; i < count; i++) {
      final a = -math.pi / 2 + (_random.nextDouble() - 0.5) * 1.5;
      final v = power * (0.5 + _random.nextDouble() * 0.7);
      _drops.add(
        _Drop(
          _x,
          _surface,
          math.cos(a) * v,
          math.sin(a) * v,
          0.7,
          1.5 + _random.nextDouble() * 1.8,
        ),
      );
    }
  }

  void _step(double dt) {
    _pt += dt;
    _time += dt;
    switch (_phase) {
      case FishingPhase.cast:
        if (_pt >= castSeconds) {
          _splash(9, 150);
          _rings.add(_Ring(1));
          _enter(FishingPhase.wait);
        }
      case FishingPhase.wait:
        if ((_pt / 1.1).floor() != ((_pt - dt) / 1.1).floor()) {
          _rings.add(_Ring(0.6));
        }
        final caught = _caught;
        if (caught != null && _pt >= waitMinSeconds) {
          _rings.add(_Ring(0.8));
          if (caught) {
            _enter(FishingPhase.bite);
            status.value = '뭔가 걸렸어요!';
          } else {
            _splash(5, 110);
            _swing = 0;
            _enter(FishingPhase.reel);
            status.value = '';
          }
        }
      case FishingPhase.bite:
        if (_pt - dt < biteSeconds / 2 && _pt >= biteSeconds / 2) {
          _rings.add(_Ring(0.8));
        }
        if (_pt >= biteSeconds) {
          _splash(16, 230);
          _rings.add(_Ring(1.4));
          _swing = 0;
          _enter(FishingPhase.reel);
          status.value = '';
        }
      case FishingPhase.reel:
        _swing += dt;
        final caught = _caught ?? false;
        // 올라오는 동안 물방울이 떨어진다.
        if (_random.nextDouble() < dt * (caught ? 26 : 12)) {
          final hook = _hook();
          _drops.add(
            _Drop(
              hook.dx + (_random.nextDouble() - 0.5) * (caught ? 30 : 8),
              hook.dy + (caught ? 92 : 18),
              0,
              30,
              0.8,
              1.4 + _random.nextDouble() * 1.4,
            ),
          );
        }
        if (_pt >= (caught ? reelSeconds : emptyReelSeconds)) {
          _enter(FishingPhase.hold);
        }
      case FishingPhase.hold:
        _swing += dt;
        if (_caught ?? false) {
          if (_pt >= holdSeconds) {
            _enter(FishingPhase.held);
            _finishWaiters();
          }
        } else if (_pt >= emptyHoldSeconds) {
          _enter(FishingPhase.retract);
        }
      case FishingPhase.held:
        _swing += dt;
      case FishingPhase.retract:
        if (_pt >= retractSeconds) {
          _phase = FishingPhase.idle;
          _drops.clear();
          _rings.clear();
          _ticker?.stop();
          _finishWaiters();
        }
      case FishingPhase.idle:
        break;
    }
    for (final d in _drops) {
      d.vy += 620 * dt;
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.life -= dt;
    }
    _drops.removeWhere((d) => d.life <= 0 || d.y > SeaWaves.height);
    for (final r in _rings) {
      r.age += dt;
    }
    _rings.removeWhere((r) => r.age >= 1.3);
  }

  double get _screenHeight => skyHeight + SeaWaves.height;

  double _topY(double fraction) => fraction * _screenHeight - skyHeight;

  double get _swingAngle =>
      0.38 * math.sin(_swing * 6.2) * math.exp(-1.9 * _swing);

  /// 바늘(줄 끝)의 위치.
  Offset _hook() {
    final rest = _surface + _hang;
    switch (_phase) {
      case FishingPhase.cast:
        final p = (_pt / castSeconds).clamp(0.0, 1.0);
        final from = -skyHeight - 30;
        return Offset(_x, from + (rest - from) * p * p);
      case FishingPhase.wait:
        return Offset(_x, rest);
      case FishingPhase.bite:
        final p = (_pt / biteSeconds).clamp(0.0, 1.0);
        return Offset(_x, rest + 16 * math.sin(p * math.pi * 2).abs());
      case FishingPhase.reel:
      case FishingPhase.hold:
      case FishingPhase.held:
        final caught = _caught ?? false;
        final top = _topY(caught ? bottleTopFraction : _emptyTopFraction);
        final p = _phase == FishingPhase.reel
            ? (_pt / (caught ? reelSeconds : emptyReelSeconds)).clamp(0.0, 1.0)
            : 1.0;
        final q = 1 - math.pow(1 - p, 3).toDouble();
        final sway = 5 * math.sin(_swing * 6.2) * math.exp(-1.9 * _swing);
        return Offset(_x + sway, rest + (top - rest) * q);
      case FishingPhase.retract:
        final p = (_pt / retractSeconds).clamp(0.0, 1.0);
        final from = _topY(_emptyTopFraction);
        return Offset(_x, from + (-skyHeight - 60 - from) * p * p);
      case FishingPhase.idle:
        return Offset(_x, rest);
    }
  }

  bool get _showsBottle =>
      (_caught ?? false) &&
      (_phase == FishingPhase.reel ||
          _phase == FishingPhase.hold ||
          _phase == FishingPhase.held);

  /// 뒤쪽 파도 두 겹을 그린 뒤에 부른다: 낚싯줄, 찌, 유리병(또는 바늘).
  void paintLine(Canvas canvas, Size size) {
    _x = size.width / 2;
    _surface = WaveField.heightAt(
      WaveField.points(
        width: size.width,
        height: size.height,
        layer: _layer,
        phases: clock.phases,
        mood: clock.mood,
      ),
      _x,
    );
    if (_phase == FishingPhase.idle) return;
    final hook = _hook();
    final float = Offset(hook.dx, hook.dy - _hang);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.95);
    final top = -skyHeight - 10;
    final slack = _phase == FishingPhase.wait
        ? 10 * math.sin(_time * 1.4)
        : 0.0;
    canvas.drawPath(
      Path()
        ..moveTo(_x, top)
        ..quadraticBezierTo(
          _x + slack,
          (top + float.dy) / 2,
          float.dx,
          float.dy - 14,
        ),
      line,
    );
    canvas.drawLine(float, hook, line);

    // 찌: 위는 빨강, 아래는 흰색.
    canvas.drawCircle(float, 7, Paint()..color = Colors.white);
    canvas.drawArc(
      Rect.fromCircle(center: float, radius: 7),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFE2513F),
    );
    canvas.drawLine(
      float.translate(0, -7),
      float.translate(0, -14),
      Paint()
        ..strokeWidth = 1.6
        ..color = const Color(0xFF4A5A68),
    );

    canvas.save();
    canvas.translate(hook.dx, hook.dy);
    final swinging =
        _phase == FishingPhase.reel ||
        _phase == FishingPhase.hold ||
        _phase == FishingPhase.held;
    // 눌러 주기를 기다리는 동안에는 유리병 둘레에서 빛 고리가 퍼져 눈에 띄게 한다.
    if (_phase == FishingPhase.held) {
      for (var i = 0; i < 2; i++) {
        final p = ((_pt / 1.4) + i * 0.5) % 1.0;
        canvas.drawCircle(
          const Offset(0, 48),
          44 + 26 * p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - p) + 0.5
            ..color = Colors.white.withValues(alpha: 0.75 * (1 - p)),
        );
      }
    }
    if (swinging) canvas.rotate(_swingAngle);
    if (_showsBottle) {
      canvas.scale(0.86);
      canvas.translate(-30, -1);
      paintBottle(canvas, const Size(60, 110));
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(0, 12)
          ..arcTo(
            Rect.fromCircle(center: const Offset(-6, 12), radius: 6),
            0,
            math.pi * 0.95,
            false,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF4A5A68),
      );
    }
    canvas.restore();
  }

  /// 찌가 떠 있는 파도 겹을 그린 뒤에 부른다: 수면에 번지는 물결.
  void paintRings(Canvas canvas, Size size) {
    for (final r in _rings) {
      final p = r.age / 1.3;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_x, _surface + 2),
          width: (10 + 46 * p) * r.size * 2,
          height: (3 + 12 * p) * r.size * 2,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.8 * (1 - p)),
      );
    }
  }

  /// 모든 파도를 그린 뒤에 부른다: 튀는 물방울.
  void paintDrops(Canvas canvas, Size size) {
    for (final d in _drops) {
      canvas.drawCircle(
        Offset(d.x, d.y),
        d.r,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.9 * (d.life * 2.5).clamp(0.0, 1.0),
          ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _finishWaiters();
    _ticker?.dispose();
    status.dispose();
    super.dispose();
  }
}
