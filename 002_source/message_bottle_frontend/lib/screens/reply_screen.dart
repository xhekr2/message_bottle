import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/toast.dart';

/// S06 답장 쓰기. 돌아가기(Android 뒤로 가기 포함)를 누르면 쓰던 내용을 임시 저장하고 원본 편지로 돌아간다.
/// 보내기가 서버에서 확인되면 true를 돌려주며 닫힌다(원본은 서버에서 자동 보관된다).
class ReplyScreen extends StatefulWidget {
  const ReplyScreen({
    super.key,
    required this.services,
    required this.letter,
    this.initialText,
    this.title,
    this.sendReply,
    this.successMessage,
    this.goneMessage,
    this.persistDraft = true,
  });

  final AppServices services;
  final DetailData letter;

  /// 임시 저장한 답장을 불러온 경우의 내용. null이면 새로 쓴다.
  final String? initialText;

  /// 공유 바다에서 낚은 편지에 답장할 때 쓰는 설정. 기본값은 바다에서 받은 편지에 답장하는 동작이다.
  final String? title;
  final Future<void> Function(String text)? sendReply;
  final String? successMessage;
  final String? goneMessage;

  /// false면 돌아갈 때 임시 저장하지 않는다(내용이 있으면 버릴지 묻는다).
  final bool persistDraft;

  @override
  State<ReplyScreen> createState() => _ReplyScreenState();
}

class _ReplyScreenState extends State<ReplyScreen> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialText,
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// 돌아가기: 내용이 있으면 임시 저장, 비어 있으면 저장하지 않는다.
  Future<void> _leave() async {
    if (_busy) return;
    if (!widget.persistDraft) {
      if (_text.text.trim().isNotEmpty) {
        final discard = await confirmDialog(
          context,
          title: '작성 중인 답장을 버릴까요?',
          message: '지금까지 쓴 내용이 지워집니다.',
          cancelLabel: '계속 작성',
          okLabel: '버리기',
          danger: true,
        );
        if (discard != true || !mounted) return;
      }
      Navigator.of(context).pop(false);
      return;
    }
    final drafts = widget.services.drafts;
    if (_text.text.trim().isNotEmpty) {
      drafts.save(widget.letter.id, _text.text);
      Toast.show('작성한 답장을 임시 저장했어요.');
    } else {
      drafts.remove(widget.letter.id);
    }
    Navigator.of(context).pop(false);
  }

  Future<void> _send() async {
    if (_busy) return;
    if (_text.text.trim().isEmpty) {
      setState(() => _error = '답장 내용을 입력해주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final send = widget.sendReply;
      if (send != null) {
        await send(_text.text);
      } else {
        await widget.services.letters.reply(widget.letter.id, _text.text);
      }
      widget.services.drafts.remove(widget.letter.id);
      Toast.show(widget.successMessage ?? '답장을 보냈어요. 원래 편지는 받은 편지함에 보관했어요.');
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isNotFound) {
        widget.services.drafts.remove(widget.letter.id);
        Toast.show(widget.goneMessage ?? '이미 사라진 편지입니다.', error: true);
        Navigator.of(context).pop(true); // 바다를 다시 불러오게 한다
        return;
      }
      setState(() {
        _busy = false;
        _error = e.isNetworkError
            ? '보내지 못했습니다. 입력한 내용은 그대로 있어요. 다시 시도해주세요.'
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = widget.initialText != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '돌아가기 (작성한 내용은 임시 저장)',
                      onPressed: _busy ? null : _leave,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.title ?? '${widget.letter.counterpart} 님에게 답장',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '답장 내용',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          key: const Key('reply-text'),
                          controller: _text,
                          enabled: !_busy,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                          decoration: InputDecoration(
                            hintText: '답장을 적어 보세요',
                            fillColor: AppColors.paper,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: AppColors.paperSkeleton,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: AppColors.paperSkeleton,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: AppColors.paperSkeleton,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ErrorText(_error),
                      if (loaded)
                        Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            '임시 저장한 답장을 불러왔어요.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ToastAvoider(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: BusyButton(
                      key: const Key('reply-send'),
                      label: '답장 보내기',
                      busyLabel: '보내는 중…',
                      icon: Icons.send,
                      busy: _busy,
                      onPressed: _send,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
