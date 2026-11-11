import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 화면 맨 아래에 뜨는 안내. 팝업·바텀시트·다이얼로그 위에서도 내용을 가리지 않도록
/// 앱의 Navigator Overlay에 직접 올린다. [visible]을 보면 "편지 쓰기" 버튼이 위로 비켜준다.
class Toast {
  static final ValueNotifier<bool> visible = ValueNotifier(false);
  static OverlayEntry? _entry;

  /// [icon]이 false면 앞의 동그란 아이콘(체크·느낌표) 없이 글자만 보여준다.
  static void show(String message, {bool error = false, bool icon = true}) {
    final overlay = appNavigatorKey.currentState?.overlay;
    if (overlay == null) return;
    hide();
    final entry = OverlayEntry(
      builder: (_) =>
          _ToastView(message: message, error: error, icon: icon, onDone: hide),
    );
    _entry = entry;
    overlay.insert(entry);
    visible.value = true;
  }

  static void hide() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
    visible.value = false;
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.error,
    required this.icon,
    required this.onDone,
  });
  final String message;
  final bool error;
  final bool icon;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  // 자동으로 닫히는 타이머는 안내 위젯이 가진다. 화면이 사라지면 함께 취소된다.
  late final Timer _timer = Timer(
    const Duration(milliseconds: 2800),
    widget.onDone,
  );

  @override
  void initState() {
    super.initState();
    _timer; // 생성 시점에 시작한다
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final error = widget.error;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 20 + bottom,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - t)),
              child: child,
            ),
          ),
          child: Material(
            color: AppColors.card,
            elevation: 8,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: error ? const Color(0xFFE8B9B5) : AppColors.line,
                ),
              ),
              child: Row(
                children: [
                  if (widget.icon) ...[
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: error ? AppColors.danger : AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        error ? Icons.priority_high : Icons.check,
                        size: 16,
                        color: AppColors.on(
                          error ? AppColors.danger : AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 안내가 떠 있는 동안 화면 아래쪽 버튼 줄을 안내 위로 올려 버튼이 가려지지 않게 한다.
class ToastAvoider extends StatelessWidget {
  const ToastAvoider({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Toast.visible,
      builder: (context, shown, child) => AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: shown ? 68 : 0),
        child: child,
      ),
      child: child,
    );
  }
}
