import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../theme.dart';
import '../widgets/bottle_icon.dart';
import 'login_screen.dart';
import 'home_screen.dart';

/// 앱 시작 시 저장된 세션을 확인한다. 서버가 리프레시 토큰을 거부하면 로그인으로,
/// 서버에 닿지 못하면 로그아웃으로 처리하지 않고 다시 시도할 수 있게 한다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _error = null);
    try {
      final loggedIn = await widget.services.auth.refresh();
      // 로그인돼 있으면 이 사용자의 화면 설정을 불러온 뒤에 바다로 들어간다.
      if (loggedIn) await widget.services.settings.load();
      if (!mounted) return;
      _go(
        loggedIn
            ? HomeScreen(services: widget.services)
            : LoginScreen(services: widget.services),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  void _go(Widget screen) {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.seaTop, AppColors.background],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BottleIcon(width: 56, height: 100),
                const SizedBox(height: 12),
                const Text(
                  'Message Bottle',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                if (_error == null)
                  const CircularProgressIndicator()
                else ...[
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _check, child: const Text('다시 시도')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
