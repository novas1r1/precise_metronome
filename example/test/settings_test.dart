// What Accel remembers: the settings it reopens with, the gap presets, and
// the background playback it holds while it plays.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precise_metronome/precise_metronome.dart';
import 'package:precise_metronome_example/accel_metronome.dart';
import 'package:precise_metronome_example/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const method = MethodChannel('precise_metronome');
  const beatChannel = EventChannel('precise_metronome/beats');
  const rampChannel = EventChannel('precise_metronome/ramp');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final List<MethodCall> calls = [];
  MockStreamHandlerEventSink? ramp;

  setUp(() {
    calls.clear();
    ramp = null;
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      beatChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockStreamHandler(
      rampChannel,
      MockStreamHandler.inline(onListen: (_, sink) => ramp = sink),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(beatChannel, null);
    messenger.setMockStreamHandler(rampChannel, null);
  });

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<AccelMetronome> open() async {
    final m = AccelMetronome();
    await m.init();
    await settle();
    calls.clear();
    return m;
  }

  /// Closes the metronome, which writes anything still waiting.
  Future<void> close(AccelMetronome m) async {
    m.dispose();
    await settle();
  }

  group('settings', () {
    test('come back the way they were left', () async {
      final first = await open();
      await first.setTempo(96);
      await first.setSignature(TimeSignature(3, 4));
      await first.setSubdivision(Subdivision.triplet);
      await first.setVoice(MetronomeVoice.wood);
      await first.setVolume(0.42);
      first.setBarsPerStep(8);
      await first.setGapEnabled(true);
      await first.setGapMode(GapMode.ladder);
      await first.setGapStartSilentBars(3);
      await close(first);

      final second = await open();
      expect(second.startBpm, 96);
      expect(second.signature, TimeSignature(3, 4));
      expect(second.subdivision, Subdivision.triplet);
      expect(second.voice, MetronomeVoice.wood);
      expect(second.volume, closeTo(0.42, 1e-9));
      expect(second.barsPerStep, 8);
      expect(second.gapEnabled, isTrue);
      expect(second.gapMode, GapMode.ladder);
      expect(second.gapStartSilentBars, 3);
      // The trainer was on, so dynamic mode stays off, as on screen.
      expect(second.dynamicMode, isFalse);
    });

    test('a remembered gap pattern reaches the engine on start', () async {
      final first = await open();
      await first.setGapEnabled(true);
      await first.setGapClickBars(1);
      await first.setGapSilentBars(1);
      await close(first);

      final second = await open();
      await second.start();
      final plan = calls.firstWhere((c) => c.method == 'setGapPlan');
      expect(((plan.arguments as Map)['silent'] as List).take(4), [
        false,
        true,
        false,
        true,
      ]);
    });

    test('a store full of nonsense still starts the app', () async {
      SharedPreferences.setMockInitialValues({
        SettingsStore.settingsKey: '{"tempo": "fast", "gap": 7, "accents": 3}',
        SettingsStore.presetsKey: 'not json at all',
      });
      final m = await open();
      expect(m.startBpm, 60, reason: 'the default is kept');
      expect(m.gapSettings, const GapSettings());
      expect(m.customGapPresets, isEmpty);
      expect(m.initError, isNull);
    });

    test('settings out of range are pulled back in', () async {
      SharedPreferences.setMockInitialValues({
        SettingsStore.settingsKey:
            '{"tempo": 900, "gap": {"clickBars": 99, "silentChance": 5}}',
      });
      final m = await open();
      expect(m.startBpm, AccelMetronome.maxBpm);
      expect(m.gapClickBars, GapSettings.maxBars);
      expect(m.gapSilentChance, GapSettings.maxChance);
    });
  });

  group('gap presets', () {
    test('ship with five, and the defaults match Classic', () async {
      final m = await open();
      expect(builtInGapPresets, hasLength(5));
      expect(m.gapPresets.map((p) => p.name), [
        'Warm-up',
        'Classic',
        'Advanced',
        'Light random',
        'Ladder',
      ]);
      expect(m.selectedGapPreset?.name, 'Classic');
    });

    test('playing one turns the trainer on and dynamic mode off', () async {
      final m = await open();
      expect(m.dynamicMode, isTrue);

      await m.applyGapPreset(builtInGapPresets.last);
      expect(m.gapEnabled, isTrue);
      expect(m.dynamicMode, isFalse);
      expect(m.gapMode, GapMode.ladder);
      expect(m.selectedGapPreset?.name, 'Ladder');
    });

    test('save, rename and delete your own', () async {
      final m = await open();
      await m.setGapEnabled(true);
      await m.setGapSilentBars(6);
      await m.saveGapPreset('  Long gaps  ');

      expect(m.customGapPresets.map((p) => p.name), ['Long gaps']);
      expect(m.selectedGapPreset?.name, 'Long gaps');

      await m.renameGapPreset(m.customGapPresets.first, 'Very long gaps');
      expect(m.customGapPresets.map((p) => p.name), ['Very long gaps']);

      await m.deleteGapPreset(m.customGapPresets.first);
      expect(m.customGapPresets, isEmpty);
      expect(m.selectedGapPreset, isNull, reason: 'nothing matches 2 / 6');
    });

    test('saving the same name twice leaves one preset', () async {
      final m = await open();
      await m.setGapEnabled(true);
      await m.saveGapPreset('Mine');
      await m.setGapSilentBars(5);
      await m.saveGapPreset('Mine');

      expect(m.customGapPresets, hasLength(1));
      expect(m.customGapPresets.single.settings.silentBars, 5);
    });

    test('an empty name saves nothing', () async {
      final m = await open();
      await m.saveGapPreset('   ');
      expect(m.customGapPresets, isEmpty);
    });

    test('are there again next time', () async {
      final first = await open();
      await first.setGapEnabled(true);
      await first.setGapMode(GapMode.random);
      await first.saveGapPreset('Coin toss');
      await close(first);

      final second = await open();
      expect(second.customGapPresets.map((p) => p.name), ['Coin toss']);
      expect(second.customGapPresets.single.settings.mode, GapMode.random);
    });
  });

  group('background playback', () {
    test('is held while the metronome plays and released after', () async {
      final m = await open();
      await m.setGapEnabled(true);
      await m.start();
      expect(calls.map((c) => c.method), contains('enableBackgroundPlayback'));

      calls.clear();
      await m.stop();
      expect(calls.map((c) => c.method), contains('disableBackgroundPlayback'));
    });

    test('a ramp that ends itself releases it too', () async {
      final m = await open();
      // Dynamic mode is on by default, so this starts a ramp.
      await m.start();
      calls.clear();

      ramp!.success({'stepIndex': 24, 'bpm': 60.0, 'finished': true});
      await settle();

      expect(m.isPlaying, isFalse);
      expect(calls.map((c) => c.method), contains('disableBackgroundPlayback'));
    });
  });
}
