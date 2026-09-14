import 'package:flutter/foundation.dart';
import 'package:precise_metronome/precise_metronome.dart';

/// Which pattern the gap trainer silences bars by.
enum GapMode { fixed, random, ladder }

/// Everything the gap trainer plays by: the mode, the parameters of all
/// three modes, and how gaps are shown.
///
/// Every mode keeps its own parameters, so switching modes back and forth
/// loses none of them. The whole thing is what a preset stores and what
/// Accel remembers between runs.
@immutable
class GapSettings {
  const GapSettings({
    this.mode = GapMode.fixed,
    this.clickBars = 2,
    this.silentBars = 2,
    this.silentChance = 0.3,
    this.maxSilentRun = 2,
    this.startSilentBars = 1,
    this.maxSilentBars = 8,
    this.cyclesPerStep = 2,
    this.hideBeatWhenSilent = true,
    this.showRemainingSilentBars = false,
  });

  /// What the trainer offers: 1–8 click and silent bars, a ladder that tops
  /// out at 16 silent bars after 1–8 cycles a step, a 10–80 % chance of
  /// silence, and at most 1–4 silent bars in a row.
  static const int minBars = 1;
  static const int maxBars = 8;
  static const int maxLadderBars = 16;
  static const int minCycles = 1;
  static const int maxCycles = 8;
  static const double minChance = 0.1;
  static const double maxChance = 0.8;
  static const double chanceStep = 0.05;
  static const int minRun = 1;
  static const int maxRun = 4;

  final GapMode mode;

  /// Audible bars a cycle opens with, in [GapMode.fixed] and
  /// [GapMode.ladder].
  final int clickBars;

  /// Silent bars a cycle ends with, in [GapMode.fixed].
  final int silentBars;

  /// Chance of a silent bar, and the most that may follow each other, in
  /// [GapMode.random].
  final double silentChance;
  final int maxSilentRun;

  /// Where the ladder's gap starts, where it tops out, and how many cycles
  /// it plays before it grows, in [GapMode.ladder].
  final int startSilentBars;
  final int maxSilentBars;
  final int cyclesPerStep;

  /// Hold the beat indicator back in a silent bar, and count out how many
  /// silent bars are left.
  final bool hideBeatWhenSilent;
  final bool showRemainingSilentBars;

  GapSettings copyWith({
    GapMode? mode,
    int? clickBars,
    int? silentBars,
    double? silentChance,
    int? maxSilentRun,
    int? startSilentBars,
    int? maxSilentBars,
    int? cyclesPerStep,
    bool? hideBeatWhenSilent,
    bool? showRemainingSilentBars,
  }) {
    return GapSettings(
      mode: mode ?? this.mode,
      clickBars: clickBars ?? this.clickBars,
      silentBars: silentBars ?? this.silentBars,
      silentChance: silentChance ?? this.silentChance,
      maxSilentRun: maxSilentRun ?? this.maxSilentRun,
      startSilentBars: startSilentBars ?? this.startSilentBars,
      maxSilentBars: maxSilentBars ?? this.maxSilentBars,
      cyclesPerStep: cyclesPerStep ?? this.cyclesPerStep,
      hideBeatWhenSilent: hideBeatWhenSilent ?? this.hideBeatWhenSilent,
      showRemainingSilentBars:
          showRemainingSilentBars ?? this.showRemainingSilentBars,
    );
  }

  /// The pattern these settings describe, for the package.
  GapPattern toPattern() => switch (mode) {
    GapMode.fixed => GapPattern.fixed(
      clickBars: clickBars,
      silentBars: silentBars,
    ),
    GapMode.random => GapPattern.random(
      silentProbability: silentChance,
      maxConsecutiveSilent: maxSilentRun,
    ),
    GapMode.ladder => GapPattern.ladder(
      clickBars: clickBars,
      startSilentBars: startSilentBars,
      maxSilentBars: maxSilentBars,
      cyclesPerStep: cyclesPerStep,
    ),
  };

