import 'package:flutter/material.dart';

/// 分类色系 ThemeExtension（design-system tokens.colors 分类色系）。
/// Material 3 ColorScheme 之外的暖盘专用色统一从这里取，禁止散落硬编码。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.olive,
    required this.oliveSoft,
    required this.rose,
    required this.roseSoft,
    required this.teal,
    required this.tealSoft,
    required this.violet,
    required this.violetSoft,
    required this.gold,
    required this.goldSoft,
    required this.goldTextOnSoft,
    required this.inkFaint,
    required this.toastBg,
    required this.toastText,
  });

  final Color olive;
  final Color oliveSoft;
  final Color rose;
  final Color roseSoft;
  final Color teal;
  final Color tealSoft;
  final Color violet;
  final Color violetSoft;
  final Color gold;
  final Color goldSoft;
  final Color goldTextOnSoft;
  final Color inkFaint;
  final Color toastBg;
  final Color toastText;

  static const light = AppColors(
    olive: Color(0xFF79905B), oliveSoft: Color(0xFFE4EAD5),
    rose: Color(0xFFC77B8E), roseSoft: Color(0xFFF6E2E6),
    teal: Color(0xFF559487), tealSoft: Color(0xFFDEEBE6),
    violet: Color(0xFF8B7DB0), violetSoft: Color(0xFFE9E4F2),
    gold: Color(0xFFD9A441), goldSoft: Color(0xFFF6EBCE),
    goldTextOnSoft: Color(0xFF9C7313),
    inkFaint: Color(0xFFA3947C),
    toastBg: Color(0xF0322A1C),
    toastText: Color(0xFFFBF2E3),
  );

  static const dark = AppColors(
    olive: Color(0xFF9CB37E), oliveSoft: Color(0xFF2C3421),
    rose: Color(0xFFD892A4), roseSoft: Color(0xFF3A282E),
    teal: Color(0xFF74AC9E), tealSoft: Color(0xFF1F302C),
    violet: Color(0xFFA99BCB), violetSoft: Color(0xFF2E2A3D),
    gold: Color(0xFFE0B45E), goldSoft: Color(0xFF39301A),
    goldTextOnSoft: Color(0xFFE0B45E),
    inkFaint: Color(0xFF847761),
    toastBg: Color(0xF0322A1C),
    toastText: Color(0xFFFBF2E3),
  );

  @override
  AppColors copyWith({Color? olive, Color? oliveSoft, Color? rose, Color? roseSoft,
      Color? teal, Color? tealSoft, Color? violet, Color? violetSoft,
      Color? gold, Color? goldSoft, Color? goldTextOnSoft, Color? inkFaint,
      Color? toastBg, Color? toastText}) {
    return AppColors(
      olive: olive ?? this.olive, oliveSoft: oliveSoft ?? this.oliveSoft,
      rose: rose ?? this.rose, roseSoft: roseSoft ?? this.roseSoft,
      teal: teal ?? this.teal, tealSoft: tealSoft ?? this.tealSoft,
      violet: violet ?? this.violet, violetSoft: violetSoft ?? this.violetSoft,
      gold: gold ?? this.gold, goldSoft: goldSoft ?? this.goldSoft,
      goldTextOnSoft: goldTextOnSoft ?? this.goldTextOnSoft,
      inkFaint: inkFaint ?? this.inkFaint,
      toastBg: toastBg ?? this.toastBg, toastText: toastText ?? this.toastText,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      olive: Color.lerp(olive, other.olive, t)!,
      oliveSoft: Color.lerp(oliveSoft, other.oliveSoft, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      roseSoft: Color.lerp(roseSoft, other.roseSoft, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealSoft: Color.lerp(tealSoft, other.tealSoft, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      violetSoft: Color.lerp(violetSoft, other.violetSoft, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      goldTextOnSoft: Color.lerp(goldTextOnSoft, other.goldTextOnSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      toastBg: Color.lerp(toastBg, other.toastBg, t)!,
      toastText: Color.lerp(toastText, other.toastText, t)!,
    );
  }
}

/// 按 colorKey 取分类色（strong/soft 色对）。
({Color strong, Color soft}) categoryColor(AppColors c, String key) {
  switch (key) {
    case 'olive':
      return (strong: c.olive, soft: c.oliveSoft);
    case 'rose':
      return (strong: c.rose, soft: c.roseSoft);
    case 'teal':
      return (strong: c.teal, soft: c.tealSoft);
    case 'violet':
      return (strong: c.violet, soft: c.violetSoft);
    case 'gold':
      return (strong: c.goldTextOnSoft, soft: c.goldSoft);
    case 'accent':
    default:
      // accent 系从 ColorScheme 取不到，这里通过主题扩展近似（与原型 t-org 一致）
      return (strong: const Color(0xFFBE5E18), soft: const Color(0xFFF8E4CF));
  }
}

/// 奶油暖盘主题（design-system material3.light_scheme / dark_scheme 逐项落地）。
class AppTheme {
  AppTheme._();

  static const pagePadding = 20.0;
  static const radiusLg = 24.0;
  static const radiusMd = 16.0;

  static ColorScheme get _light => const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFFDE7931), onPrimary: Color(0xFFFFF7EC),
        primaryContainer: Color(0xFFF8E4CF), onPrimaryContainer: Color(0xFFBE5E18),
        secondary: Color(0xFF559487), onSecondary: Color(0xFFFFFFFF),
        tertiary: Color(0xFF8B7DB0), onTertiary: Color(0xFFFFFFFF),
        error: Color(0xFFCB5840), onError: Color(0xFFFFFFFF),
        surface: Color(0xFFFBF4E8), onSurface: Color(0xFF3D352A),
        surfaceContainerHighest: Color(0xFFF3E9D6),
        surfaceContainerLowest: Color(0xFFFFFCF5),
        outline: Color(0xFFEBDEC7), outlineVariant: Color(0xFFF0E6D3),
      );

  static ColorScheme get _dark => const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFE08A45), onPrimary: Color(0xFFFFF6EA),
        primaryContainer: Color(0xFF3D2D1B), onPrimaryContainer: Color(0xFFEF9E5D),
        secondary: Color(0xFF74AC9E), onSecondary: Color(0xFF10201C),
        tertiary: Color(0xFFA99BCB), onTertiary: Color(0xFF1E1930),
        error: Color(0xFFE07A5F), onError: Color(0xFF2A130B),
        surface: Color(0xFF1C1712), onSurface: Color(0xFFF0E7D6),
        surfaceContainerHighest: Color(0xFF322A20),
        surfaceContainerLowest: Color(0xFF262019),
        outline: Color(0xFF41382A), outlineVariant: Color(0xFF37301F),
      );

  static ThemeData light() => _build(Brightness.light, AppColors.light);
  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final scheme = brightness == Brightness.light ? _light : _dark;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      extensions: [colors],
      textTheme: numericOf(base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      )),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: scheme.outline),
        backgroundColor: scheme.surfaceContainerLowest,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.toastBg,
        contentTextStyle: TextStyle(color: colors.toastText, fontSize: 13.5, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        modalBackgroundColor: scheme.surfaceContainerLowest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    );
  }
}

/// 衬线数字风格（design-system typography.numeric：Fraunces 缺省回退 serif）。
TextTheme numericOf(TextTheme base) {
  const family = ['Fraunces', 'serif'];
  TextStyle f(TextStyle? s) => (s ?? const TextStyle()).copyWith(fontFamilyFallback: family);
  return base.copyWith(
    displayLarge: f(base.displayLarge), displayMedium: f(base.displayMedium),
    displaySmall: f(base.displaySmall), headlineLarge: f(base.headlineLarge),
    headlineMedium: f(base.headlineMedium), headlineSmall: f(base.headlineSmall),
    titleLarge: f(base.titleLarge),
  );
}
