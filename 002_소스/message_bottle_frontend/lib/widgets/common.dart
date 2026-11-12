import 'package:flutter/material.dart';

import '../theme.dart';

/// 입력 오류·실패 안내. 비어 있으면 아무것도 그리지 않는다.
class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '⚠ $message',
        style: TextStyle(
          color: AppColors.danger,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 처리 중에는 스피너로 바뀌고 다시 누를 수 없는 버튼(중복 제출 방지).
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.icon,
    this.color,
  });

  final String label;
  final String? busyLabel;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primary;
    final fg = AppColors.on(color);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: fg,
        disabledBackgroundColor: color.withValues(alpha: 0.6),
        disabledForegroundColor: fg,
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
                ),
                if (busyLabel != null) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      busyLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// 확인 대화상자. 바깥을 눌러도 닫히지 않는다.
/// true=오른쪽 버튼(확인), false=왼쪽 버튼(취소), null=Android 뒤로 가기로 그냥 닫음.
Future<bool?> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String cancelLabel,
  required String okLabel,
  bool danger = false,
  IconData? okIcon,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      content: Text(message, style: const TextStyle(height: 1.5)),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? AppColors.danger : AppColors.primary,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (okIcon != null) ...[
                Icon(okIcon, size: 18),
                const SizedBox(width: 6),
              ],
              Text(okLabel),
            ],
          ),
        ),
      ],
    ),
  );
}

/// [showActionDialog]의 결과. 취소했으면 [confirmed]가 false, 실행하다 실패했으면 [error]가 있다.
class ActionOutcome {
  const ActionOutcome({required this.confirmed, this.error});
  final bool confirmed;
  final Object? error;
  bool get succeeded => confirmed && error == null;
}

/// 확인을 누르면 대화상자 안에서 스피너를 보여 주며 [action]을 실행하고, 끝나면 닫는다(예: 편지 버리기).
Future<ActionOutcome> showActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String cancelLabel,
  required String okLabel,
  required Future<void> Function() action,
  bool danger = false,
  IconData? okIcon,
}) async {
  final outcome = await showDialog<ActionOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ActionDialog(
      title: title,
      message: message,
      cancelLabel: cancelLabel,
      okLabel: okLabel,
      action: action,
      danger: danger,
      okIcon: okIcon,
    ),
  );
  return outcome ?? const ActionOutcome(confirmed: false);
}

class _ActionDialog extends StatefulWidget {
  const _ActionDialog({
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.okLabel,
    required this.action,
    required this.danger,
    this.okIcon,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String okLabel;
  final Future<void> Function() action;
  final bool danger;
  final IconData? okIcon;

  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    Object? error;
    try {
      await widget.action();
    } catch (e) {
      error = e;
    }
    if (mounted) {
      Navigator.of(context).pop(ActionOutcome(confirmed: true, error: error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        content: Text(widget.message, style: const TextStyle(height: 1.5)),
        actions: [
          OutlinedButton(
            onPressed: _busy
                ? null
                : () =>
                      Navigator.of(context)
                          .pop(const ActionOutcome(confirmed: false)),
            child: Text(widget.cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: widget.danger
                  ? AppColors.danger
                  : AppColors.primary,
              disabledBackgroundColor:
                  (widget.danger ? AppColors.danger : AppColors.primary)
                      .withValues(alpha: 0.6),
            ),
            onPressed: _busy ? null : _run,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.okIcon != null) ...[
                        Icon(widget.okIcon, size: 18),
                        const SizedBox(width: 6),
                      ],
                      Text(widget.okLabel),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
