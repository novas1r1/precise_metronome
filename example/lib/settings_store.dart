import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'gap_settings.dart';

/// What Accel remembers between runs: the settings last used, and the gap
/// presets the user saved.
///
/// Both are kept as one JSON blob each, so adding a setting needs no
/// migration: anything a previous version did not write falls back to its
/// default when it is read.
class SettingsStore {
  /// The keys carry a version, so a future format can be told apart from
  /// this one instead of being misread.
  static const String settingsKey = 'accel.settings.v1';
  static const String presetsKey = 'accel.gapPresets.v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// The settings last written, or an empty map on a first run or after
  /// anything unreadable.
  Future<Map<String, Object?>> loadSettings() async {
    final text = (await _prefs).getString(settingsKey);
    return _decodeMap(text);
  }

  Future<void> saveSettings(Map<String, Object?> settings) async {
    await (await _prefs).setString(settingsKey, jsonEncode(settings));
  }

  /// The user's own presets, oldest first. Entries that cannot be read are
  /// left out rather than failing the lot.
  Future<List<GapPreset>> loadPresets() async {
    final text = (await _prefs).getString(presetsKey);
    if (text == null) return const [];
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (GapPreset.fromJson(entry) case final preset?) preset,
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> savePresets(List<GapPreset> presets) async {
    await (await _prefs).setString(
      presetsKey,
      jsonEncode([for (final preset in presets) preset.toJson()]),
    );
  }

  static Map<String, Object?> _decodeMap(String? text) {
    if (text == null) return const {};
    try {
      final decoded = jsonDecode(text);
      return decoded is Map ? decoded.cast<String, Object?>() : const {};
    } on FormatException {
      return const {};
    }
  }
}
