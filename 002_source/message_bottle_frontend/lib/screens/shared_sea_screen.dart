import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/fishing_rig.dart';
import '../widgets/sea_backdrop.dart';
import '../widgets/sea_waves.dart';
import '../widgets/toast.dart';
import 'fished_letter_screen.dart';
import 'shared_write_sheet.dart';

/// 모든 사용자가 함께 쓰는 공유 바다. 유리병이 떠다니지 않고, 아래 가운데 "유리병 낚기" 버튼으로
/// 바다에 남아 있는 편지 중 하나를 무작위로 낚는다. 우상단에서 익명으로 편지를 띄울 수 있다.
class SharedSeaScreen extends StatefulWidget {
  const SharedSeaScreen({
    super.key,
    required this.services,
    this.header,
    this.clock,
    this.seaShift,
  });

  final AppServices services;

  /// 화면 위 가운데에 그리는 "내 바다 / 공유 바다" 표시(홈 화면이 준다). 서랍이 없지만 같은 위치를 쓴다.
  final Widget? header;

  /// 홈 화면이 두 바다에 함께 주는 파도 시계. 없으면 이 화면이 자기 시계를 만든다.
  final WaveClock? clock;

  /// 이 화면이 옆으로 밀려 있는 만큼을 되돌리는 값(홈 화면이 준다). 바다를 화면에 고정해 그리는 데 쓴다.
  final ValueListenable<double>? seaShift;

  @override
  State<SharedSeaScreen> createState() => _SharedSeaScreenState();
}

