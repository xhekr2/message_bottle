import 'package:flutter/material.dart';

/// 한 가지 바다 색감(아침바다 또는 밤바다)의 색 모음. docs/design-system.md 기준.
class AppPalette {
  const AppPalette({
    required this.night,
    required this.primary,
    required this.onPrimary,
    required this.background,
    required this.card,
    required this.text,
    required this.muted,
    required this.paper,
    required this.accent,
    required this.danger,
    required this.seaTop,
    required this.seaMiddle,
    required this.seaBottom,
    required this.seaGlow,
    required this.waves,
    required this.ink,
    required this.chip,
    required this.line,
    required this.inputBorder,
    required this.selected,
    required this.skeleton,
    required this.skeletonShine,
    required this.paperSkeleton,
    required this.paperSkeletonShine,
    required this.bottleGlass,
    required this.bottleLine,
  });

  final bool night;
  final Color primary;
  final Color onPrimary;

  /// 창·시트·폼의 바탕.
  final Color background;

  /// 카드·입력 칸·확인 창의 바탕.
  final Color card;
  final Color text;
  final Color muted;
  final Color paper;
  final Color accent;
  final Color danger;
  final Color seaTop;
  final Color seaMiddle;
  final Color seaBottom;

  /// 하늘의 빛(아침은 햇빛, 밤은 달빛).
  final Color seaGlow;

  /// 파도 네 겹(뒤에서 앞으로).
  final List<Color> waves;

  /// 바다 위에 직접 올리는 글자.
  final Color ink;

  /// 바다 위에 올리는 둥근 버튼·안내의 바탕.
  final Color chip;
  final Color line;
  final Color inputBorder;

  /// 고른 항목(받는 사람 등)의 바탕.
  final Color selected;
  final Color skeleton;
  final Color skeletonShine;
  final Color paperSkeleton;
  final Color paperSkeletonShine;
  final Color bottleGlass;
  final Color bottleLine;

  /// 아침바다(밝은 톤).
  static const day = AppPalette(
    night: false,
    primary: Color(0xFF0B5FA5),
    onPrimary: Colors.white,
    background: Color(0xFFF7FBFE),
    card: Colors.white,
    text: Color(0xFF12263A),
    muted: Color(0xFF5A6B7B),
    paper: Color(0xFFFFF8E7),
    accent: Color(0xFF1B8475),
    danger: Color(0xFFB3261E),
    seaTop: Color(0xFFCBE9F7),
    seaMiddle: Color(0xFF7FBDE3),
    seaBottom: Color(0xFF2F7FB8),
    seaGlow: Color(0xBFFFFFFF),
    waves: [
      Color(0x6B60AAD7),
      Color(0x8534869E),
      Color(0x9E1B649B),
      Color(0xCC145282),
    ],
    ink: Color(0xFF0E3150),
    chip: Color(0xE0FFFFFF),
    line: Color(0xFFD6E3EE),
    inputBorder: Color(0xFFA9BCCB),
    selected: Color(0xFFE2F0FA),
    skeleton: Color(0xFFD9E5EF),
    skeletonShine: Color(0xFFEEF4F9),
    paperSkeleton: Color(0xFFEADFC6),
    paperSkeletonShine: Color(0xFFF6EEDB),
    bottleGlass: Color(0x8CFFFFFF),
    bottleLine: Colors.white,
  );

  /// 밤바다(어두운 톤).
  static const dark = AppPalette(
    night: true,
    primary: Color(0xFF7CC0F5),
    onPrimary: Color(0xFF06213A),
    background: Color(0xFF101C2B),
    card: Color(0xFF172638),
    text: Color(0xFFE6EEF6),
    muted: Color(0xFF9DB0C3),
    paper: Color(0xFF262019),
    accent: Color(0xFF5FD0BD),
    danger: Color(0xFFFF9A90),
    seaTop: Color(0xFF081428),
    seaMiddle: Color(0xFF0D2644),
    seaBottom: Color(0xFF0C3A62),
    seaGlow: Color(0x47BED6FF),
    waves: [
      Color(0x8C14466F),
      Color(0xA6103A5E),
      Color(0xBF0C2E4C),
      Color(0xE608223A),
    ],
    ink: Color(0xFFDCEBFA),
    chip: Color(0xD6142438),
    line: Color(0xFF2A3C50),
    inputBorder: Color(0xFF3D5268),
    selected: Color(0xFF1F3A52),
    skeleton: Color(0xFF22344A),
    skeletonShine: Color(0xFF30475F),
    paperSkeleton: Color(0xFF3A3126),
    paperSkeletonShine: Color(0xFF4B4032),
    bottleGlass: Color(0x3896BEE6),
    bottleLine: Color(0xFFBFD9F2),
  );
}

/// 지금 쓰는 색감의 색. 색감이 바뀌면 앱이 화면 전체를 다시 그린다(main.dart).
class AppColors {
  static AppPalette current = AppPalette.day;

  static bool get night => current.night;
  static Color get primary => current.primary;
  static Color get onPrimary => current.onPrimary;
  static Color get background => current.background;
  static Color get card => current.card;
  static Color get text => current.text;
  static Color get muted => current.muted;
  static Color get paper => current.paper;
  static Color get accent => current.accent;
  static Color get danger => current.danger;
  static Color get seaTop => current.seaTop;
  static Color get seaMiddle => current.seaMiddle;
  static Color get seaBottom => current.seaBottom;
  static Color get seaGlow => current.seaGlow;
  static List<Color> get waves => current.waves;
  static Color get ink => current.ink;
  static Color get chip => current.chip;
  static Color get line => current.line;
  static Color get inputBorder => current.inputBorder;
  static Color get selected => current.selected;
  static Color get skeleton => current.skeleton;
  static Color get skeletonShine => current.skeletonShine;
  static Color get paperSkeleton => current.paperSkeleton;
  static Color get paperSkeletonShine => current.paperSkeletonShine;
  static Color get bottleGlass => current.bottleGlass;
  static Color get bottleLine => current.bottleLine;

  /// [background] 색 버튼 위에 올릴 글자·아이콘 색(밝은 바탕에는 어두운 글자).
  static Color on(Color background) => background.computeLuminance() > 0.4
      ? const Color(0xFF06213A)
      : Colors.white;
}

const double kRadius = 12;

ThemeData buildTheme([AppPalette p = AppPalette.day]) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: p.night ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: p.primary,
        onPrimary: p.onPrimary,
        surface: p.background,
        onSurface: p.text,
        onSurfaceVariant: p.muted,
        error: p.danger,
        onError: AppColors.on(p.danger),
        outline: p.inputBorder,
        outlineVariant: p.line,
      );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kRadius),
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(kRadius),
    borderSide: BorderSide(color: c, width: w),
  );
  final base = p.night ? ThemeData.dark() : ThemeData.light();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    iconTheme: IconThemeData(color: p.text),
    dividerTheme: DividerThemeData(color: p.line),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: p.text,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
        foregroundColor: p.primary,
        side: BorderSide(color: p.line),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(p.inputBorder),
      enabledBorder: border(p.inputBorder),
      focusedBorder: border(p.primary, 2),
      errorBorder: border(p.danger),
      focusedErrorBorder: border(p.danger, 2),
      helperStyle: TextStyle(color: p.muted, fontSize: 13),
      errorStyle: TextStyle(color: p.danger, fontSize: 13),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
