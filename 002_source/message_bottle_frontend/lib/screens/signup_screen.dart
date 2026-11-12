import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../theme.dart';
import '../validators.dart';
import '../widgets/common.dart';

/// 회원가입. 가입이 서버에서 확인되면 만든 아이디를 돌려주며 닫힌다.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _usernameError; // 서버가 알려준 중복 오류
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _usernameError = null;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.services.auth.signup(_username.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pop(_username.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (e.statusCode == 409) {
          _usernameError = e.message;
        } else {
          _error = e.isNetworkError
              ? '${e.message} 입력한 내용은 그대로 있어요.'
              : e.message;
        }
      });
      _formKey.currentState!.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment(0, -0.3),
            colors: [AppColors.seaTop, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 28, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: '로그인으로 돌아가기',
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '회원가입',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _username,
                              enabled: !_loading,
                              decoration: const InputDecoration(
                                labelText: '아이디',
                                helperText: '영문, 숫자 4~20자 (대소문자 구분)',
                              ),
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  _usernameError ?? validateUsername(v),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              enabled: !_loading,
                              decoration: const InputDecoration(
                                labelText: '비밀번호',
                                helperText: '영문, 숫자, 특수기호 8~20자',
                              ),
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: validatePassword,
                            ),
                            ErrorText(_error),
                            const SizedBox(height: 22),
                            BusyButton(
                              label: '가입하기',
                              busyLabel: '가입하는 중…',
                              onPressed: _submit,
                              busy: _loading,
                            ),
                          ],
                        ),
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
