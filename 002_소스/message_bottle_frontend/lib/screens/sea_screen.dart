import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/bottle_field.dart';
import '../widgets/common.dart';
import '../widgets/sea_backdrop.dart';
import '../widgets/sea_drawer.dart';
import '../widgets/skeleton.dart';
import '../widgets/sea_waves.dart';
import '../widgets/toast.dart';
import 'letter_detail_screen.dart';
import 'login_screen.dart';
import 'mailbox_dialog.dart';
import 'sea_visibility_dialog.dart';
import 'visit_sea_screen.dart';
import 'write_letter_sheet.dart';

/// S01 내 바다(메인). 떠 있는 유리병(최대 10개), 우상단 보낸/받은 편지함, 우하단 "편지 쓰기",
/// 좌상단 메뉴(서랍: 바다 공개 설정, UI 숨김 대기 시간, 파도 종류, 로그아웃).
/// 설정한 시간 동안 아무것도 하지 않으면 버튼과 안내가 숨고 유리병과 파도만 보인다.
class SeaScreen extends StatefulWidget {
  const SeaScreen({
    super.key,
    required this.services,
    this.wakeSignal,
    this.header,
  });

  final AppServices services;

  /// 울리면 숨겼던 UI를 다시 보인다(옆 페이지에서 내 바다로 돌아올 때 홈 화면이 울린다).
  final Listenable? wakeSignal;

  /// 화면 위 가운데에 그리는 "내 바다 / 공유 바다" 표시(홈 화면이 준다). 서랍보다 아래에 그려진다.
  final Widget? header;

  @override
  State<SeaScreen> createState() => _SeaScreenState();
}

