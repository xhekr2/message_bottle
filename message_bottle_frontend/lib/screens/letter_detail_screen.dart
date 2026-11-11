import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/toast.dart';
import 'reply_screen.dart';
import 'visit_sea_screen.dart';

/// 바다에서 연 편지를 어떻게 처리하고 닫았는지. 바다 화면이 이 결과로 바다를 다시 불러온다.
/// [discarded]는 수신자가 X로 직접 버린 경우만이다. 이미 사라진 편지는 [gone].
enum DetailResult { archived, replied, discarded, gone }

/// S05 편지 상세.
///  - 바다에서 연 편지: 우상단 X(영구 삭제), 하단 [답장](일반 편지만)·[보관]. X 외에는 닫을 수 없고
///    Android 뒤로 가기는 아무 일도 하지 않는다.
///  - 받은 편지함·보낸 편지함에서 연 편지: 좌상단 뒤로 가기 화살표만 있고 하단 액션이 없다.
class LetterDetailScreen extends StatefulWidget {
  const LetterDetailScreen({
    super.key,
    required this.services,
    required this.data,
  });

  final AppServices services;
  final DetailData data;

  @override
  State<LetterDetailScreen> createState() => _LetterDetailScreenState();
}

class _LetterDetailScreenState extends State<LetterDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  bool _archiving = false;
  bool _loadingParent = false;

  bool get _isSea => widget.data.mode == DetailMode.sea;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /* ---------- 보관 ---------- */

  Future<void> _archive() async {
    if (_archiving) return;
    setState(() => _archiving = true);
    try {
      await widget.services.letters.archive(widget.data.id);
      widget.services.drafts.remove(widget.data.id);
      Toast.show('받은 편지함에 보관했어요.');
      if (mounted) Navigator.of(context).pop(DetailResult.archived);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _archiving = false);
      if (e.isNotFound) {
        Toast.show('이미 사라진 편지입니다.', error: true);
        Navigator.of(context).pop(DetailResult.gone);
      } else {
        Toast.show('보관하지 못했습니다. 편지는 그대로 있어요. 다시 시도해주세요.', error: true);
      }
    }
  }

  /* ---------- X: 영구 삭제 ---------- */

  Future<void> _discard() async {
    final outcome = await showActionDialog(
      context,
      title: '이 편지를 버릴까요?',
      message: '영구히 삭제되며 받은 편지함에 저장되지 않습니다. 되돌릴 수 없어요.',
      cancelLabel: '취소',
      okLabel: '버리기',
      okIcon: Icons.delete_outline,
      danger: true,
      action: () => widget.services.letters.discard(widget.data.id),
    );
    if (!mounted || !outcome.confirmed) return;
    final error = outcome.error;
    if (error == null || (error is ApiException && error.isNotFound)) {
      widget.services.drafts.remove(widget.data.id);
      Toast.show(
        error == null ? '편지를 버렸어요.' : '이미 사라진 편지입니다.',
        error: error != null,
      );
      Navigator.of(context)
          .pop(error == null ? DetailResult.discarded : DetailResult.gone);
    } else {
      Toast.show('삭제하지 못했습니다. 편지는 그대로 있어요.', error: true);
    }
  }

  /* ---------- 답장 ---------- */

  Future<void> _startReply() async {
    final drafts = widget.services.drafts;
    final id = widget.data.id;
    var load = false;
    if (drafts.has(id)) {
      final choice = await confirmDialog(
        context,
        title: '임시 저장한 답장이 있어요',
        message: '불러올까요? 취소를 누르면 새로 씁니다.',
        cancelLabel: '취소',
        okLabel: '확인',
      );
      if (!mounted || choice == null) return; // 뒤로 가기로 닫음: 아무 것도 바꾸지 않는다
      if (choice) {
        load = true;
      } else {
        drafts.remove(id); // 새로 쓰기: 이전 임시 저장은 그 자리에서 버린다
      }
    }
    final replied = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReplyScreen(
          services: widget.services,
          letter: widget.data,
          initialText: load ? drafts.of(id) : null,
        ),
      ),
    );
    if (replied == true && mounted) {
      Navigator.of(context).pop(DetailResult.replied);
    }
  }

  Future<void> _visitSea(String username) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            VisitSeaScreen(services: widget.services, username: username),
      ),
    );
  }

  /// 이전(부모) 편지를 불러와 읽기 전용으로 연다. 그 편지에 또 이전 편지가 있으면 같은 방식으로 이어진다.
  /// 바다에서 연 편지는 그대로 열려 있고, 뒤로 가면 돌아온다.
  Future<void> _openParent() async {
    final parentOf = widget.data.id;
    if (_loadingParent) return;
    setState(() => _loadingParent = true);
    try {
      final parent = await widget.services.letters.parentOf(parentOf);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              LetterDetailScreen(services: widget.services, data: parent),
        ),
      );
    } on ApiException catch (e) {
      if (e.sessionExpired) return;
      Toast.show(
        e.isNotFound ? '이전 편지를 더 이상 볼 수 없어요.' : e.message,
        error: true,
      );
    } finally {
      if (mounted) setState(() => _loadingParent = false);
    }
  }

  void _shakePaper() {
    _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return PopScope(
      // 바다에서 연 편지는 X(버리기)·보관·답장으로만 닫는다. 뒤로 가기는 편지를 닫거나 삭제하지 않는다.
      canPop: !_isSea,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSea) _shakePaper();
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      if (!_isSea)
                        IconButton(
                          key: const Key('detail-back'),
                          tooltip: '뒤로',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      const Spacer(),
                      if (_isSea)
                        IconButton(
                          key: const Key('detail-discard'),
                          tooltip: '편지 버리기 (영구 삭제)',
                          onPressed: _archiving ? null : _discard,
                          color: AppColors.danger,
                          iconSize: 28,
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      math.sin(_shake.value * math.pi * 4) *
                          6 *
                          (1 - _shake.value),
                      0,
                    ),
                    child: child,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 답장이면 제목 위에서 이전 편지로 거슬러 올라간다(내가 볼 수 있는 편지만).
                          if (d.parentId != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                key: const Key('detail-parent'),
                                onPressed: _loadingParent ? null : _openParent,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.only(right: 10),
                                  tapTargetSize: MaterialTapTargetSize.padded,
                                ),
                                icon: _loadingParent
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.north_west, size: 18),
                                label: const Text('이전 편지 보기'),
                              ),
                            ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  d.heading,
                                  key: const Key('detail-heading'),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    height: 32 / 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              // 보낸 사람(익명이 아닌 받은 편지)의 이름 옆에서 그 사람의 바다로 이동한다.
                              // 바다에서 연 편지도 이동할 수 있고, 돌아오면 편지가 그대로 열려 있다.
                              if (d.mode != DetailMode.sent &&
                                  !d.anonymous &&
                                  d.counterpart != null) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  key: const Key('detail-visit'),
                                  onPressed: () => _visitSea(d.counterpart!),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    tapTargetSize: MaterialTapTargetSize.padded,
                                  ),
                                  icon: const Icon(Icons.waves, size: 18),
                                  label: const Text('바다 이동'),
                                ),
                              ],
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              formatDate(d.sentAt),
                              style: TextStyle(
                                fontSize: 13,
                                height: 24 / 13,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Text(
                            d.content,
                            key: const Key('detail-content'),
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_isSea)
                ToastAvoider(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: _ActionRow(
                      children: [
                        if (d.canReply)
                          BusyButton(
                            key: const Key('detail-reply'),
                            label: '답장',
                            icon: Icons.reply,
                            onPressed: _archiving ? null : _startReply,
                          ),
                        if (d.canArchive)
                          BusyButton(
                            key: const Key('detail-archive'),
                            label: '보관',
                            busyLabel: '보관하는 중…',
                            icon: Icons.bookmark_border,
                            color: AppColors.accent,
                            busy: _archiving,
                            onPressed: _archive,
                          ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// 편지 아래의 버튼들. 보통은 옆으로 나란히 두고, 글자를 크게 키우면(130% 이상) 위아래로 쌓는다.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final big = MediaQuery.textScalerOf(context).scale(100) >= 130;
    if (big) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}
