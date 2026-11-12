import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_services.dart';
import 'network_guard.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'sea_settings.dart';
import 'theme.dart';
import 'widgets/toast.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = AppServices.create(
    offlineProbe: deviceOffline,
    exitApp: exitApplication,
  );
  runApp(MessageBottleApp(services: services));
}

/// 글자 크기 배율의 상한. 기기의 글자 크기 설정과 앱 설정을 곱한 값이 이보다 커지지 않게 한다.
const double kMaxTextScale = 1.4;

class MessageBottleApp extends StatefulWidget {
  const MessageBottleApp({super.key, required this.services, this.home});

  final AppServices services;

  /// 첫 화면. 주지 않으면 [SplashScreen]으로 시작한다(테스트에서 바꾼다).
  final Widget? home;

  @override
  State<MessageBottleApp> createState() => _MessageBottleAppState();
}

class _MessageBottleAppState extends State<MessageBottleApp>
    with WidgetsBindingObserver {
  bool _sessionEnding = false;

  SeaSettings get _settings => widget.services.settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 토큰 갱신까지 거부되면(예외 상황) 로그인 화면으로 보낸다.
    widget.services.client.onSessionExpired = _onSessionExpired;
    AppColors.current = _palette();
    _settings.addListener(_onSettings);
    _settings.onSaveError = (message) => Toast.show(message, error: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettings);
    _settings.onSaveError = null;
    AppColors.current = AppPalette.day;
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _onSettings();

  /// 설정한 바다 색감에 맞는 색 모음. "기기 설정"이면 기기의 어두운 화면 설정을 따른다.
  AppPalette _palette() {
    final night = switch (_settings.tone) {
      SeaTone.day => false,
      SeaTone.night => true,
      SeaTone.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    return night ? AppPalette.dark : AppPalette.day;
  }

  void _onSettings() {
    if (!mounted) return;
    final palette = _palette();
    final toneChanged = palette != AppColors.current;
    setState(() => AppColors.current = palette);
    if (toneChanged) _rebuildAll();
  }

  /// 색은 화면 곳곳에서 [AppColors]로 바로 읽으므로, 색감이 바뀌면 떠 있는 화면을 모두 다시 그린다.
  void _rebuildAll() {
    void visit(Element element) {
      element.markNeedsBuild();
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  void _onSessionExpired() {
    if (_sessionEnding) return;
    _sessionEnding = true;
    widget.services.drafts.clear();
    _settings.reset(); // 다음 사용자에게 이 사용자의 설정이 보이지 않게
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(services: widget.services),
      ),
      (_) => false,
    );
    Toast.show('로그인이 만료되었습니다. 다시 로그인해주세요.', error: true);
    Future<void>.delayed(
      const Duration(seconds: 1),
      () => _sessionEnding = false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Message Bottle',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: buildTheme(AppColors.current),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final system = media.textScaler.scale(100) / 100;
        final scale = math.min(kMaxTextScale, system * _settings.textScale);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: NetworkGuard(
            services: widget.services,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: widget.home ?? SplashScreen(services: widget.services),
    );
  }
}
