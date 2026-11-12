import 'package:flutter/material.dart';

import '../sea_settings.dart';
import '../theme.dart';

/// 내 바다 화면의 서랍: 바다 공개 설정, 바다 색감, 글자 크기, UI 숨김 대기 시간, 파도 종류, 로그아웃.
class SeaDrawer extends StatelessWidget {
  const SeaDrawer({
    super.key,
    required this.settings,
    required this.isPublic,
    required this.onVisibility,
    required this.onLogout,
  });

  final SeaSettings settings;

  /// 내 바다가 공개 중인지. 바다를 아직 불러오지 못했으면 null(공개 설정을 열 수 없다).
  final bool? isPublic;
  final VoidCallback onVisibility;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('sea-drawer'),
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Text(
                        '설정',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ListTile(
                      key: const Key('sea-visibility'),
                      enabled: isPublic != null,
                      minVerticalPadding: 12,
                      leading: Icon(
                        isPublic == true ? Icons.public : Icons.lock_outline,
                      ),
                      title: const Text(
                        '내 바다 공개 설정',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isPublic == null
                            ? '바다를 불러온 뒤에 바꿀 수 있어요'
                            : isPublic!
                            ? '바다 공개 중'
                            : '바다 비공개',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: onVisibility,
                    ),
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: _SettingTitle(
                        title: '바다 색감',
                        value: settings.tone.label,
                        valueKey: const Key('tone-value'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                      child: Text(
                        '밝은 아침바다와 어두운 밤바다 중에서 골라요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        key: const Key('sea-tone'),
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tone in SeaTone.values)
                            ChoiceChip(
                              key: Key('tone-${tone.name}'),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              avatar: Icon(switch (tone) {
                                SeaTone.day => Icons.wb_sunny_outlined,
                                SeaTone.night => Icons.nightlight_outlined,
                                SeaTone.system => Icons.phone_android,
                              }, size: 18),
                              showCheckmark: false,
                              label: Text(tone.label),
                              selected: settings.tone == tone,
                              onSelected: (_) => settings.setTone(tone),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: _SettingTitle(
                        title: '글자 크기',
                        value: settings.textScaleLabel,
                        valueKey: const Key('text-scale-value'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                      child: Text(
                        '편지와 화면의 글자를 키우거나 줄여요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Slider(
                      key: const Key('text-scale-slider'),
                      min: 0,
                      max: (SeaSettings.textScales.length - 1).toDouble(),
                      divisions: SeaSettings.textScales.length - 1,
                      value: settings.textStep.toDouble(),
                      label: settings.textScaleLabel,
                      onChanged: (v) => settings.setTextStep(v.round()),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        key: const Key('text-scale-preview'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(kRadius),
                        ),
                        child: const Text(
                          '미리 보기: 오늘 바다는 잔잔해요.',
                          style: TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'UI 숨김 대기 시간',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '${settings.idleSeconds}초',
                            key: const Key('idle-value'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                      child: Text(
                        '바다에서 아무것도 하지 않으면 이만큼 뒤에 버튼과 안내가 숨고 유리병과 파도만 보여요.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted, height: 1.4),
                      ),
                    ),
                    Slider(
                      key: const Key('idle-slider'),
                      min: SeaSettings.minIdleSeconds.toDouble(),
                      max: SeaSettings.maxIdleSeconds.toDouble(),
                      divisions:
                          SeaSettings.maxIdleSeconds -
                          SeaSettings.minIdleSeconds,
                      value: settings.idleSeconds.toDouble(),
                      label: '${settings.idleSeconds}초',
                      onChanged: (v) => settings.setIdleSeconds(v.round()),
                    ),
                    const Divider(height: 24),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
                      child: Text(
                        '파도 종류',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SegmentedButton<WaveType>(
                        key: const Key('wave-type'),
                        showSelectedIcon: false,
                        segments: [
                          for (final type in WaveType.values)
                            ButtonSegment<WaveType>(
                              value: type,
                              label: Text(
                                type.label,
                                key: Key('wave-${type.name}'),
                              ),
                            ),
                        ],
                        selected: {settings.waveType},
                        onSelectionChanged: (s) =>
                            settings.setWaveType(s.first),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        '둘 다는 잔잔한 물결과 굽이치는 파도가 저절로 번갈아 나타나요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('sea-logout'),
                minVerticalPadding: 12,
                leading: Icon(Icons.logout, color: AppColors.danger),
                title: Text(
                  '로그아웃',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 설정 한 항목의 제목과 지금 값. 글자가 커지면 값이 아랫줄로 내려간다.
class _SettingTitle extends StatelessWidget {
  const _SettingTitle({
    required this.title,
    required this.value,
    required this.valueKey,
  });

  final String title;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 10,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(
          value,
          key: valueKey,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
