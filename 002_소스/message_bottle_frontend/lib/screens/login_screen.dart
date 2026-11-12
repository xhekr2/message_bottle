import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../theme.dart';
import '../widgets/bottle_icon.dart';
import '../widgets/common.dart';
import '../widgets/toast.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

/// S00 로그인.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.services, this.initialUsername});

  final AppServices services;
  final String? initialUsername;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username = TextEditingController(
    text: widget.initialUsername,
  );
  final _password = TextEditingController();
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _bob.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.services.auth.login(_username.text, _password.text);
      // 이 사용자의 화면 설정(색감·글자 크기 등)을 불러온 뒤에 바다로 들어간다.
      await widget.services.settings.load();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(services: widget.services),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _openSignUp() async {
    final username = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => SignUpScreen(services: widget.services),
      ),
    );
    if (username != null && mounted) {
      setState(() => _username.text = username);
      _password.clear();
      Toast.show('가입이 완료되었습니다. 로그인해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment(0, 0.1),
            colors: [AppColors.seaTop, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedBuilder(
                        animation: _bob,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, -8 * _bob.value),
                          child: child,
                        ),
                        child: const Center(
                          child: BottleIcon(width: 64, height: 110),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Message Bottle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '유리병에 담아 보내는 편지',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _username,
                        enabled: !_loading,
                        decoration: const InputDecoration(labelText: '아이디'),
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? '아이디를 입력해주세요.' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        enabled: !_loading,
                        decoration: const InputDecoration(labelText: '비밀번호'),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? '비밀번호를 입력해주세요.' : null,
                      ),
                      ErrorText(_error),
                      const SizedBox(height: 22),
                      BusyButton(
                        label: '로그인',
                        onPressed: _submit,
                        busy: _loading,
                      ),
                      TextButton(
                        onPressed: _loading ? null : _openSignUp,
                        child: const Text('계정이 없나요? 회원가입'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
