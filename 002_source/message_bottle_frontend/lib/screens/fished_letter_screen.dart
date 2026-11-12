import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/toast.dart';
import 'reply_screen.dart';

/// 공유 바다에서 낚은 편지. 작성자는 익명이라 알 수 없다.
/// 보관은 할 수 없고, 답장은 익명 작성자의 바다로 보낼 수 있다(공유 바다 편지의 예외 규칙).
/// 우상단 X는 영구 삭제가 아니라 그냥 닫기이며, 답장하지 않고 닫으면 편지는 공유 바다에 그대로 남는다.
/// 답장이 서버에서 확인되면 true를 돌려주며 닫힌다(그 편지는 공유 바다에서 사라진다).
class FishedLetterScreen extends StatelessWidget {
  const FishedLetterScreen({
    super.key,
    required this.services,
    required this.letter,
  });

  final AppServices services;
  final SharedLetter letter;

  Future<void> _reply(BuildContext context) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReplyScreen(
          services: services,
          letter: DetailData(
            id: letter.id,
            mode: DetailMode.sea,
            anonymous: true,
            content: letter.content,
          ),
          title: '익명의 유리병에 답장',
          persistDraft: false,
          sendReply: (text) => services.letters.replyShared(letter.id, text),
          successMessage: '답장을 보냈어요. 그 편지는 공유 바다에서 사라져요.',
          goneMessage: '이미 답장이 된 편지예요.',
        ),
      ),
    );
    if (sent == true && context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          // 편지 본문이 짧아도 일반 편지처럼 화면 가로를 꽉 채운다.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      key: const Key('fished-close'),
                      tooltip: '닫기 (편지는 공유 바다에 그대로 남아요)',
                      onPressed: () => Navigator.of(context).pop(false),
                      iconSize: 28,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '익명의 유리병',
                      key: Key('fished-heading'),
                      style: TextStyle(
                        fontSize: 20,
                        height: 32 / 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '공유 바다에서 낚았어요',
                      style: TextStyle(
                        fontSize: 13,
                        height: 24 / 13,
                        color: AppColors.muted,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        formatDate(letter.sentAt),
                        style: TextStyle(
                          fontSize: 13,
                          height: 24 / 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Text(
                      letter.content,
                      key: const Key('fished-content'),
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            ToastAvoider(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '보관은 할 수 없어요. 답장하지 않고 닫으면 이 편지는 공유 바다에 남아요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('fished-reply'),
                        onPressed: () => _reply(context),
                        icon: const Icon(Icons.reply),
                        label: const Text('답장'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
