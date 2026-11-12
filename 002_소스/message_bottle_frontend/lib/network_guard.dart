import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_services.dart';
import 'theme.dart';
import 'widgets/toast.dart';

const _networkChannel = MethodChannel('message_bottle/network');

/// 기기에 네트워크 연결(Wi-Fi·데이터)이 하나도 없으면 true.
/// 서버만 꺼져 있고 기기는 연결돼 있는 경우는 false다(그때는 각 화면의 "다시 시도"가 안내한다).
/// Android에서는 기기의 연결 상태를 직접 묻고(MainActivity.kt), 그 밖에서는 네트워크 장치가 있는지로 판단한다.
Future<bool> deviceOffline() async {
  try {
    final online = await _networkChannel.invokeMethod<bool>('isOnline');
    if (online != null) return !online;
  } on MissingPluginException {
    // Android가 아닌 곳: 아래 방법으로 판단한다.
  } on PlatformException {
    return false;
  }
  try {
    final interfaces = await NetworkInterface.list();
    return interfaces.isEmpty;
  } catch (_) {
    return false;
  }
}

/// 앱을 종료한다.
void exitApplication() {
  SystemNavigator.pop();
}

/// 네트워크가 끊기면 안내 창을 띄운다. 확인을 누르면 앱을 종료한다.
/// 단, 바다에서 연 편지가 열려 있는 동안에는 종료하지 않고 "다시 시도"만 보여 준다
/// (앱이 종료되면 열어 둔 편지가 버려지기 때문이다).
class NetworkGuard extends StatefulWidget {
  const NetworkGuard({
    super.key,
    required this.services,
    required this.child,
    this.interval = const Duration(seconds: 3),
  });

  final AppServices services;
  final Widget child;
  final Duration interval;

  @override
  State<NetworkGuard> createState() => _NetworkGuardState();
}

class _NetworkGuardState extends State<NetworkGuard> {
  Timer? _timer;
  bool _checking = false;
  bool _showing = false;
  final ValueNotifier<bool> _offline = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    if (widget.services.offlineProbe == null) return;
    widget.services.client.onNetworkError = _check;
    _timer = Timer.periodic(widget.interval, (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.services.client.onNetworkError == _check) {
      widget.services.client.onNetworkError = null;
    }
    _offline.dispose();
    super.dispose();
  }

  Future<bool> _probe() async {
    final probe = widget.services.offlineProbe;
    if (probe == null) return false;
    try {
      return await probe();
    } catch (_) {
      return false;
    }
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    final offline = await _probe();
    _checking = false;
    if (!mounted) return;
    _offline.value = offline;
    if (offline && !_showing) _show();
  }

  Future<void> _show() async {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    _showing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OfflineDialog(
        keepLetter: widget.services.letterOpen.value,
        offline: _offline,
        probe: _probe,
        onExit: widget.services.exitApp ?? exitApplication,
      ),
    );
    _showing = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _OfflineDialog extends StatefulWidget {
  const _OfflineDialog({
    required this.keepLetter,
    required this.offline,
    required this.probe,
    required this.onExit,
  });

  /// 편지를 열어 둔 상태라 종료하지 않고 다시 시도하게 한다.
  final bool keepLetter;
  final ValueNotifier<bool> offline;
  final Future<bool> Function() probe;
  final VoidCallback onExit;

  @override
  State<_OfflineDialog> createState() => _OfflineDialogState();
}

class _OfflineDialogState extends State<_OfflineDialog> {
  bool _busy = false;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    widget.offline.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.offline.removeListener(_onChanged);
    super.dispose();
  }

  /// 편지를 열어 둔 경우에는 연결이 돌아오면 창을 저절로 닫는다.
  void _onChanged() {
    if (widget.keepLetter && !widget.offline.value && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _still = false;
    });
    final offline = await widget.probe();
    if (!mounted) return;
    if (offline) {
      setState(() {
        _busy = false;
        _still = true;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('offline-dialog'),
        icon: Icon(Icons.wifi_off, color: AppColors.danger, size: 36),
        title: const Text(
          '네트워크에 연결할 수 없어요',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.keepLetter
                  ? '열어 둔 편지는 그대로 있어요. 앱을 종료하지 않으니, 연결을 확인한 뒤 다시 시도해 주세요.'
                  : 'Wi-Fi나 데이터 연결을 확인한 뒤 앱을 다시 실행해 주세요. 확인을 누르면 앱을 종료합니다.',
              style: const TextStyle(height: 1.5),
            ),
            if (_still)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '아직 연결되지 않았어요.',
                  key: const Key('offline-still'),
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: widget.keepLetter
                ? FilledButton(
                    key: const Key('offline-retry'),
                    onPressed: _busy ? null : _retry,
                    child: const Text('다시 시도'),
                  )
                : FilledButton(
                    key: const Key('offline-exit'),
                    onPressed: widget.onExit,
                    child: const Text('확인 (앱 종료)'),
                  ),
          ),
        ],
      ),
    );
  }
}
