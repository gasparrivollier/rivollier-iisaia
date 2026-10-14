import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors ported from design/yvoty-ui/tokens.css (oklch -> sRGB, computed once).
/// Alpha variants (the `/ 0.NN` suffixes in the CSS) are applied at call sites
/// via `.withValues(alpha: ...)` rather than hardcoded as separate constants.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF35251B);
  static const inkSoft = Color(0xFF615248);
  static const inkFaint = Color(0xFF8A7D75);
  static const paper = Color(0xFFF9F3E8);
  static const paperRaised = Color(0xFFFEFBF6);
  static const lineBase = Color(0xFF706052);
  static const lineStrongBase = Color(0xFF544438);
  static const forest = Color(0xFF195C2E);
  static const forestHover = Color(0xFF085023);
  static const terracotta = Color(0xFFAE5528);
  static const gold = Color(0xFFC49F4D);
  static const goldDarkText = Color(0xFF805D00);
  static const goldNoteText = Color(0xFF634800);

  static Color get line => lineBase.withValues(alpha: 0.16);
  static Color get lineStrong => lineStrongBase.withValues(alpha: 0.3);
  static Color get forestSoft => forest.withValues(alpha: 0.12);
  static Color get terracottaSoft => terracotta.withValues(alpha: 0.14);
  static Color get goldSoft => gold.withValues(alpha: 0.18);
  static Color get cardShadow => ink.withValues(alpha: 0.06);
}

class AppRadius {
  AppRadius._();
  static const sm = 4.0;
  static const md = 7.0;
  static const lg = 8.0;
  static const xl = 9.0;
  static const xxl = 12.0;
}

class AppSpacing {
  AppSpacing._();
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 16.0;
  static const xxl = 20.0;
}

ThemeData buildYvotyTheme() {
  final base = ThemeData.light(useMaterial3: true);
  final bodyFont = GoogleFonts.figtreeTextTheme(base.textTheme);
  final serifFont = GoogleFonts.sourceSerif4();

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.forest,
      onPrimary: AppColors.paper,
      secondary: AppColors.terracotta,
      surface: AppColors.paperRaised,
      onSurface: AppColors.ink,
    ),
    textTheme: bodyFont.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    extensions: [YvotyTypography(serif: serifFont.fontFamily!)],
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.paper,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: AppColors.lineStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
  );
}

/// Holds the serif font family name (Source Serif 4) for the `.serif`/`.serif-i`
/// accents used throughout the mockups, alongside the default Figtree body font.
class YvotyTypography extends ThemeExtension<YvotyTypography> {
  const YvotyTypography({required this.serif});

  final String serif;

  TextStyle serifStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    FontStyle fontStyle = FontStyle.normal,
  }) => TextStyle(
    fontFamily: serif,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.ink,
    fontStyle: fontStyle,
  );

  @override
  YvotyTypography copyWith({String? serif}) =>
      YvotyTypography(serif: serif ?? this.serif);

  @override
  YvotyTypography lerp(ThemeExtension<YvotyTypography>? other, double t) =>
      this;
}

extension YvotyThemeX on BuildContext {
  YvotyTypography get yvotyType => Theme.of(this).extension<YvotyTypography>()!;
}
