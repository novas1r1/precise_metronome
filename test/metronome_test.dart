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
