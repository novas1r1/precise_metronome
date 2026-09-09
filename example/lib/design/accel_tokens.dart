import 'package:flutter/widgets.dart';

/// Design tokens for the Accel design system, transcribed from
/// `docs/design_system/tokens/*.css`. Values are kept verbatim so the
/// Flutter app and the HTML UI kit stay in sync.

// ---------------------------------------------------------------- colors

abstract final class AccelColors {
  // Palette.
  static const navy950 = Color(0xFF070B18);
  static const navy900 = Color(0xFF0B1124);
  static const navy800 = Color(0xFF111A33);
  static const navy700 = Color(0xFF182342);

  static const coral300 = Color(0xFFFF9A8A);
  static const coral400 = Color(0xFFFF7A63);
  static const coral500 = Color(0xFFFF5E45);
  static const coral600 = Color(0xFFE8432B);

  static const mint500 = Color(0xFF2EDCA7);
  static const sun400 = Color(0xFFFFC857);
  static const sky400 = Color(0xFF6FB4FF);

  static const ink100 = Color(0xFFEEF1FA);
  static const ink200 = Color(0xFFC9D0E3);
  static const ink300 = Color(0xFF98A3C2);
  static const ink400 = Color(0xFF6A7699);

  // Semantic.
  static const bg = navy950;
  static const surfaceGlass = Color(0x0DFFFFFF); // white 5%
  static const surfaceGlassStrong = Color(0x17FFFFFF); // white 9%
  static const surfaceGlassBorder = Color(0x1AFFFFFF); // white 10%
  static const surfaceInput = Color(0x0FFFFFFF); // white 6%

  static const textPrimary = ink100;
  static const textSecondary = ink300;
  static const textMuted = ink400;
  static const textOnAccent = navy950;

  static const accent = coral500;
  static const accentHover = coral400;
  static const accentPress = coral600;
  static const accentSoft = Color(0x29FF5E45); // coral 16%
  static const accentGlow = Color(0x8CFF5E45); // coral 55%

  static const positive = mint500;
  static const positiveSoft = Color(0x292EDCA7);
  static const info = sky400;
  static const infoSoft = Color(0x296FB4FF);

  static const borderStrong = Color(0x2EFFFFFF); // white 18%

  /// Ring / dot colors: coral while climbing, sky blue on the way back
  /// down, sun yellow on an accented beat.
  static const beatUp = coral500;
  static const beatDown = sky400;
  static const beatAccent = sun400;
}

// --------------------------------------------------------------- spacing

abstract final class AccelRadius {
  static const sm = Radius.circular(8);
  static const md = Radius.circular(14);
  static const lg = Radius.circular(22);
  static const xl = Radius.circular(32);

  static const smAll = BorderRadius.all(sm);
  static const mdAll = BorderRadius.all(md);
  static const lgAll = BorderRadius.all(lg);
  static const xlAll = BorderRadius.all(xl);
  static const pill = BorderRadius.all(Radius.circular(999));
}

abstract final class AccelControl {
  static const sm = 36.0;
  static const md = 44.0;
  static const lg = 56.0;
  static const xl = 72.0;
}

// ---------------------------------------------------------------- motion

abstract final class AccelMotion {
  static const easeOut = Cubic(0.16, 1, 0.3, 1);
  static const easeInOut = Cubic(0.65, 0, 0.35, 1);
  static const spring = Cubic(0.34, 1.56, 0.64, 1);

  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 420);

  /// `accel-beat`: the ring expanding out of the dial on every beat.
  static const beat = Duration(milliseconds: 520);
}

// ------------------------------------------------------------ typography

abstract final class AccelType {
  static const displayFamily = 'Archivo';
  static const monoFamily = 'IBMPlexMono';

  /// Tabular, lining figures — numbers are the hero and must not jitter.
  static const List<FontFeature> tabular = [
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];

  /// Archivo is bundled as a variable font, so weight comes from the `wght`
  /// axis. [FontWeight] alone would not move a variable axis; it is passed
  /// too so fallback fonts still render at a sensible weight.
  static TextStyle display({
    required double size,
    double weight = 800,
    double? height,
    double letterSpacing = 0,
    Color color = AccelColors.textPrimary,
    bool tabularFigures = false,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: _nearestWeight(weight),
      fontVariations: [FontVariation('wght', weight)],
      fontFeatures: tabularFigures ? tabular : null,
    );
  }

  static TextStyle mono({
    required double size,
    double weight = 500,
    double letterSpacing = 0,
    Color color = AccelColors.textSecondary,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: _nearestWeight(weight),
      fontFeatures: tabular,
    );
  }

  /// The tiny tracked all-caps label (`--text-label` / `--tracking-label`).
  static TextStyle label({Color color = AccelColors.textMuted}) => display(
    size: 11,
    weight: 600,
    letterSpacing: 0.14 * 11,
    color: color,
  );

  static FontWeight _nearestWeight(double weight) {
    final index = ((weight / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }
}

// --------------------------------------------------------------- shadows

abstract final class AccelShadow {
  static const glass = [
    BoxShadow(
      color: Color(0x99000000),
      blurRadius: 50,
      spreadRadius: -20,
      offset: Offset(0, 20),
    ),
  ];

  static const float = [
    BoxShadow(
      color: Color(0xCC000000),
      blurRadius: 80,
      spreadRadius: -30,
      offset: Offset(0, 30),
    ),
  ];

  static List<BoxShadow> accentGlow({double opacity = 1}) => [
    BoxShadow(
      color: AccelColors.accentGlow.withValues(
        alpha: AccelColors.accentGlow.a * opacity,
      ),
      blurRadius: 40,
    ),
  ];
}