class _SeaScreenState extends State<SeaScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  late final WaveClock _clock = WaveClock(
    type: widget.services.settings.waveType,
  )..attach(this);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  SeaData? _sea;
  String? _error;
  bool _loading = true;
  bool _opening = false;
  bool _openingMail = false; // 편지함의 편지를 불러오는 중
  bool _detailOpen = false;

  /// 편지 id → 바다의 자리. 한 번 정한 자리는 그 병이 있는 동안 바뀌지 않는다.
  Map<int, int> _slots = {};

  /// 버려서 사라지는 중인 자리들.
  final List<int> _vanishing = [];

  Timer? _idleTimer;
  bool _idle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.services.settings.addListener(_onSettings);
    widget.wakeSignal?.addListener(_wake);
    widget.services.settings.load();
    _restartIdle();
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.services.settings.removeListener(_onSettings);
    widget.wakeSignal?.removeListener(_wake);
    _idleTimer?.cancel();
    _anim.dispose();
    _clock.dispose();
    super.dispose();
  }

  /* ---------- 설정과 UI 숨김 ---------- */

  void _onSettings() {
    _clock.type = widget.services.settings.waveType;
    _restartIdle();
  }

  /// 화면을 건드리면 숨겼던 UI를 다시 보이고 대기 시간을 처음부터 센다.
  void _wake() {
    if (_idle && mounted) setState(() => _idle = false);
    _restartIdle();
  }

  void _restartIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(
      Duration(seconds: widget.services.settings.idleSeconds),
      _onIdle,
    );
  }

  void _onIdle() {
    if (!mounted) return;
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    final drawerOpen = _scaffoldKey.currentState?.isDrawerOpen ?? false;
    // 다른 화면·창이 위에 있거나 서랍이 열려 있거나 오류 안내가 떠 있으면 숨기지 않는다.
    if (onTop && !drawerOpen && !_loading && !_opening && _error == null) {
      if (!_idle) setState(() => _idle = true);
    } else {
      _restartIdle();
    }
  }

  Widget _hideable(Widget child) => IgnorePointer(
    ignoring: _idle,
    child: AnimatedOpacity(
      opacity: _idle ? 0 : 1,
      duration: const Duration(milliseconds: 800),
      child: child,
    ),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱으로 돌아왔을 때 새 편지를 불러온다. 편지를 열어 둔 동안에는 바다를 불러오지 않는다
    // (서버가 "열었지만 처리하지 않은 편지"를 버리는 시점이 바다를 불러올 때이기 때문이다).
    if (state == AppLifecycleState.resumed &&
        !_detailOpen &&
        !_opening &&
        !_loading) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final sea = await widget.services.letters.sea();
      if (!mounted) return;
      setState(() {
        _sea = sea;
        _slots = assignSlots(
          _slots,
          sea.letters.take(10).map((b) => b.id).toList(),
          reserved: _vanishing.toSet(),
        );
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || e.sessionExpired) return;
      if (silent && _sea != null) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  /* ---------- 유리병 열기 ---------- */

  Future<void> _openBottle(Bottle bottle) async {
    if (_opening) return;
    setState(() => _opening = true);
    final slot = _slots[bottle.id];
    DetailResult? result;
    try {
      // 서버가 열람을 기록하는 순간부터 닫을 때까지는 네트워크가 끊겨도 앱을 종료하지 않는다.
      widget.services.letterOpen.value = true;
      final data = await widget.services.letters.openLetter(bottle.id);
      if (!mounted) return;
      _detailOpen = true;
      result = await Navigator.of(context).push<DetailResult>(
        MaterialPageRoute<DetailResult>(
          builder: (_) =>
              LetterDetailScreen(services: widget.services, data: data),
        ),
      );
    } on ApiException catch (e) {
      if (e.sessionExpired) return;
      Toast.show(e.isNotFound ? '이미 사라진 편지입니다.' : e.message, error: true);
    } finally {
      _detailOpen = false;
      widget.services.letterOpen.value = false;
      if (mounted) setState(() => _opening = false);
    }
    if (!mounted) return;
    _wake();
    final sea = _sea;
    if (result == DetailResult.discarded && slot != null && sea != null) {
      // X로 직접 버렸을 때만 그 자리에서 물결이 번지고 병이 가라앉는다(보관·답장은 효과 없이 사라진다).
      setState(() {
        _vanishing.add(slot);
        _sea = SeaData(
          floatingCount: sea.floatingCount - 1,
          capacity: sea.capacity,
          letters: sea.letters.where((b) => b.id != bottle.id).toList(),
          isPublic: sea.isPublic,
        );
      });
    }
    await _load(); // 처리(보관·답장·버리기)한 편지는 바다에서 사라진다
  }

  /* ---------- 편지함 ---------- */

  Future<void> _openMailbox(MailboxKind kind) async {
    var offset = 0.0;
    while (true) {
      if (!mounted) return;
      final selection = await showDialog<MailboxSelection>(
        context: context,
        builder: (_) => MailboxDialog(
          services: widget.services,
          kind: kind,
          initialOffset: offset,
        ),
      );
      if (selection == null || !mounted) return;
      offset = selection.offset;
      if (selection.visitUsername != null) {
        // 받은 편지의 보낸 사람을 눌러 그 사람의 바다를 방문하고, 돌아오면 목록을 다시 연다.
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => VisitSeaScreen(
              services: widget.services,
              username: selection.visitUsername!,
            ),
          ),
        );
        continue;
      }
      if (!await _openMailDetail(kind, selection.id)) return;
    }
  }

  /// 편지함에서 편지를 열고, 뒤로 가기로 돌아오면 true(목록을 다시 연다).
  Future<bool> _openMailDetail(MailboxKind kind, int id) async {
    setState(() => _openingMail = true);
    try {
      final data = kind == MailboxKind.inbox
          ? await widget.services.letters.inboxDetail(id)
          : await widget.services.letters.sentDetail(id);
      if (!mounted) return false;
      _detailOpen = true;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              LetterDetailScreen(services: widget.services, data: data),
        ),
      );
    } on ApiException catch (e) {
      if (e.sessionExpired) return false;
      Toast.show(e.isNotFound ? '이미 사라진 편지입니다.' : e.message, error: true);
    } finally {
      _detailOpen = false;
      if (mounted) setState(() => _openingMail = false);
    }
    return true;
  }

  /* ---------- 편지 쓰기 ---------- */

  Future<void> _write() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WriteLetterSheet(services: widget.services),
    );
    if (sent == true) Toast.show('보냈습니다. 보낸 편지함에서 확인할 수 있어요.');
  }

  /* ---------- 바다 공개 설정 ---------- */

  Future<void> _openVisibility() async {
    final sea = _sea;
    if (sea == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => SeaVisibilityDialog(
        services: widget.services,
        initialPublic: sea.isPublic,
        onChanged: (value) {
          if (mounted && _sea != null) {
            setState(() => _sea = _sea!.withPublic(value));
          }
        },
      ),
    );
  }

  /* ---------- 로그아웃 ---------- */

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: '로그아웃할까요?',
      message: '다시 로그인해야 편지를 볼 수 있어요.',
      cancelLabel: '취소',
      okLabel: '로그아웃',
    );
    if (ok != true || !mounted) return;
    await widget.services.auth.logout();
    widget.services.drafts.clear();
    widget.services.settings.reset(); // 다음 사용자에게 이 사용자의 설정이 보이지 않게
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(services: widget.services),
      ),
      (_) => false,
    );
  }

  /* ---------- 화면 ---------- */

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _wake(),
      onPointerMove: (_) => _wake(),
      onPointerSignal: (_) => _wake(),
      child: Stack(
        children: [
          Scaffold(
            key: _scaffoldKey,
            extendBody: true,
            drawer: SeaDrawer(
              settings: widget.services.settings,
              isPublic: _sea?.isPublic,
              onVisibility: () {
                _scaffoldKey.currentState?.closeDrawer();
                _openVisibility().whenComplete(_wake);
              },
              onLogout: () {
                _scaffoldKey.currentState?.closeDrawer();
                _logout();
              },
            ),
            floatingActionButton: _hideable(
              ValueListenableBuilder<bool>(
                valueListenable: Toast.visible,
                builder: (context, toastShown, child) => AnimatedSlide(
                  offset: toastShown
                      ? const Offset(0, -1.25)
                      : Offset.zero, // 안내가 뜨는 동안 버튼이 위로 비켜준다
                  duration: const Duration(milliseconds: 200),
                  child: child,
                ),
                child: FloatingActionButton.extended(
                  key: const Key('sea-write'),
                  onPressed: () => _write().whenComplete(_wake),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: StadiumBorder(
                    side: BorderSide(color: AppColors.bottleLine, width: 3),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text(
                    '편지 쓰기',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            body: SeaBackdrop(
              header: widget.header,
              clock: _clock,
              content: _content(),
              overlay: _hideable(
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          color: AppColors.chip,
                          elevation: 2,
                          shadowColor: Colors.black26,
                          shape: const CircleBorder(),
                          child: IconButton(
                            key: const Key('sea-menu'),
                            tooltip: '메뉴',
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            icon: const Icon(Icons.menu),
                            color: AppColors.text,
                          ),
                        ),
                        const Spacer(),
                        // 위쪽 "내 바다 / 공유 바다" 표시와 겹치지 않게 그 아랫줄에서 시작한다.
                        Padding(
                          padding: const EdgeInsets.only(
                            top: SeaBackdrop.chipTop - 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SeaChip(
                                key: const Key('sea-sent'),
                                icon: Icons.send_outlined,
                                label: '보낸 편지함',
                                onTap: () =>
                                    _openMailbox(MailboxKind.sent)
                                        .whenComplete(_wake),
                              ),
                              const SizedBox(height: 8),
                              SeaChip(
                                key: const Key('sea-inbox'),
                                icon: Icons.inbox_outlined,
                                label: '받은 편지함',
                                onTap: () =>
                                    _openMailbox(MailboxKind.inbox)
                                        .whenComplete(_wake),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 편지를 불러오는 동안 편지지 모양의 스켈레톤을 보여 준다.
          if (_opening || _openingMail)
            const Positioned.fill(child: LetterSkeleton()),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading && _sea == null) {
      return const SeaSkeleton();
    }
    if (_error != null && _sea == null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.chip,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '바다를 불러오지 못했습니다',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('sea-retry'),
                onPressed: _load,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    final letters = _sea?.letters.take(10).toList() ?? const <Bottle>[];
    if (letters.isEmpty) {
      return Stack(
        children: [
          Positioned.fill(child: _vanishLayer(const [])),
          // 숨김 상태에서는 안내도 사라져 빈 바다만 보인다.
          _hideable(
            Align(
              alignment: Alignment(0, -0.25),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mail_outline, size: 44, color: AppColors.ink),
                    SizedBox(height: 8),
                    Text(
                      '아직 도착한 유리병이 없어요',
                      key: Key('sea-empty'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '오른쪽 아래 버튼으로 먼저 편지를 보내 보세요.',
                      style: TextStyle(fontSize: 13, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return _vanishLayer(letters);
  }

  /// 유리병들과 사라지는 효과. 자리는 병마다 고정이라 한 병이 사라져도 나머지는 움직이지 않는다.
  Widget _vanishLayer(List<Bottle> letters) {
    return BottleField(
      animation: _anim,
      slotOf: [for (final b in letters) _slots[b.id] ?? 0],
      keyOf: (i) => Key('bottle-${letters[i].id}'),
      onTap: (i) => _openBottle(letters[i]),
      vanishing: List.of(_vanishing),
      onVanished: (slot) {
        if (mounted) setState(() => _vanishing.remove(slot));
      },
    );
  }
}