class _SharedSeaScreenState extends State<SharedSeaScreen>
    with TickerProviderStateMixin {
  late final WaveClock _clock =
      widget.clock ??
      (WaveClock(type: widget.services.settings.waveType)..attach(this));
  late final FishingRig _rig = FishingRig(_clock)..attach(this);
  bool _fishing = false;

  /// 낚는 움직임을 보여 주는 중(버튼과 가운데 안내를 치운다). "애니메이션 줄이기" 설정이면 쓰지 않는다.
  bool _animating = false;

  /// 유리병이 올라와 매달려 있고, 눌러 주기를 기다리는 중이면 값이 있다.
  Completer<void>? _bottleTap;

  @override
  void initState() {
    super.initState();
    widget.services.settings.addListener(_onSettings);
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_onSettings);
    final tap = _bottleTap;
    if (tap != null && !tap.isCompleted) tap.complete();
    _rig.dispose();
    if (widget.clock == null) _clock.dispose(); // 홈 화면이 준 시계는 홈 화면이 정리한다
    super.dispose();
  }

  void _onSettings() => _clock.type = widget.services.settings.waveType;

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
      builder: (_) => SharedWriteSheet(services: widget.services),
    );
    if (sent == true) Toast.show('공유 바다에 편지를 띄웠어요.');
  }

  Future<void> _fish() async {
    if (_fishing) return;
    final animate = !MediaQuery.of(context).disableAnimations;
    setState(() {
      _fishing = true;
      _animating = animate;
    });
    // 낚싯줄을 던져 두고 서버의 답을 기다린다. 찌가 떠 있는 동안이 기다리는 시간이다.
    if (animate) _rig.start();
    try {
      final letter = await widget.services.letters.fishShared();
      if (animate) {
        await _rig.finish(caught: true);
        if (!mounted) return;
        // 올라온 유리병을 눌러야 편지가 열린다.
        final tap = Completer<void>();
        setState(() => _bottleTap = tap);
        await tap.future;
        if (!mounted) return;
        setState(() => _bottleTap = null);
      }
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      final opened = Navigator.of(context).push<bool>(
        animate
            ? _revealRoute(
                // 매달린 유리병의 가운데에서 편지지가 퍼져 나온다.
                Offset(
                  size.width / 2,
                  size.height * FishingRig.bottleTopFraction + 48,
                ),
                letter,
              )
            : MaterialPageRoute<bool>(
                builder: (_) => FishedLetterScreen(
                  services: widget.services,
                  letter: letter,
                ),
              ),
      );
      // 편지가 화면을 덮은 뒤에 낚싯줄을 치운다.
      if (animate) {
        Future<void>.delayed(_revealDuration, () {
          if (mounted) _rig.reset();
        });
      }
      await opened;
    } on ApiException catch (e) {
      if (e.sessionExpired) return;
      // 낚인 것이 없으면 빈 바늘만 올라온 뒤에 알린다.
      if (animate) await _rig.finish(caught: false);
      if (e.isNotFound) {
        Toast.show('남아있는 편지가 없어요!', icon: false);
      } else {
        Toast.show(e.message, error: true);
      }
    } finally {
      if (mounted) {
        _rig.reset();
        setState(() {
          _fishing = false;
          _animating = false;
          _bottleTap = null;
        });
      }
    }
  }

  static const _revealDuration = Duration(milliseconds: 450);

  Route<bool> _revealRoute(Offset center, SharedLetter letter) {
    return PageRouteBuilder<bool>(
      transitionDuration: _revealDuration,
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) =>
          FishedLetterScreen(services: widget.services, letter: letter),
      transitionsBuilder: (_, animation, _, child) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) => ClipPath(
          clipper: _CircleReveal(
            center,
            Curves.easeInOut.transform(animation.value),
          ),
          child: child,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: Toast.visible,
        // 안내(토스트)가 떠 있으면 버튼이 그 위로 비켜난다. 자리를 실제로 옮겨야 비켜난 버튼도 눌린다.
        builder: (context, toastShown, child) => AnimatedPadding(
          padding: EdgeInsets.only(bottom: toastShown ? 83 : 0),
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: _animating,
            child: AnimatedOpacity(
              opacity: _animating ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: AnimatedSlide(
                // 낚는 동안에는 버튼이 아래로 빠지고 그 자리에 낚싯줄이 내려온다.
                offset: _animating ? const Offset(0, 1.6) : Offset.zero,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: child,
              ),
            ),
          ),
        ),
        child: _FishButton(busy: _fishing, onPressed: _fish),
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          _rig.skyHeight = box.maxHeight - SeaWaves.height;
          final tap = _bottleTap;
          return Stack(
            children: [
              Positioned.fill(child: _sea()),
              if (tap != null)
                Positioned(
                  left: 0,
                  right: 0,
                  // 매달린 유리병(마개가 화면 높이의 bottleTopFraction 지점)을 덮는 자리.
                  top: box.maxHeight * FishingRig.bottleTopFraction - 30,
                  child: Center(
                    child: _BottleTapTarget(
                      onTap: () {
                        if (!tap.isCompleted) tap.complete();
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 낚싯줄이 내려올 때부터 낚은 편지를 닫을 때까지 숨기는 것(위쪽 표시, 편지 띄우기).
  Widget _hiddenWhileFishing(Widget child) => IgnorePointer(
    ignoring: _fishing,
    child: AnimatedOpacity(
      opacity: _fishing ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      child: child,
    ),
  );

  Widget _sea() {
    return SeaBackdrop(
      header: widget.header == null
          ? null
          : _hiddenWhileFishing(widget.header!),
      shift: widget.seaShift,
      clock: _clock,
      rig: _rig,
      content: AnimatedOpacity(
        key: const Key('shared-hello'),
        opacity: _animating ? 0 : 1,
        duration: const Duration(milliseconds: 250),
        child: Align(
          alignment: Alignment(0, -0.2),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.public, size: 44, color: AppColors.ink),
                SizedBox(height: 8),
                Text(
                  '공유 바다',
                  key: Key('shared-title'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '모두가 함께 쓰는 바다예요.\n누군가 띄운 유리병을 낚아 보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      overlay: SafeArea(
        child: Stack(
          children: [
            Padding(
              // 위쪽 표시와 겹치지 않게 그 아랫줄 오른쪽에 둔다(내 바다의 편지함 버튼과 같은 높이).
              padding: const EdgeInsets.fromLTRB(
                12,
                SeaBackdrop.chipTop,
                12,
                0,
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: _hiddenWhileFishing(
                  SeaChip(
                    key: const Key('shared-write'),
                    icon: Icons.edit_outlined,
                    label: '편지 띄우기',
                    onTap: _write,
                  ),
                ),
              ),
            ),
            // 낚는 동안 버튼이 있던 자리에 보여 주는 안내.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: IgnorePointer(
                  child: ValueListenableBuilder<String>(
                    valueListenable: _rig.status,
                    builder: (context, text, _) => AnimatedOpacity(
                      opacity: text.isEmpty ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        text,
                        key: const Key('fishing-status'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Color(0x990A325A), blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 아래 가운데의 둥근 "유리병 낚기" 버튼. 편지 쓰기 버튼처럼 파란 바탕에 흰 테두리.
class _FishButton extends StatelessWidget {
  const _FishButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '유리병 낚기',
      child: Material(
        key: const Key('shared-fish'),
        color: AppColors.primary,
        elevation: 6,
        shadowColor: Colors.black38,
        shape: CircleBorder(
          side: BorderSide(color: AppColors.bottleLine, width: 3),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            width: 92,
            height: 92,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phishing,
                          color: AppColors.onPrimary,
                          size: 32,
                        ),
                        SizedBox(height: 2),
                        Text(
                          '유리병 낚기',
                          style: TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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

/// [center]에서 원이 퍼지며 화면 전체가 드러난다. [progress] 0은 안 보임, 1은 전부 보임.
class _CircleReveal extends CustomClipper<Path> {
  const _CircleReveal(this.center, this.progress);

  final Offset center;
  final double progress;

  @override
  Path getClip(Size size) {
    final far = Offset(
      math.max(center.dx, size.width - center.dx),
      math.max(center.dy, size.height - center.dy),
    ).distance;
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: far * progress));
  }

  @override
  bool shouldReclip(covariant _CircleReveal old) =>
      old.progress != progress || old.center != center;
}

/// 올라온 유리병 위에 놓는 누르는 자리와 그 아래의 안내. 이걸 눌러야 편지가 열린다.
class _BottleTapTarget extends StatelessWidget {
  const _BottleTapTarget({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '유리병을 눌러 편지 열기',
      child: GestureDetector(
        key: const Key('fished-bottle'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 유리병이 그려지는 자리(그림은 파도와 함께 그린다).
              const SizedBox(width: 120, height: 150),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 18,
                      color: AppColors.text,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '유리병을 눌러 열어 보세요',
                      key: Key('fished-bottle-hint'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
