// The gap trainer's state: the pattern it describes, what the strip and the
// status show, and how a gap holds back the beat indicator.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precise_metronome/precise_metronome.dart';
import 'package:precise_metronome_example/accel_metronome.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const method = MethodChannel('precise_metronome');
  const beatChannel = EventChannel('precise_metronome/beats');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final List<MethodCall> calls = [];
  MockStreamHandlerEventSink? beats;

  setUp(() {
    calls.clear();
    beats = null;
    // A fresh store for every test: nothing carried over, nothing written
    // to the device.
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      beatChannel,
      MockStreamHandler.inline(onListen: (_, sink) => beats = sink),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(beatChannel, null);
  });

  Future<void> settle() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<AccelMetronome> ready({bool gap = false}) async {
    final m = AccelMetronome();
    await m.init();
    await settle();
    if (gap) await m.setGapEnabled(true);
    calls.clear();
    return m;
  }

  /// The downbeat of [bar], as the engine reports it once a pattern runs.
  Future<void> downbeat(
    int bar, {
    bool muted = false,
    bool landing = false,
  }) async {
    beats!.success({
      'bar': bar,
      'beat': 0,
      'pulse': 0,
      'accent': true,
      'muted': muted,
      'landing': landing,
      'gapSegment': 1,
      'gapBar': bar,
    });
    await settle();
  }

  /// The strip as silent flags: `null` is a bar the trainer keeps to itself.
  List<bool?> strip(AccelMetronome m) =>
      m.gapStrip.map((cell) => cell.silent).toList();

  test('is off until asked, then describes the pattern it plays', () async {
    final m = await ready();
    expect(m.gapEnabled, isFalse);
    expect(m.gapPattern, isNull);
    expect(m.gapStrip, isEmpty);

    await m.setGapEnabled(true);
    expect(m.gapPattern, GapPattern.fixed(clickBars: 2, silentBars: 2));

    await m.setGapMode(GapMode.random);
    expect(
      m.gapPattern,
      GapPattern.random(silentProbability: 0.3, maxConsecutiveSilent: 2),
    );

    await m.setGapMode(GapMode.ladder);
    expect(
      m.gapPattern,
      GapPattern.ladder(
        clickBars: 2,
        startSilentBars: 1,
        maxSilentBars: 8,
        cyclesPerStep: 2,
      ),
    );
  });

  test('the two trainers take turns', () async {
    final m = await ready();
    expect(m.dynamicMode, isTrue);

    await m.setGapEnabled(true);
    expect(m.dynamicMode, isFalse);

    await m.setDynamicMode(true);
    expect(m.gapEnabled, isFalse);
    expect(m.gapPattern, isNull);
  });

  test('keeps every mode’s settings while switching between them', () async {
    final m = await ready(gap: true);
    await m.setGapSilentBars(5);
    await m.setGapMode(GapMode.ladder);
    await m.setGapStartSilentBars(3);
    await m.setGapMode(GapMode.fixed);

    expect(m.gapSilentBars, 5);
    expect(m.gapStartSilentBars, 3);
  });

  test('a ladder cannot top out below where it starts', () async {
    final m = await ready(gap: true);
    await m.setGapMode(GapMode.ladder);
    await m.setGapMaxSilentBars(2);
    await m.setGapStartSilentBars(6);
    expect(m.gapMaxSilentBars, 6);
  });

  test('the chance of silence snaps to the steps the slider offers', () async {
    final m = await ready(gap: true);
    await m.setGapMode(GapMode.random);
    await m.setGapSilentChance(0.43);
    expect(m.gapSilentChance, closeTo(0.45, 1e-9));
    await m.setGapSilentChance(0.95);
    expect(m.gapSilentChance, GapSettings.maxChance);
  });

  test('the strip previews the pattern while stopped', () async {
    final m = await ready(gap: true);
    expect(strip(m), [false, false, true, true, false, false, true]);

    await m.setGapMode(GapMode.ladder);
    // Two bars of click, one silent, and the gap grows every two cycles.
    expect(strip(m), [false, false, true, false, false, true, false]);
  });

  test('a random pattern keeps the coming bars to itself', () async {
    final m = await ready(gap: true);
    await m.setGapMode(GapMode.random);
    expect(strip(m).skip(1), everyElement(isNull));
    expect(strip(m).first, isFalse, reason: 'a pattern opens with a click');
  });

  test('the status follows the beats through a gap', () async {
    final m = await ready(gap: true);
    expect(m.gapPhase, isNull, reason: 'nothing is playing');

    await m.start();
    await downbeat(0);
    expect(m.gapPhase, GapPhase.click);

    await downbeat(2, muted: true);
    expect(m.gapPhase, GapPhase.silent);

    await downbeat(4, landing: true);
    expect(m.gapPhase, GapPhase.landing);

    await m.stop();
    expect(m.gapPhase, isNull);
  });

  test('a gap holds back the beat indicator, if asked to', () async {
    final m = await ready(gap: true);
    await m.start();
    await downbeat(0);
    expect(m.indicatorBeat, 0);
    expect(m.currentSlot, 0);

    await downbeat(2, muted: true);
    expect(m.indicatorBeat, isNull);
    expect(m.currentSlot, isNull);

    await m.setHideBeatWhenSilent(false);
    expect(m.indicatorBeat, 0, reason: 'the bar position still shows');
  });

  test('the dial never rings on a silenced beat', () async {
    final m = await ready(gap: true);
    await m.start();
    await downbeat(0);
    final ticks = m.beatTick;

    await downbeat(2, muted: true);
    expect(m.beatTick, ticks, reason: 'a gap stays quiet, in every sense');

    await downbeat(4);
    expect(m.beatTick, ticks + 1);
  });

  test('counts the silent bars left when asked to', () async {
    final m = await ready(gap: true);
    await m.start();
    await downbeat(0);
    await downbeat(2, muted: true);
    expect(m.silentBarsLeft, isNull, reason: 'the option is off by default');

    await m.setShowRemainingSilentBars(true);
    expect(m.silentBarsLeft, 2);

    await downbeat(3, muted: true);
    expect(m.silentBarsLeft, 1);

    await downbeat(4);
    expect(m.silentBarsLeft, isNull, reason: 'the click is back');

    await m.setGapMode(GapMode.random);
    await downbeat(6, muted: true);
    expect(m.silentBarsLeft, isNull, reason: 'a random gap has no count');
  });

  test('the ladder shows the gap it is on', () async {
    final m = await ready(gap: true);
    expect(m.gapLadderBars, isNull);

    await m.setGapMode(GapMode.ladder);
    expect(m.gapLadderBars, 1);

    await m.setGapStartSilentBars(3);
    expect(m.gapLadderBars, 3);
  });

  test('hands the pattern to the engine when the metronome starts', () async {
    final m = await ready(gap: true);
    await m.start();

    final methods = calls.map((c) => c.method).toList();
    expect(methods.indexOf('setGapPlan'), lessThan(methods.indexOf('start')));
    expect(methods, isNot(contains('startRamp')));
    final plan = calls.firstWhere((c) => c.method == 'setGapPlan');
    expect((plan.arguments as Map)['silent'], [
      false,
      false,
      true,
      true,
      false,
      false,
      true,
      true,
    ]);
  });
}
