import 'package:flutter/material.dart';

import '../theme.dart';

import '../app_services.dart';
import 'sea_screen.dart';
import 'shared_sea_screen.dart';

/// 로그인한 뒤의 첫 화면. 옆으로 밀어서 내 바다와 공유 바다를 오간다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pages = PageController();
  final ValueNotifier<int> _wake = ValueNotifier<int>(0);
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // 내 바다가 조금이라도 보이는 동안(밀어서 돌아오는 도중 포함) 내 바다의 UI를 다시 보이게 하고 대기 시간을 처음부터 센다.
    _pages.addListener(() {
      final p = _pages.hasClients ? _pages.page : null;
      if (p != null && p < 0.99) _wake.value++;
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    _wake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 두 바다 중 어디에 있는지 알려 주는 표시. 눌러서도 넘길 수 있다.
    // 각 바다 화면이 자기 Scaffold 본문 안에 그리므로 서랍(drawer)이 열리면 서랍이 표시 위에 덮인다.
    final tabs = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++)
          _PageTab(
            key: Key('home-tab-$i'),
            label: i == 0 ? '내 바다' : '공유 바다',
            selected: _page == i,
            onTap: () => _pages.animateToPage(
              i,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            ),
          ),
      ],
    );
    return PageView(
      key: const Key('home-pages'),
      controller: _pages,
      onPageChanged: (i) => setState(() => _page = i),
      children: [
        _KeepAlive(
          child: SeaScreen(
            services: widget.services,
            wakeSignal: _wake,
            header: tabs,
          ),
        ),
        _KeepAlive(
          child: SharedSeaScreen(services: widget.services, header: tabs),
        ),
      ],
    );
  }
}

class _PageTab extends StatelessWidget {
  const _PageTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.ink.withValues(alpha: selected ? 1 : 0.55),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 18 : 6,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: selected ? 0.9 : 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 옆 페이지로 넘어가도 이 페이지의 상태(바다, 열어 둔 편지 등)를 지우지 않는다.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