  /// The same settings with every value inside the range the UI offers, so
  /// a store written by an older version can never describe an impossible
  /// pattern.
  GapSettings clamped() {
    final start = startSilentBars.clamp(minBars, maxBars);
    return GapSettings(
      mode: mode,
      clickBars: clickBars.clamp(minBars, maxBars),
      silentBars: silentBars.clamp(minBars, maxBars),
      silentChance: silentChance.isNaN
          ? const GapSettings().silentChance
          : silentChance.clamp(minChance, maxChance),
      maxSilentRun: maxSilentRun.clamp(minRun, maxRun),
      startSilentBars: start,
      maxSilentBars: maxSilentBars.clamp(start, maxLadderBars),
      cyclesPerStep: cyclesPerStep.clamp(minCycles, maxCycles),
      hideBeatWhenSilent: hideBeatWhenSilent,
      showRemainingSilentBars: showRemainingSilentBars,
    );
  }

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'clickBars': clickBars,
    'silentBars': silentBars,
    'silentChance': silentChance,
    'maxSilentRun': maxSilentRun,
    'startSilentBars': startSilentBars,
    'maxSilentBars': maxSilentBars,
    'cyclesPerStep': cyclesPerStep,
    'hideBeat': hideBeatWhenSilent,
    'countSilent': showRemainingSilentBars,
  };

  /// Reads settings a previous run wrote. Anything missing or unreadable
  /// falls back to the default, and every value ends up in range.
  factory GapSettings.fromJson(Map<String, Object?> json) {
    const fallback = GapSettings();
    return GapSettings(
      mode: GapMode.values.firstWhere(
        (mode) => mode.name == json['mode'],
        orElse: () => fallback.mode,
      ),
      clickBars: readInt(json['clickBars'], fallback.clickBars),
      silentBars: readInt(json['silentBars'], fallback.silentBars),
      silentChance: readDouble(json['silentChance'], fallback.silentChance),
      maxSilentRun: readInt(json['maxSilentRun'], fallback.maxSilentRun),
      startSilentBars: readInt(
        json['startSilentBars'],
        fallback.startSilentBars,
      ),
      maxSilentBars: readInt(json['maxSilentBars'], fallback.maxSilentBars),
      cyclesPerStep: readInt(json['cyclesPerStep'], fallback.cyclesPerStep),
      hideBeatWhenSilent: readBool(
        json['hideBeat'],
        fallback.hideBeatWhenSilent,
      ),
      showRemainingSilentBars: readBool(
        json['countSilent'],
        fallback.showRemainingSilentBars,
      ),
    ).clamped();
  }

  /// Readers the settings and the store share: a value of the wrong type,
  /// or none at all, leaves the fallback in place.
  static int readInt(Object? value, int fallback) =>
      value is num && value.isFinite ? value.toInt() : fallback;

  static double readDouble(Object? value, double fallback) =>
      value is num && value.isFinite ? value.toDouble() : fallback;

  static bool readBool(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  @override
  bool operator ==(Object other) =>
      other is GapSettings &&
      other.mode == mode &&
      other.clickBars == clickBars &&
      other.silentBars == silentBars &&
      other.silentChance == silentChance &&
      other.maxSilentRun == maxSilentRun &&
      other.startSilentBars == startSilentBars &&
      other.maxSilentBars == maxSilentBars &&
      other.cyclesPerStep == cyclesPerStep &&
      other.hideBeatWhenSilent == hideBeatWhenSilent &&
      other.showRemainingSilentBars == showRemainingSilentBars;

  @override
  int get hashCode => Object.hash(
    mode,
    clickBars,
    silentBars,
    silentChance,
    maxSilentRun,
    startSilentBars,
    maxSilentBars,
    cyclesPerStep,
    hideBeatWhenSilent,
    showRemainingSilentBars,
  );
}

/// A named gap setting the user can recall: the ones Accel ships with, and
/// the ones they save themselves.
@immutable
class GapPreset {
  const GapPreset({required this.name, required this.settings});

  final String name;
  final GapSettings settings;

  Map<String, Object?> toJson() => {
    'name': name,
    'settings': settings.toJson(),
  };

  /// `null` for a preset without a usable name, so one bad entry cannot
  /// take the rest of the list down with it.
  static GapPreset? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final settings = json['settings'];
    return GapPreset(
      name: name,
      settings: GapSettings.fromJson(
        settings is Map ? settings.cast<String, Object?>() : const {},
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GapPreset && other.name == name && other.settings == settings;

  @override
  int get hashCode => Object.hash(name, settings);
}

/// The presets Accel ships with, from easiest to hardest.
const List<GapPreset> builtInGapPresets = [
  GapPreset(
    name: 'Warm-up',
    settings: GapSettings(clickBars: 4, silentBars: 1),
  ),
  GapPreset(
    name: 'Classic',
    settings: GapSettings(clickBars: 2, silentBars: 2),
  ),
  GapPreset(
    name: 'Advanced',
    settings: GapSettings(clickBars: 1, silentBars: 3),
  ),
  GapPreset(
    name: 'Light random',
    settings: GapSettings(
      mode: GapMode.random,
      silentChance: 0.2,
      maxSilentRun: 1,
    ),
  ),
  GapPreset(
    name: 'Ladder',
    settings: GapSettings(
      mode: GapMode.ladder,
      clickBars: 2,
      startSilentBars: 1,
      maxSilentBars: 8,
      cyclesPerStep: 2,
    ),
  ),
];
