import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/common.dart';

enum _SearchState { idle, waiting, searching, failed }

/// S02 편지 쓰기(바텀시트). 받는 사람은 아이디를 검색해서 고른다.
/// 검색은 글자를 칠 때마다 부르지 않고, 입력이 [searchDelay] 동안 멈추면 한 번만 부른다(부분 일치, 대소문자 구분).
/// 보내기가 서버에서 확인되면 true를 돌려주며 닫힌다. 입력한 내용이 있을 때 취소하면 폐기를 확인한다.
class WriteLetterSheet extends StatefulWidget {
  const WriteLetterSheet({
    super.key,
    required this.services,
    this.searchDelay = const Duration(seconds: 1),
  });

  final AppServices services;
  final Duration searchDelay;

  @override
  State<WriteLetterSheet> createState() => _WriteLetterSheetState();
}

class _WriteLetterSheetState extends State<WriteLetterSheet> {
  final _search = TextEditingController();
  final _content = TextEditingController();
  Timer? _debounce;
  String? _me;
  String? _chosen;
  bool _anonymous = false; // 기본은 익명 아님
  _SearchState _state = _SearchState.idle;
  List<String> _results = const [];
  bool _noMatch = false; // 검색이 끝났는데 결과가 하나도 없을 때
  String? _toError;
  String? _contentError;
  String? _sendError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.services.storage.readUsername().then((v) => _me = v);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _content.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    setState(() {
      _toError = null;
      _results = const [];
      _noMatch = false;
      _state = q.isEmpty ? _SearchState.idle : _SearchState.waiting;
    });
    if (q.isEmpty) return;
    _debounce = Timer(widget.searchDelay, () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    if (!mounted) return;
    setState(() => _state = _SearchState.searching);
    try {
      final found = await widget.services.letters.searchUsers(q);
      if (!mounted || _search.text != q) return; // 그 사이 입력이 바뀌었으면 결과를 버린다
      setState(() {
        _results = found;
        _noMatch = found.isEmpty;
        _state = _SearchState.idle;
      });
    } on ApiException {
      if (!mounted || _search.text != q) return;
      setState(() => _state = _SearchState.failed);
    }
  }

  void _choose(String username) {
    if (username == _me) {
      setState(() => _toError = '나 자신에게는 보낼 수 없습니다.');
      return;
    }
    setState(() {
      _chosen = username;
      _toError = null;
      _results = const [];
      _state = _SearchState.idle;
      _search.clear();
    });
  }

  bool get _dirty =>
      _chosen != null ||
      _content.text.trim().isNotEmpty ||
      _search.text.trim().isNotEmpty;

  Future<void> _cancel() async {
    if (_busy) return;
    if (!_dirty) {
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
      _toError = _chosen == null ? '받는 사람을 선택해주세요.' : null;
      _contentError = _content.text.trim().isEmpty ? '편지 내용을 입력해주세요.' : null;
      _sendError = null;
    });
    if (_toError != null || _contentError != null) return;
    setState(() => _busy = true);
    try {
      await widget.services.letters.send(
        receiverUsername: _chosen!,
        content: _content.text,
        anonymous: _anonymous,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sendError = e.isNetworkError
            ? '보내지 못했습니다. 입력한 내용은 그대로 있어요. 다시 시도해주세요.'
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
                '편지 쓰기',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              if (_chosen == null) ...[
                TextField(
                  key: const Key('write-search'),
                  controller: _search,
                  enabled: !_busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: '받는 사람 검색',
                    hintText: '아이디로 검색 (대소문자 구분)',
                  ),
                  onChanged: _onSearchChanged,
                ),
                _SearchResults(
                  state: _state,
                  results: _results,
                  noMatch: _noMatch,
                  me: _me,
                  onChoose: _choose,
                  onRetry: () => _runSearch(_search.text),
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: const Key('write-chosen'),
                    padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                    decoration: BoxDecoration(
                      color: AppColors.selected,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_chosen 님에게',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          tooltip: '받는 사람 다시 고르기',
                          onPressed: _busy
                              ? null
                              : () => setState(() => _chosen = null),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ErrorText(_toError),
              const SizedBox(height: 14),
              TextField(
                key: const Key('write-content'),
                controller: _content,
                enabled: !_busy,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '편지 내용',
                  hintText: '바다에 띄울 이야기를 적어 보세요',
                  alignLabelWithHint: true,
                ),
              ),
              ErrorText(_contentError),
              const SizedBox(height: 6),
              SwitchListTile(
                key: const Key('write-anonymous'),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '익명으로 보내기',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                value: _anonymous,
                onChanged: _busy ? null : (v) => setState(() => _anonymous = v),
              ),
              ErrorText(_sendError),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: OutlinedButton(
                      key: const Key('write-cancel'),
                      onPressed: _busy ? null : _cancel,
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BusyButton(
                      key: const Key('write-send'),
                      label: '보내기',
                      busyLabel: '보내는 중…',
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

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.state,
    required this.results,
    required this.noMatch,
    required this.me,
    required this.onChoose,
    required this.onRetry,
  });

  final _SearchState state;
  final List<String> results;
  final bool noMatch;
  final String? me;
  final ValueChanged<String> onChoose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    Widget? child;
    switch (state) {
      case _SearchState.waiting:
        child = const _Hint('입력을 멈추면 검색해요…');
      case _SearchState.searching:
        child = Semantics(
          label: '검색 중…',
          child: const ListSkeleton(count: 2, cards: false),
        );
      case _SearchState.failed:
        child = TextButton(
          onPressed: onRetry,
          child: const Text('검색하지 못했습니다. 다시 시도'),
        );
      case _SearchState.idle:
        if (results.isNotEmpty) {
          child = ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final u in results)
                  InkWell(
                    key: Key('result-$u'),
                    onTap: () => onChoose(u),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(u == me ? '$u (나)' : u),
                    ),
                  ),
              ],
            ),
          );
        } else if (noMatch) {
          child = const _Hint('일치하는 사용자가 없습니다.');
        }
    }
    if (child == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Text(text, style: TextStyle(color: AppColors.muted, fontSize: 14)),
  );
}
