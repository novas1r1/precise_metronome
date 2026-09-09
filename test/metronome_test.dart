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

  test('setAccentPattern rejects wrong length', () async {
    final m = Metronome();
    await m.init();
    await m.setTimeSignature(TimeSignature(4, 4));
    expect(
      () => m.setAccentPattern([true, false, true]), // 3 instead of 4
      throwsArgumentError,
    );
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
