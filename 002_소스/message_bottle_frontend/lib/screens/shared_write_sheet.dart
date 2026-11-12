import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 공유 바다에 편지를 띄우는 바텀시트. 받는 사람도 익명 선택도 없고 작성자는 언제나 익명이다.
/// 보내기가 서버에서 확인되면 true를 돌려주며 닫힌다. 입력한 내용이 있을 때 취소하면 폐기를 확인한다.
class SharedWriteSheet extends StatefulWidget {
  const SharedWriteSheet({super.key, required this.services});

  final AppServices services;

  @override
  State<SharedWriteSheet> createState() => _SharedWriteSheetState();
}

class _SharedWriteSheetState extends State<SharedWriteSheet> {
  final _content = TextEditingController();
  String? _contentError;
  String? _sendError;
  bool _busy = false;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (_busy) return;
    if (_content.text.trim().isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    final discard = await confirmDialog(
      context,
      title: '작성 중인 편지를 버릴까요?',
      message: '지금까지 쓴 내용이 지워집니다.',
      cancelLabel: '계속 작성',
      okLabel: '버리기',
      danger: true,
    );
    if (discard == true && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _contentError = _content.text.trim().isEmpty ? '편지 내용을 입력해주세요.' : null;
      _sendError = null;
    });
    if (_contentError != null) return;
    setState(() => _busy = true);
    try {
      await widget.services.letters.writeShared(_content.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sendError = e.isNetworkError
            ? '띄우지 못했습니다. 입력한 내용은 그대로 있어요. 다시 시도해주세요.'
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 뒤로 가기·바깥 터치는 취소와 같다
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '공유 바다에 편지 띄우기',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                '익명으로 모두의 바다에 띄워요. 누군가 낚아서 답장하면 그 답장이 내 바다로 도착해요.',
                key: Key('shared-write-note'),
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('shared-write-content'),
                controller: _content,
                enabled: !_busy,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '편지 내용',
                  hintText: '누군가에게 닿길 바라는 이야기를 적어 보세요',
                  alignLabelWithHint: true,
                ),
              ),
              ErrorText(_contentError),
              ErrorText(_sendError),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: OutlinedButton(
                      key: const Key('shared-write-cancel'),
                      onPressed: _busy ? null : _cancel,
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BusyButton(
                      key: const Key('shared-write-send'),
                      label: '띄우기',
                      busyLabel: '띄우는 중…',
                      icon: Icons.send,
                      busy: _busy,
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
