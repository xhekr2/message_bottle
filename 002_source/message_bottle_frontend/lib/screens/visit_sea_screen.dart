import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_services.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/bottle_field.dart';
import '../widgets/sea_backdrop.dart';
import '../widgets/sea_waves.dart';

/// 다른 사람의 바다 방문. "OOO의 바다"로 누구의 바다인지 보여주고, 공개된 바다는 떠 있는 유리병 개수만 보여준다.
/// 유리병을 눌러 편지를 열 수는 없다. 비공개 바다는 서버가 막고, 여기서는 안내만 보여준다.
class VisitSeaScreen extends StatefulWidget {
  const VisitSeaScreen({
    super.key,
    required this.services,
    required this.username,
  });

  final AppServices services;
  final String username;

  @override
  State<VisitSeaScreen> createState() => _VisitSeaScreenState();
}

enum _VisitState { loading, ready, privateSea, notFound, failed }

class _VisitSeaScreenState extends State<VisitSeaScreen>
    with TickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  late final WaveClock _clock = WaveClock(
    type: widget.services.settings.waveType,
  )..attach(this);
  _VisitState _state = _VisitState.loading;
  PublicSea? _sea;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    _clock.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _state = _VisitState.loading;
      _error = null;
    });
    try {
      final sea = await widget.services.letters.visitSea(widget.username);
      if (!mounted) return;
      setState(() {
        _sea = sea;
        _state = _VisitState.ready;
      });
    } on ApiException catch (e) {
      if (!mounted || e.sessionExpired) return;
      setState(() {
        _error = e.message;
        _state = switch (e.statusCode) {
          403 => _VisitState.privateSea,
          404 => _VisitState.notFound,
          _ => _VisitState.failed,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SeaBackdrop(
        clock: _clock,
        content: _content(),
        overlay: SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('visit-back'),
                    tooltip: '뒤로',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.text,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${widget.username}의 바다',
                      key: const Key('visit-title'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
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

  Widget _content() {
    switch (_state) {
      case _VisitState.loading:
        return const SeaSkeleton(label: '바다를 불러오고 있어요…');
      case _VisitState.ready:
        final count = _sea!.floatingCount;
        return Stack(
          children: [
            BottleField(
              animation: _anim,
              // 주인이 보는 자리 그대로(서버에 저장된 자리).
              slotOf: _sea!.slots.take(10).toList(),
            ),
            Align(
              alignment: const Alignment(0, 0.72),
              child: _InfoCard(
                children: [
                  Text(
                    count == 0 ? '떠 있는 유리병이 없어요' : '유리병 $count개가 떠 있어요',
                    key: const Key('visit-count'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '공개된 바다라서 유리병 개수만 볼 수 있어요.\n편지 내용은 볼 수 없어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case _VisitState.privateSea:
        return Center(
          child: _InfoCard(
            children: [
              Icon(Icons.lock_outline, size: 36, color: AppColors.muted),
              const SizedBox(height: 8),
              const Text(
                '비공개 바다예요',
                key: Key('visit-private'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.username}님이 바다를 공개하면 유리병 개수를 볼 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      case _VisitState.notFound:
        return Center(
          child: _InfoCard(
            children: [
              Icon(Icons.person_off_outlined, size: 36, color: AppColors.muted),
              const SizedBox(height: 8),
              const Text(
                '찾을 수 없는 사용자예요',
                key: Key('visit-notfound'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      case _VisitState.failed:
        return Center(
          child: _InfoCard(
            children: [
              const Text(
                '바다를 불러오지 못했습니다',
                key: Key('visit-failed'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('visit-retry'),
                onPressed: _load,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        );
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
