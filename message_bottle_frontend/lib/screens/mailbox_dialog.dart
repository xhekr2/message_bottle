import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/toast.dart';

enum MailboxKind { sent, inbox }

/// 목록에서 고른 항목. [id]는 받은 편지함이면 보관 id, 보낸 편지함이면 편지 id. [offset]은 돌아올 때 스크롤 위치를 되살리는 값.
/// [visitUsername]이 있으면 편지가 아니라 그 사람의 바다를 방문하겠다는 뜻이다(받은 편지의 보낸 사람을 누른 경우).
class MailboxSelection {
  const MailboxSelection(this.id, this.offset, {this.visitUsername});
  final int id;
  final double offset;
  final String? visitUsername;
}

/// S03 보낸 편지함 / S04 받은 편지함 팝업. 카드가 많아지면 카드는 줄어들지 않고 목록이 스크롤된다.
///  - 보낸 편지함: 삭제 기능이 없다.
///  - 받은 편지함: 카드를 오른쪽에서 왼쪽으로 밀면 확인 없이 삭제한다(서버에서 확인된 뒤에만 지운다).
///    답장한 편지는 카드 맨 오른쪽에 체크 아이콘이 있다.
/// 바깥 터치나 뒤로 가기로 닫을 수 있다.
class MailboxDialog extends StatefulWidget {
  const MailboxDialog({
    super.key,
    required this.services,
    required this.kind,
    this.initialOffset = 0,
  });

  final AppServices services;
  final MailboxKind kind;
  final double initialOffset;

  @override
  State<MailboxDialog> createState() => _MailboxDialogState();
}

class _MailboxDialogState extends State<MailboxDialog> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: widget.initialOffset,
  );
  bool _loading = true;
  String? _error;
  List<SentItem> _sent = const [];
  List<InboxItem> _inbox = const [];

  bool get _isInbox => widget.kind == MailboxKind.inbox;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isInbox) {
        final items = await widget.services.letters.inbox();
        if (mounted) setState(() => _inbox = items);
      } else {
        final items = await widget.services.letters.sent();
        if (mounted) setState(() => _sent = items);
      }
      if (mounted) setState(() => _loading = false);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  void _select(int id) {
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    Navigator.of(context).pop(MailboxSelection(id, offset));
  }

  void _visit(String username) {
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    Navigator.of(context)
        .pop(MailboxSelection(0, offset, visitUsername: username));
  }

  Future<bool> _confirmDelete(InboxItem item) async {
    try {
      await widget.services.letters.deleteFromInbox(item.archiveId);
      return true;
    } on ApiException catch (e) {
      if (e.isNotFound) return true; // 이미 지워진 항목은 목록에서도 치운다
      Toast.show('삭제하지 못했습니다. 카드를 다시 밀어 보세요.', error: true);
      return false;
    }
  }

  void _removeInbox(InboxItem item) {
    setState(
      () =>
          _inbox = _inbox.where((e) => e.archiveId != item.archiveId).toList(),
    );
    Toast.show('삭제했어요.');
  }

  @override
  Widget build(BuildContext context) {
    final title = _isInbox ? '받은 편지함' : '보낸 편지함';
    final hint = _isInbox
        ? '카드를 왼쪽으로 밀면 삭제됩니다. (확인 없음) ✓는 답장한 편지예요.'
        : '보낸 편지는 삭제할 수 없어요.';
    final maxHeight = math.min(580.0, MediaQuery.sizeOf(context).height * 0.72);

    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 340, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      key: const Key('mailbox-title'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('mailbox-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                hint,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            Flexible(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: ListSkeleton(),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('불러오지 못했습니다.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 4),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    final empty = _isInbox ? _inbox.isEmpty : _sent.isEmpty;
    if (empty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Center(
          child: Text(
            _isInbox ? '보관한 편지가 없습니다' : '보낸 편지가 없습니다',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    return ListView(
      controller: _scroll,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        if (_isInbox)
          for (final item in _inbox)
            Padding(
              key: ValueKey('inbox-${item.archiveId}'),
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kRadius),
                child: Dismissible(
                  key: ValueKey('dismiss-${item.archiveId}'),
                  direction: DismissDirection.endToStart,
                  background: const SizedBox.shrink(),
                  secondaryBackground: Container(
                    color: AppColors.danger,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: AppColors.on(AppColors.danger),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '삭제',
                          style: TextStyle(
                            color: AppColors.on(AppColors.danger),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (_) => _confirmDelete(item),
                  onDismissed: (_) => _removeInbox(item),
                  child: _LetterCard(
                    title: item.senderLabel,
                    date: formatDate(item.archivedAt),
                    preview: item.preview,
                    replied: item.replied,
                    onTap: () => _select(item.archiveId),
                    // 익명 편지는 보낸 사람을 알 수 없으므로 누를 수 없다
                    onTitleTap: item.anonymous || item.senderUsername == null
                        ? null
                        : () => _visit(item.senderUsername!),
                  ),
                ),
              ),
            )
        else
          for (final item in _sent)
            Padding(
              key: ValueKey('sent-${item.id}'),
              padding: const EdgeInsets.only(bottom: 8),
              child: _LetterCard(
                title: item.receiverLabel,
                date: formatDate(item.sentAt),
                suffix: item.anonymous ? '익명으로 보냄' : null,
                preview: item.preview,
                onTap: () => _select(item.id),
              ),
            ),
      ],
    );
  }
}

/// 편지함 카드 한 장. 카드 높이는 줄어들지 않는다.
class _LetterCard extends StatelessWidget {
  const _LetterCard({
    required this.title,
    required this.date,
    required this.preview,
    required this.onTap,
    this.onTitleTap,
    this.suffix,
    this.replied = false,
  });

  final String title;
  final String date;
  final String preview;
  final String? suffix;
  final bool replied;
  final VoidCallback onTap;

  /// 있으면 이름을 눌러 그 사람의 바다로 갈 수 있다(밑줄과 색으로 표시).
  final VoidCallback? onTitleTap;

  Widget _name() {
    final tappable = onTitleTap != null;
    final label = Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: tappable ? AppColors.primary : AppColors.text,
        decoration: tappable ? TextDecoration.underline : null,
        decorationColor: AppColors.primary,
      ),
    );
    final box = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 1,
        child: label,
      ),
    );
    if (!tappable) return box;
    return Semantics(
      button: true,
      label: '$title의 바다 방문',
      child: InkWell(
        key: Key('card-visit-$title'),
        onTap: onTitleTap,
        child: box,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 아이디가 길거나 글자가 크면 날짜가 아랫줄로 내려간다.
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _name(),
                        Text(
                          '$date${suffix != null ? ' · $suffix' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.text.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (replied)
                Container(
                  key: const Key('replied-check'),
                  margin: const EdgeInsets.only(left: 10),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Semantics(
                    label: '답장한 편지',
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: AppColors.on(AppColors.accent),
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
