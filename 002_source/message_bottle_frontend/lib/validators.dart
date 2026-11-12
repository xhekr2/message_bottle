/// Mirrors the server-side signup rules (the server still validates).
final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9]{4,20}$');
final RegExp _passwordPattern = RegExp(r'^[\x21-\x7E]{8,20}$');

String? validateUsername(String? value) {
  if (value == null || value.isEmpty) return '아이디를 입력해주세요.';
  if (!_usernamePattern.hasMatch(value)) {
    return '아이디는 영문, 숫자만 사용하여 4~20자로 입력해주세요.';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return '비밀번호를 입력해주세요.';
  if (!_passwordPattern.hasMatch(value)) {
    return '비밀번호는 영문, 숫자, 특수기호만 사용하여 8~20자로 입력해주세요.';
  }
  return null;
}
