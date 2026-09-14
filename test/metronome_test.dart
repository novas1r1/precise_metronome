import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precise_metronome/precise_metronome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('precise_metronome');

  final List<MethodCall> calls = [];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('init() pushes full state to native', () async {
    final m = Metronome();
    await m.init();

    final methods = calls.map((c) => c.method).toList();
    expect(methods, contains('init'));
    // After init, defaults should be pushed.
    expect(methods, contains('setTempo'));
    expect(methods, contains('setTimeSignature'));
    expect(methods, contains('setSubdivision'));
    expect(methods, contains('setVoice'));
    expect(methods, contains('setVolume'));
  });

  test('default subdivision is none', () async {
    final m = Metronome();
    await m.init();
    expect(m.subdivision, Subdivision.none);

    final subdivCall =
        calls.firstWhere((c) => c.method == 'setSubdivision');
    expect((subdivCall.arguments as Map)['pulsesPerBeat'], 1);
  });

  test('start() without delay sends initialDelayMs 0', () async {
    final m = Metronome();
    await m.init();
    calls.clear();

    await m.start();

    final call = calls.firstWhere((c) => c.method == 'start');
    expect((call.arguments as Map)['initialDelayMs'], 0);
  });

  test('start(initialDelay:) sends initialDelayMs', () async {
    final m = Metronome();
    await m.init();
    calls.clear();

    await m.start(initialDelay: const Duration(milliseconds: 250));

    final call = calls.firstWhere((c) => c.method == 'start');
    expect((call.arguments as Map)['initialDelayMs'], 250);
    expect(m.isPlaying, isTrue);
  });

  test('start() rejects negative initialDelay', () async {
    final m = Metronome();
    await m.init();

    expect(
      () => m.start(initialDelay: const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
  });

  test('nudge() sends deltaMs while playing', () async {
    final m = Metronome();
    await m.init();
    await m.start();
    calls.clear();

    await m.nudge(const Duration(milliseconds: -25));

    final call = calls.firstWhere((c) => c.method == 'nudge');
    expect((call.arguments as Map)['deltaMs'], -25);
  });

  test('nudge() is a no-op when stopped', () async {
    final m = Metronome();
    await m.init();
    calls.clear();

    await m.nudge(const Duration(milliseconds: 25));

    expect(calls.where((c) => c.method == 'nudge'), isEmpty);
  });

  test('setSubdivision sends pulsesPerBeat', () async {
    final m = Metronome();
    await m.init();
    calls.clear();

    await m.setSubdivision(Subdivision.triplet);
    expect(m.subdivision, Subdivision.triplet);

    final call = calls.firstWhere((c) => c.method == 'setSubdivision');
    expect((call.arguments as Map)['pulsesPerBeat'], 3);
  });

  test('setTempo validates range', () async {
    final m = Metronome();
    await m.init();
    await expectLater(m.setTempo(19.0), throwsArgumentError);
    await expectLater(m.setTempo(401.0), throwsArgumentError);
    await expectLater(m.setTempo(120.0), completes);
  });

  test('setTimeSignature resets accent pattern to beat-1-only', () async {
    final m = Metronome();
    await m.init();
    calls.clear();
    await m.setTimeSignature(TimeSignature(7, 8));
    final call = calls.firstWhere((c) => c.method == 'setTimeSignature');
    final args = call.arguments as Map;
    expect(args['beatsPerBar'], 7);
    final pattern = (args['accentPattern'] as List).cast<bool>();
    expect(pattern.length, 7);
    expect(pattern[0], true);
    expect(pattern.sublist(1), everyElement(false));
  });

  test('setAccentEnabled(false) sends an all-false pattern', () async {
    final m = Metronome();
    await m.init();
    calls.clear();

    await m.setAccentEnabled(false);

    expect(m.accentEnabled, false);
    final call = calls.firstWhere((c) => c.method == 'setAccentPattern');
    final pattern = ((call.arguments as Map)['accentPattern'] as List)
        .cast<bool>();
    expect(pattern, everyElement(false));
    expect(pattern.length, 4);
  });

  test('setAccentEnabled(true) restores the accent on its previous beat',
      () async {
    final m = Metronome();
    await m.init();
    await m.setAccentBeat(2);
    await m.setAccentEnabled(false);
    calls.clear();

    await m.setAccentEnabled(true);

    expect(m.accentEnabled, true);
    expect(m.accentBeat, 2);
    expect(m.accentPattern, [false, false, true, false]);
  });

  test('setAccentBeat moves the single accent', () async {
    final m = Metronome();
    await m.init();
    calls.clear();

    await m.setAccentBeat(3);

    expect(m.accentBeat, 3);
    final call = calls.firstWhere((c) => c.method == 'setAccentPattern');
    expect(
      ((call.arguments as Map)['accentPattern'] as List).cast<bool>(),
      [false, false, false, true],
    );
  });

  test('setAccentBeat re-enables a disabled accent', () async {
    final m = Metronome();
    await m.init();
    await m.setAccentEnabled(false);

    await m.setAccentBeat(1);

    expect(m.accentEnabled, true);
    expect(m.accentPattern, [false, true, false, false]);
  });

  test('setAccentBeat validates against beatsPerBar', () async {
    final m = Metronome();
    await m.init();
    await m.setTimeSignature(TimeSignature(3, 4));

    expect(() => m.setAccentBeat(-1), throwsArgumentError);
    expect(() => m.setAccentBeat(3), throwsArgumentError);
    await expectLater(m.setAccentBeat(2), completes);
  });

  test('setTimeSignature keeps accent disabled and keeps a valid beat',
      () async {
    final m = Metronome();
    await m.init();
    await m.setAccentEnabled(false);
    await m.setTimeSignature(TimeSignature(3, 4));
    expect(m.accentEnabled, false);
    expect(m.accentPattern, everyElement(false));

    await m.setAccentBeat(2);
    await m.setTimeSignature(TimeSignature(4, 4));
    // Beat 2 still exists in 4/4 — the accent stays there.
    expect(m.accentPattern, [false, false, true, false]);

    await m.setAccentBeat(3);
    await m.setTimeSignature(TimeSignature(3, 4));
    // Beat 3 does not exist in 3/4 — falls back to beat 0.
    expect(m.accentBeat, 0);
    expect(m.accentPattern, [true, false, false]);
  });

  test('setAccentPattern syncs accentEnabled and accentBeat', () async {
    final m = Metronome();
    await m.init();

    await m.setAccentPattern([false, false, false, false]);
    expect(m.accentEnabled, false);

    await m.setAccentPattern([false, true, false, false]);
    expect(m.accentEnabled, true);
    expect(m.accentBeat, 1);

    // Multi-accent pattern: enabled, accentBeat keeps its last value.
    await m.setAccentPattern([true, false, true, false]);
    expect(m.accentEnabled, true);
    expect(m.accentBeat, 1);
  });

  test('the longest per-pulse pattern reaches native intact', () async {
    final m = Metronome();
    await m.init();
    await m.setTimeSignature(TimeSignature(32, 4));
    await m.setSubdivision(Subdivision.quadruple);
    calls.clear();

    // 32 beats x 4 pulses is the most flags the API allows. The native
    // bridges must carry all of them, not just the first 32.
    final pattern = List<bool>.generate(128, (i) => i % 4 == 0);
    await m.setAccentPattern(pattern);

    final call = calls.lastWhere((c) => c.method == 'setAccentPattern');
    expect(
      ((call.arguments as Map)['accentPattern'] as List).cast<bool>(),
      pattern,
    );
  });

  test('setAccentPattern rejects wrong length', () async {
    final m = Metronome();
    await m.init();
    await m.setTimeSignature(TimeSignature(4, 4));
    expect(
      () => m.setAccentPattern([true, false, true]), // 3 instead of 4
      throwsArgumentError,
    );
  });

  test('setVoice sends the wire name for every voice', () async {
    final m = Metronome();
    await m.init();
    expect(
      MetronomeVoice.values.map((v) => v.wireName),
      ['tone', 'click', 'wood', 'mechanical', 'blip'],
    );
    for (final voice in MetronomeVoice.values) {
      calls.clear();
      await m.setVoice(voice);
      expect(m.voice, voice);
      final call = calls.firstWhere((c) => c.method == 'setVoice');
      expect((call.arguments as Map)['voice'], voice.wireName);
    }
  });

  test('a per-beat pattern is sent expanded over the pulse grid', () async {
    final m = Metronome();
    await m.init();
    await m.setTimeSignature(TimeSignature(3, 4));
    await m.setSubdivision(Subdivision.duple);
    calls.clear();

    await m.setAccentPattern([true, false, true]);

    final call = calls.lastWhere((c) => c.method == 'setAccentPattern');
    final sent = ((call.arguments as Map)['accentPattern'] as List).cast<bool>();
    // Beat accents land on each beat's own pulse; the off-beats stay clear.
    expect(sent, [true, false, false, false, true, false]);
    expect(m.accentPattern, [true, false, true]);
    expect(m.pulseAccents, sent);
  });

  test('a per-pulse pattern can accent subdivision pulses', () async {
    final m = Metronome();
    await m.init();
    await m.setTimeSignature(TimeSignature(2, 4));
    await m.setSubdivision(Subdivision.triplet);
    calls.clear();

    // Beat 1, plus the last triplet of beat 2 — a pickup into the downbeat.
    await m.setAccentPattern([true, false, false, false, false, true]);

    final call = calls.lastWhere((c) => c.method == 'setAccentPattern');
    final sent = ((call.arguments as Map)['accentPattern'] as List).cast<bool>();
    expect(sent, [true, false, false, false, false, true]);
    expect(m.pulseAccents, sent);
    // The per-beat view only reports the beats' own pulses.
    expect(m.accentPattern, [true, false]);
  });

  test('setAccentPattern rejects a length that is neither grid', () async {
    final m = Metronome();
    await m.init();
    await m.setTimeSignature(TimeSignature(4, 4));
    await m.setSubdivision(Subdivision.duple);
    // 4 beats x 2 pulses = 8; 5 is neither 4 nor 8.
    expect(
      () => m.setAccentPattern([true, false, true, false, true]),
      throwsArgumentError,
    );
    await expectLater(m.setAccentPattern(List.filled(8, false)), completes);
    await expectLater(m.setAccentPattern(List.filled(4, false)), completes);
  });

  test('changing subdivision keeps beat accents and drops sub accents',
      () async {
    final m = Metronome();
    await m.init();
    await m.setTimeSignature(TimeSignature(2, 4));
    await m.setSubdivision(Subdivision.duple);
    await m.setAccentPattern([true, true, false, false]); // beat 1 + its 'and'
    calls.clear();

    await m.setSubdivision(Subdivision.triplet);

    expect(m.pulseAccents.length, 6);
    // Beat 1 stays accented, the accent on the old off-beat is gone.
    expect(m.pulseAccents, [true, false, false, false, false, false]);
    expect(m.accentPattern, [true, false]);
    final call = calls.lastWhere((c) => c.method == 'setAccentPattern');
    expect(
      ((call.arguments as Map)['accentPattern'] as List).cast<bool>(),
      m.pulseAccents,
    );
  });

  test('setTimeSignature sizes the pattern to the pulse grid', () async {
    final m = Metronome();
    await m.init();
    await m.setSubdivision(Subdivision.quadruple);
    calls.clear();

    await m.setTimeSignature(TimeSignature(3, 4));

    final call = calls.firstWhere((c) => c.method == 'setTimeSignature');
    final sent = ((call.arguments as Map)['accentPattern'] as List).cast<bool>();
    expect(sent.length, 12, reason: '3 beats x 4 pulses');
    expect(sent.first, isTrue);
    expect(sent.sublist(1), everyElement(false));
  });

  test('accent controls work on the pulse grid', () async {
    final m = Metronome();
    await m.init();
    await m.setSubdivision(Subdivision.triplet);
    calls.clear();

    await m.setAccentBeat(2);

    // 4 beats x 3 pulses, the accent on beat 3's own pulse.
    final sent = ((calls.lastWhere((c) => c.method == 'setAccentPattern')
                .arguments
            as Map)['accentPattern'] as List)
        .cast<bool>();
    expect(sent.length, 12);
    expect(sent[6], isTrue);
    expect(sent.where((a) => a).length, 1);

    await m.setAccentEnabled(false);
    expect(m.pulseAccents.length, 12);
    expect(m.pulseAccents, everyElement(false));

    await m.setAccentEnabled(true);
    expect(m.accentBeat, 2);
    expect(m.pulseAccents[6], isTrue);
  });

  test('a lone accent on a subdivision pulse leaves accentBeat alone',
      () async {
    final m = Metronome();
    await m.init();
    await m.setTimeSignature(TimeSignature(2, 4));
    await m.setSubdivision(Subdivision.duple);
    await m.setAccentBeat(1);

    // One accent, but on an off-beat — not a single-accent beat pattern.
    await m.setAccentPattern([false, false, false, true]);
    expect(m.accentEnabled, isTrue);
    expect(m.accentBeat, 1, reason: 'kept from the last main-beat accent');

    // Turning accents off and on again restores the beat, not the off-beat.
    await m.setAccentEnabled(false);
    await m.setAccentEnabled(true);
    expect(m.pulseAccents, [false, false, true, false]);
  });

  test('setVolume validates range', () async {
    final m = Metronome();
    await m.init();
    await expectLater(m.setVolume(-0.1), throwsArgumentError);
    await expectLater(m.setVolume(1.1), throwsArgumentError);
    await expectLater(m.setVolume(0.5), completes);
  });

  test('start / stop toggle isPlaying', () async {
    final m = Metronome();
    await m.init();
    expect(m.isPlaying, false);
    await m.start();
    expect(m.isPlaying, true);
    await m.stop();
    expect(m.isPlaying, false);
  });

  test('methods throw after dispose', () async {
    final m = Metronome();
    await m.init();
    await m.dispose();
    expect(() => m.setTempo(120), throwsStateError);
  });
}
