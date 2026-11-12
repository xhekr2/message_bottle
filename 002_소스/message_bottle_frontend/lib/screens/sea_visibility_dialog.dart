import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/toast.dart';

/// 내 바다를 공개/비공개로 바꾸는 작은 설정 창. 서버가 확인한 뒤에만 설정이 바뀐 것으로 보여준다.
/// 공개하면 다른 사람이 내 아이디와 유리병 개수를 볼 수 있고, 편지 내용은 볼 수 없다.
class SeaVisibilityDialog extends StatefulWidget {
  const SeaVisibilityDialog({
    super.key,
    required this.services,
    required this.initialPublic,
    required this.onChanged,
  });

  final AppServices services;
  final bool initialPublic;

  /// 서버에서 바뀐 것이 확인되면 새 값(공개=true)으로 부른다.
  final ValueChanged<bool> onChanged;

  @override
  State<SeaVisibilityDialog> createState() => _SeaVisibilityDialogState();
}

class _SeaVisibilityDialogState extends State<SeaVisibilityDialog> {
  late bool _public = widget.initialPublic;
  bool _busy = false;
  String? _error;

  Future<void> _change(bool value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final confirmed = await widget.services.letters.setSeaPublic(value);
      if (!mounted) return;
      setState(() {
        _public = confirmed;
        _busy = false;
      });
      widget.onChanged(confirmed);
      Toast.show(confirmed ? '바다를 공개했어요.' : '바다를 비공개로 바꿨어요.');
    } on ApiException catch (e) {
      if (!mounted || e.sessionExpired) return;
      setState(() {
        _busy = false;
        _error = e.isNetworkError
            ? '바꾸지 못했습니다. 설정은 그대로예요. 다시 시도해주세요.'
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '내 바다 공개',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const Key('visibility-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '바다 공개하기',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            secondary: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : null,
            value: _public,
            onChanged: _busy ? null : _change,
          ),
          const SizedBox(height: 4),
          Text(
            _public
                ? '지금은 공개 중이에요. 다른 사람이 내 아이디와 떠 있는 유리병 개수를 볼 수 있어요. 편지 내용은 볼 수 없어요.'
                : '지금은 비공개예요. 나만 내 바다를 볼 수 있어요. 공개하면 다른 사람이 내 아이디와 유리병 개수를 볼 수 있어요.',
            key: const Key('visibility-description'),
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
          ErrorText(_error),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('visibility-close'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
