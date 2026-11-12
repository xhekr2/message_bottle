import 'package:flutter/material.dart';

import '../theme.dart';
import 'bottle_icon.dart';

/// 불러오는 동안 글자 자리에 보여 주는 막대. 빛이 왼쪽에서 오른쪽으로 지나간다.
/// 기기의 "움직임 줄이기"가 켜져 있으면 움직이지 않는다.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.widthFactor = 1,
    this.height = 14,
    this.onPaper = false,
  });

  /// 부모 너비에 대한 비율(0~1).
  final double widthFactor;
  final double height;

  /// 편지지 위에 놓는 막대(편지지에 맞는 색을 쓴다).
  final bool onPaper;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.onPaper ? AppColors.paperSkeleton : AppColors.skeleton;
    final shine = widget.onPaper
        ? AppColors.paperSkeletonShine
        : AppColors.skeletonShine;
    final height = MediaQuery.textScalerOf(context).scale(widget.height);
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widget.widthFactor,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final x = -2.0 + 4.0 * _c.value;
          return Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: LinearGradient(
                begin: Alignment(x - 1, 0),
                end: Alignment(x + 1, 0),
                colors: [base, shine, base],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 편지를 불러오는 동안 보여 주는 편지지 모양(제목, 날짜, 본문 줄).
class LetterSkeleton extends StatelessWidget {
  const LetterSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('letter-skeleton'),
      color: AppColors.paper,
      child: SafeArea(
        child: Semantics(
          label: '편지를 불러오는 중',
          child: const Padding(
            padding: EdgeInsets.fromLTRB(24, 72, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(widthFactor: 0.52, height: 18, onPaper: true),
                SizedBox(height: 14),
                Skeleton(widthFactor: 0.24, onPaper: true),
                SizedBox(height: 24),
                Skeleton(onPaper: true),
                SizedBox(height: 12),
                Skeleton(widthFactor: 0.94, onPaper: true),
                SizedBox(height: 12),
                Skeleton(widthFactor: 0.98, onPaper: true),
                SizedBox(height: 12),
                Skeleton(widthFactor: 0.61, onPaper: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 목록을 불러오는 동안 보여 주는 카드 모양 [count]개(편지함, 검색 결과).
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 3, this.cards = true});

  final int count;

  /// false면 카드 테두리 없이 줄만 보여 준다(검색 결과).
  final bool cards;

  static const _first = [0.38, 0.46, 0.34, 0.42];
  static const _second = [0.88, 0.72, 0.8, 0.64];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '불러오는 중',
      child: Column(
        key: const Key('list-skeleton'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: EdgeInsets.only(bottom: cards ? 8 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: cards
                  ? BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(kRadius),
                      border: Border.all(color: AppColors.line),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(widthFactor: _first[i % _first.length]),
                  if (cards) ...[
                    const SizedBox(height: 10),
                    Skeleton(widthFactor: _second[i % _second.length]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 바다를 불러오는 동안 유리병 자리에 보여 주는 흐린 유리병들.
class SeaSkeleton extends StatefulWidget {
  const SeaSkeleton({super.key, this.label = '유리병을 찾고 있어요…'});

  final String label;

  @override
  State<SeaSkeleton> createState() => _SeaSkeletonState();
}

class _SeaSkeletonState extends State<SeaSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  static const _spots = [
    Offset(0.2, 0.3),
    Offset(0.7, 0.38),
    Offset(0.4, 0.54),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 0;
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const Key('sea-skeleton'),
      builder: (context, box) => Stack(
        children: [
          for (final spot in _spots)
            Positioned(
              left: box.maxWidth * spot.dx - 28,
              top: box.maxHeight * spot.dy - 50,
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.4, end: 0.18).animate(_c),
                child: const BottleIcon(),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            top: box.maxHeight * 0.68,
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
