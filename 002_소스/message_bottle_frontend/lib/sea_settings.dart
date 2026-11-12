import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api/api_client.dart';
import 'api/api_exception.dart';

/// 파도 종류: 둘 다(잔잔했다 거세졌다 저절로 바뀜), 잔잔, 거센.
enum WaveType {
  both('둘 다'),
  calm('잔잔'),
  rough('거센');

  const WaveType(this.label);
  final String label;
}

/// 바다 색감: 밝은 아침바다, 어두운 밤바다, 또는 기기의 어두운 화면 설정을 따름.
enum SeaTone {
  day('아침바다'),
  night('밤바다'),
  system('기기 설정');

  const SeaTone(this.label);
  final String label;
}

/// 사용자별 화면 설정(바다 색감, 글자 크기, UI 숨김 대기 시간, 파도 종류).
///
/// 서버에 사용자별로 저장한다(GET/PUT /api/users/me/settings). 기기에는 저장하지 않으므로
/// 같은 기기에서 다른 사용자가 로그인해도 앞 사용자의 설정이 따라오지 않는다.
/// 로그인하면 [load]로 불러오고, 로그아웃하면 [reset]으로 기본값으로 돌린다.
class SeaSettings extends ChangeNotifier {
  SeaSettings({ApiClient? client})
    : _client = client; // ignore: prefer_initializing_formals

  static const minIdleSeconds = 1;
  static const maxIdleSeconds = 10;
  static const defaultIdleSeconds = 5;

  /// 글자 크기 단계(배율). 가운데 값 1.0이 기본이다.
  static const textScales = <double>[0.85, 1.0, 1.15, 1.3, 1.4];
  static const textScaleLabels = <String>['작게', '보통', '크게', '더 크게', '가장 크게'];
  static const defaultTextStep = 1;

  static const _path = '/api/users/me/settings';

  /// 서버와 통신할 클라이언트. null이면 이번 실행 동안만 적용한다(테스트).
  final ApiClient? _client;

  /// 서버에 저장하지 못했을 때 부른다(안내 표시용).
  void Function(String message)? onSaveError;

  int _idleSeconds = defaultIdleSeconds;
  WaveType _waveType = WaveType.both;
  SeaTone _tone = SeaTone.day;
  int _textStep = defaultTextStep;
  bool _loaded = false;
  bool _saving = false;
  bool _dirty = false;
  int _session = 0; // 로그아웃(reset) 뒤에 도착한 응답을 버리기 위한 번호

  /// 아무것도 하지 않은 채 이만큼(초) 지나면 바다 화면의 버튼과 안내가 숨는다.
  int get idleSeconds => _idleSeconds;
  WaveType get waveType => _waveType;
  SeaTone get tone => _tone;

  /// 글자 크기 단계(0부터). 배율은 [textScale].
  int get textStep => _textStep;
  double get textScale => textScales[_textStep];
  String get textScaleLabel =>
      '${textScaleLabels[_textStep]} (${(textScale * 100).round()}%)';

  /// 로그인한 사용자의 설정을 서버에서 불러온다. 이미 불러왔으면 다시 부르지 않는다.
  /// 불러오지 못하면 기본값으로 두고, 다음에 다시 시도한다.
  Future<void> load() async {
    final client = _client;
    if (_loaded || client == null) return;
    final session = _session;
    try {
      final json = await client.get(_path);
      if (session != _session || json is! Map<String, dynamic>) return;
      _apply(json);
      _loaded = true;
      notifyListeners();
    } on ApiException {
      // 기본값으로 쓴다.
    }
  }

  /// 로그아웃했을 때: 기본값으로 돌린다(다음 사용자에게 앞 사용자의 설정이 보이지 않게).
  void reset() {
    _session++;
    _loaded = false;
    _dirty = false;
    _idleSeconds = defaultIdleSeconds;
    _waveType = WaveType.both;
    _tone = SeaTone.day;
    _textStep = defaultTextStep;
    notifyListeners();
  }

  void _apply(Map<String, dynamic> json) {
    final idle = json['idleSeconds'];
    final step = json['textStep'];
    final tone = (json['seaTone'] as String?)?.toLowerCase();
    final wave = (json['waveType'] as String?)?.toLowerCase();
    if (idle is int) _idleSeconds = idle.clamp(minIdleSeconds, maxIdleSeconds);
    if (step is int) _textStep = step.clamp(0, textScales.length - 1);
    for (final t in SeaTone.values) {
      if (t.name == tone) _tone = t;
    }
    for (final w in WaveType.values) {
      if (w.name == wave) _waveType = w;
    }
  }

  Map<String, dynamic> _toJson() => {
    'seaTone': _tone.name.toUpperCase(),
    'textStep': _textStep,
    'idleSeconds': _idleSeconds,
    'waveType': _waveType.name.toUpperCase(),
  };

  Future<void> setIdleSeconds(int seconds) async {
    final value = seconds.clamp(minIdleSeconds, maxIdleSeconds);
    if (value == _idleSeconds) return;
    _idleSeconds = value;
    _changed();
  }

  Future<void> setWaveType(WaveType type) async {
    if (type == _waveType) return;
    _waveType = type;
    _changed();
  }

  Future<void> setTone(SeaTone tone) async {
    if (tone == _tone) return;
    _tone = tone;
    _changed();
  }

  Future<void> setTextStep(int step) async {
    final value = step.clamp(0, textScales.length - 1);
    if (value == _textStep) return;
    _textStep = value;
    _changed();
  }

  /// 화면에는 바로 반영하고, 서버에는 뒤에서 저장한다.
  void _changed() {
    notifyListeners();
    unawaited(_push());
  }

  /// 지금 설정 전체를 서버에 보낸다. 보내는 중에 또 바뀌면 끝난 뒤 마지막 값으로 한 번 더 보낸다
  /// (슬라이더를 끄는 동안 요청이 겹치거나 순서가 뒤바뀌지 않게).
  Future<void> _push() async {
    final client = _client;
    if (client == null) return;
    if (_saving) {
      _dirty = true;
      return;
    }
    _saving = true;
    final session = _session;
    try {
      do {
        _dirty = false;
        await client.put(_path, body: _toJson());
      } while (_dirty && session == _session);
    } on ApiException catch (e) {
      if (!e.sessionExpired && session == _session) {
        onSaveError?.call('설정을 서버에 저장하지 못했어요. 다음에 로그인하면 이전 설정으로 보여요.');
      }
    } finally {
      _saving = false;
    }
  }
}
