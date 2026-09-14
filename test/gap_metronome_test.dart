import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precise_metronome/precise_metronome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('precise_metronome');
  const beatChannel = EventChannel('precise_metronome/beats');
  const rampChannel = EventChannel('precise_metronome/ramp');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final List<MethodCall> calls = [];
  MockStreamHandlerEventSink? sink;
  var listenCount = 0;
  var cancelCount = 0;
  // How many upcoming setGapPlan calls the engine refuses.
  var refuseGapPlans = 0;

  setUp(() {
    calls.clear();
    sink = null;
    listenCount = 0;
    cancelCount = 0;
    refuseGapPlans = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'setGapPlan' && refuseGapPlans > 0) {
        refuseGapPlans--;
        throw PlatformException(code: 'gap_plan_busy');
      }
      return null;
    });
    messenger.setMockStreamHandler(
      beatChannel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          sink = events;
          listenCount++;
        },
        onCancel: (_) => cancelCount++,
      ),
    );
    messenger.setMockStreamHandler(
      rampChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockStreamHandler(beatChannel, null);
    messenger.setMockStreamHandler(rampChannel, null);
  });

  Future<Metronome> ready() async {
    final m = Metronome();
    await m.init();
    calls.clear();
    return m;
  }

  /// Lets channel messages and the calls they trigger go through.
  Future<void> settle() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void downbeat(
    int bar, {
    required int segment,
    required int index,
    bool landing = false,
  }) {
    sink!.success({
      'bar': bar,
      'beat': 0,
      'pulse': 0,
      'accent': true,
      'muted': false,
      'landing': landing,
      'gapSegment': segment,
      'gapBar': index,
    });
  }

  List<MethodCall> gapCalls() => calls
      .where((c) => c.method == 'setGapPlan' || c.method == 'clearGapPlan')
      .toList();
  Iterable<MethodCall> beatCalls() =>
      calls.where((c) => c.method == 'setBeatEvents');
  Map<Object?, Object?> args(MethodCall call) =>
      call.arguments as Map<Object?, Object?>;

  final twoTwo = GapPattern.fixed(clickBars: 2, silentBars: 2);

  test('start hands the first bars to the engine before it starts', () async {
    final m = await ready();
    await m.setGapPattern(twoTwo);
    expect(m.gapPattern, twoTwo);
    expect(gapCalls(), isEmpty);

    await m.start();
    final methods = calls.map((c) => c.method).toList();
    expect(methods.indexOf('setGapPlan'), lessThan(methods.indexOf('start')));
    // 120 BPM in 4/4 is two seconds a bar: the minimum of 8 bars covers
    // the four seconds.
    expect(args(gapCalls().single), {
      'segment': 1,
      'from': 0,
      'silent': [false, false, true, true, false, false, true, true],
    });
  });

  test('plans four seconds ahead at fast tempos', () async {
    final m = await ready();
    await m.setTempo(400);
    await m.setTimeSignature(TimeSignature(1, 4));
    await m.setGapPattern(twoTwo);
    await m.start();
    // A one-beat bar at 400 BPM lasts 0.15 s, so four seconds take 27.
    expect(args(gapCalls().single)['silent'], hasLength(27));
  });

  test('switches native beat events on while a pattern is set', () async {
    final m = await ready();
    await m.setGapPattern(twoTwo);
    await settle();
    expect(listenCount, 1);
    expect(args(beatCalls().single)['enabled'], isTrue);

    await m.setGapPattern(null);
    await settle();
    expect(cancelCount, 1);
    expect(args(beatCalls().last)['enabled'], isFalse);
  });

  test('a metronome without a pattern makes no gap calls', () async {
    final m = await ready();
    await m.start();
    await m.stop();
    await m.start();
    expect(gapCalls(), isEmpty);
    expect(beatCalls(), isEmpty);
  });

  test('startRamp plays the pattern too', () async {
    final m = await ready();
    await m.setGapPattern(twoTwo);
    await m.startRamp(
      TempoRamp(
        startBpm: 120,
        goalBpm: 140,
        stepBpm: 10,
        stepLength: RampStepLength.bars(4),
      ),
    );
    final methods = calls.map((c) => c.method).toList();
    expect(
      methods.indexOf('setGapPlan'),
      lessThan(methods.indexOf('startRamp')),
    );
  });

  test('tops the bars up as the pattern plays', () async {
    final m = await ready();
    await m.setGapPattern(twoTwo);
    await m.start();
    calls.clear();

    for (var bar = 0; bar < 4; bar++) {
      downbeat(bar, segment: 1, index: bar);
    }
    await settle();
    expect(gapCalls(), isEmpty, reason: 'bars 3 to 7 are still ahead');

    downbeat(4, segment: 1, index: 4, landing: true);
    await settle();
    expect(args(gapCalls().single), {
      'segment': 1,
      'from': 8,
      'silent': [false, false, true, true],
    });
  });

  test('reports muted pulses and landings on beat events', () async {
    final m = await ready();
    final received = <BeatEvent>[];
    m.beats.listen(received.add);
    await settle();

    sink!.success({
      'bar': 3,
      'beat': 1,
      'pulse': 0,
      'accent': false,
      'muted': true,
      'landing': false,
      'gapSegment': 1,
      'gapBar': 3,
    });
    downbeat(4, segment: 1, index: 4, landing: true);
    await settle();

    expect(received, hasLength(2));
    expect(received[0].muted, isTrue);
    expect(received[0].landing, isFalse);
    expect(received[1].muted, isFalse);
    expect(received[1].landing, isTrue);
  });

  test('a new pattern while playing starts a new segment', () async {
    final m = await ready();
    await m.setGapPattern(twoTwo);
    await m.start();
    await m.setGapPattern(GapPattern.fixed(clickBars: 1, silentBars: 1));
    expect(args(gapCalls().last), {
      'segment': 2,
      'from': 0,
      'silent': [false, true, false, true, false, true, false, true],
    });
  });

  test('setting the same pattern again changes nothing', () async {
    final m = await ready();
    await m.setGapPattern(twoTwo);
    await m.start();
    calls.clear();
    await m.setGapPattern(GapPattern.fixed(clickBars: 2, silentBars: 2));
    expect(calls, isEmpty);
  });

  test('turning the pattern off while playing clears it natively', () async {
    final m = await ready();
    await m.setGapPattern(twoTwo);
    await m.start();
    await m.setGapPattern(null);
    expect(m.gapPattern, isNull);
    expect(gapCalls().last.method, 'clearGapPlan');
    expect(args(gapCalls().last), {'segment': 2});
  });

  test('every start plays the pattern from its beginning', () async {
    final m = await ready();
    await m.setGapPattern(twoTwo);
    await m.start();
    await m.stop();
    await m.start();
    expect(gapCalls().map((c) => args(c)['segment']), [1, 2]);
    expect(gapCalls().map((c) => args(c)['from']), [0, 0]);
  });

  test(
    'start clears a segment left from before the pattern was turned off',
    () async {
      final m = await ready();
      await m.setGapPattern(twoTwo);
      await m.start();
      await m.stop();
      await m.setGapPattern(null);
      calls.clear();

      await m.start();
      expect(
        calls.map((c) => c.method),
        containsAllInOrder(['clearGapPlan', 'start']),
      );
      expect(args(gapCalls().single), {'segment': 2});
    },
  );

  test('starts over when the engine ran out of bars', () async {
    final m = await ready();
    await m.setGapPattern(twoTwo);
    await m.start();
    downbeat(0, segment: 1, index: 0);
    await settle();
    calls.clear();

    downbeat(9, segment: 1, index: -1);
    await settle();
    expect(args(gapCalls().single)['segment'], 2);
    expect(args(gapCalls().single)['from'], 0);
  });

  test(
    'starts over when the engine dropped a segment it had started',
    () async {
      final m = await ready();
      await m.setGapPattern(twoTwo);
      await m.start();
      downbeat(0, segment: 1, index: 0);
      await settle();
      calls.clear();

      downbeat(1, segment: 0, index: -1);
      await settle();
      expect(args(gapCalls().single)['segment'], 2);
    },
  );

  test('waits while the engine has not started a new segment yet', () async {
    final m = await ready();
    await m.setGapPattern(twoTwo);
    await m.start();
    downbeat(0, segment: 1, index: 0);
    await settle();
    await m.setGapPattern(GapPattern.fixed(clickBars: 1, silentBars: 1));
    calls.clear();

    downbeat(1, segment: 1, index: 1);
    await settle();
    expect(gapCalls(), isEmpty);
  });

  test('sends a segment again when the engine could not take it', () async {
    final m = await ready();
    refuseGapPlans = 1;
    await m.setGapPattern(twoTwo);
    await m.start();
    expect(m.isPlaying, isTrue);

    downbeat(0, segment: 0, index: -1);
    await settle();
    final sent = gapCalls().map(args).toList();
    expect(sent, hasLength(2));
    expect(sent.last['segment'], 2);
    expect(sent.last['from'], 0);
  });

  test('gapBarAt follows the session once the pattern took effect', () async {
    final m = await ready();
    await m.setGapPattern(GapPattern.fixed(clickBars: 1, silentBars: 1));
    expect(m.gapBarAt(0), isNull);

    await m.start();
    expect(m.gapBarAt(5), isNull, reason: 'the engine has not started it');

    downbeat(5, segment: 1, index: 0, landing: true);
    await settle();
    expect(m.gapBarAt(4), isNull);
    expect(m.gapBarAt(5), const GapBar(index: 5, silent: false, landing: true));
    expect(m.gapBarAt(6), const GapBar(index: 6, silent: true, landing: false));
    expect(m.gapBarAt(7), const GapBar(index: 7, silent: false, landing: true));

    await m.stop();
    expect(m.gapBarAt(6), isNull);
  });
}
