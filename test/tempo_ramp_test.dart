import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precise_metronome/precise_metronome.dart';

void main() {
  group('TempoRamp', () {
    test('computes steps, clamping the last one to the goal', () {
      final ramp = TempoRamp(
        startBpm: 80,
        goalBpm: 120,
        stepBpm: 15,
        stepLength: RampStepLength.bars(4),
      );
      expect(ramp.totalSteps, 4);
      expect(ramp.steps, [80, 95, 110, 120]);
      expect(ramp.ascending, isTrue);
    });

    test('exact multiple ends on the goal without an extra step', () {
      final ramp = TempoRamp(
        startBpm: 100,
        goalBpm: 130,
        stepBpm: 10,
        stepLength: RampStepLength.bars(2),
      );
      expect(ramp.steps, [100, 110, 120, 130]);
    });

    test('descending ramp', () {
      final ramp = TempoRamp(
        startBpm: 120,
        goalBpm: 90,
        stepBpm: 20,
        stepLength: RampStepLength.bars(1),
      );
      expect(ramp.ascending, isFalse);
      expect(ramp.steps, [120, 100, 90]);
    });

    test('returnToStart walks back down to the start tempo', () {
      final ramp = TempoRamp(
        startBpm: 60,
        goalBpm: 70,
        stepBpm: 5,
        stepLength: RampStepLength.bars(4),
        returnToStart: true,
      );
      expect(ramp.totalSteps, 5);
      expect(ramp.steps, [60, 65, 70, 65, 60]);
      expect(ramp.ascending, isTrue);
    });

    test('returnToStart mirrors a clamped last step by distance', () {
      // Up: 80, 95, 110, 120 (last step shortened). Down covers the same
      // 40 BPM in the same three moves, clamping at the start instead.
      final ramp = TempoRamp(
        startBpm: 80,
        goalBpm: 120,
        stepBpm: 15,
        stepLength: RampStepLength.bars(4),
        returnToStart: true,
      );
      expect(ramp.totalSteps, 7);
      expect(ramp.steps, [80, 95, 110, 120, 105, 90, 80]);
    });

    test('returnToStart on a descending ramp climbs back up', () {
      final ramp = TempoRamp(
        startBpm: 120,
        goalBpm: 90,
        stepBpm: 20,
        stepLength: RampStepLength.bars(1),
        returnToStart: true,
      );
      expect(ramp.steps, [120, 100, 90, 110, 120]);
    });

    test('bpmAt clamps past the end of the return leg', () {
      final ramp = TempoRamp(
        startBpm: 60,
        goalBpm: 70,
        stepBpm: 5,
        stepLength: RampStepLength.bars(4),
        returnToStart: true,
      );
      expect(ramp.bpmAt(4), 60.0);
      expect(ramp.bpmAt(9), 60.0);
    });

    test('returnToStart with start == goal stays a single step', () {
      final ramp = TempoRamp(
        startBpm: 100,
        goalBpm: 100,
        stepBpm: 5,
        stepLength: RampStepLength.bars(3),
        returnToStart: true,
      );
      expect(ramp.totalSteps, 1);
      expect(ramp.steps, [100]);
    });

    test('returnToStart needs a goal to return from', () {
      expect(
        () => TempoRamp(
          startBpm: 90,
          stepBpm: 4,
          stepLength: RampStepLength.bars(8),
          returnToStart: true,
        ),
        throwsArgumentError,
      );
    });

    test('start == goal is a single step', () {
      final ramp = TempoRamp(
        startBpm: 100,
        goalBpm: 100,
        stepBpm: 5,
        stepLength: RampStepLength.bars(3),
      );
      expect(ramp.totalSteps, 1);
      expect(ramp.steps, [100]);
    });

    test('open-ended ramp climbs to maxBpm and never finishes', () {
      final ramp = TempoRamp(startBpm: 380, stepBpm: 15, stepLength: RampStepLength.bars(2));
      expect(ramp.isOpenEnded, isTrue);
      expect(ramp.goalBpm, isNull);
      expect(ramp.steps, [380, 395, 400]);
      expect(ramp.bpmAt(10), 400); // holds the limit
      expect(ramp.toMap()['stopAtGoal'], isFalse);
      expect(ramp.toMap()['goalBpm'], 400.0);
    });

    test('holdAtGoal keeps the metronome running at the goal', () {
      final ramp = TempoRamp(
        startBpm: 80,
        goalBpm: 120,
        stepBpm: 15,
        stepLength: RampStepLength.bars(4),
        holdAtGoal: true,
      );
      expect(ramp.isOpenEnded, isFalse);
      expect(ramp.stopsAtGoal, isFalse);
      expect(ramp.totalSteps, 4);
      expect(ramp.toMap()['stopAtGoal'], isFalse);
      expect(ramp.toMap()['goalBpm'], 120.0);
      expect(ramp.toString(), contains('hold at goal'));

      final plain = TempoRamp(startBpm: 80, goalBpm: 120, stepBpm: 15, stepLength: RampStepLength.bars(4));
      expect(plain.stopsAtGoal, isTrue);
      expect(plain.toMap()['stopAtGoal'], isTrue);
    });

    test('RampProgress.isLastStep marks the goal step', () {
      const mid = RampProgress(stepIndex: 1, totalSteps: 4, bpm: 95, finished: false);
      const goal = RampProgress(stepIndex: 3, totalSteps: 4, bpm: 120, finished: false);
      const open = RampProgress(stepIndex: 3, totalSteps: null, bpm: 120, finished: false);
      expect(mid.isLastStep, isFalse);
      expect(goal.isLastStep, isTrue);
      expect(open.isLastStep, isFalse);
    });

    test('validates arguments', () {
      expect(
        () => TempoRamp(startBpm: 10, goalBpm: 120, stepBpm: 5, stepLength: RampStepLength.bars(1)),
        throwsArgumentError,
      );
      expect(
        () => TempoRamp(startBpm: 80, goalBpm: 401, stepBpm: 5, stepLength: RampStepLength.bars(1)),
        throwsArgumentError,
      );
      expect(
        () => TempoRamp(startBpm: 80, goalBpm: 120, stepBpm: 0, stepLength: RampStepLength.bars(1)),
        throwsArgumentError,
      );
      expect(
        () => TempoRamp(startBpm: 80, goalBpm: 120, stepBpm: 5, stepLength: RampStepLength.bars(0)),
        throwsArgumentError,
      );
    });
  });

  group('RampStepLength', () {
    test('bars: fixed count, sent as barsPerStep', () {
      final ramp = TempoRamp(
        startBpm: 80,
        goalBpm: 120,
        stepBpm: 15,
        stepLength: RampStepLength.bars(4),
      );
      expect(ramp.stepLength, RampStepLength.bars(4));
      expect(ramp.barsAt(0, beatsPerBar: 4), 4);
      expect(ramp.barsAt(3, beatsPerBar: 7), 4);
      expect(ramp.totalBars(beatsPerBar: 4), 16);
      expect(ramp.toMap()['barsPerStep'], 4);
      expect(ramp.toMap()['stepMs'], 0);
      expect(ramp.toString(), contains('4 bars/step'));
    });

    test('time: rounds each step up to the bar line at its tempo', () {
      // 30 s at 100 BPM in 4/4: a bar is 2.4 s, so 12.5 → 13 bars. At 105
      // and 110 BPM the bars are shorter and it takes 14.
      final ramp = TempoRamp(
        startBpm: 100,
        goalBpm: 110,
        stepBpm: 5,
        stepLength: RampStepLength.time(const Duration(seconds: 30)),
      );
      expect(ramp.stepLength, RampStepLength.time(const Duration(seconds: 30)));
      expect(ramp.barsAt(0, beatsPerBar: 4), 13);
      expect(ramp.barsAt(1, beatsPerBar: 4), 14);
      expect(ramp.barsAt(2, beatsPerBar: 4), 14);
      expect(ramp.totalBars(beatsPerBar: 4), 41);
      // 13 × 2.4 s + 14 × 2.2857 s + 14 × 2.1818 s ≈ 93.7 s.
      expect(ramp.totalDuration(beatsPerBar: 4)!.inMilliseconds, 93745);
      expect(ramp.toMap()['barsPerStep'], 0);
      expect(ramp.toMap()['stepMs'], 30000);
      expect(ramp.toString(), contains('30s/step'));
    });

    test('time: an exact multiple of the bar needs no extra bar', () {
      final step = RampStepLength.time(const Duration(seconds: 30));
      // 120 BPM in 4/4: a bar is exactly 2 s.
      expect(step.barsAt(bpm: 120, beatsPerBar: 4), 15);
      expect(
        step.durationAt(bpm: 120, beatsPerBar: 4),
        const Duration(seconds: 30),
      );
    });

    test('time: a step shorter than a bar still plays a whole bar', () {
      final step = RampStepLength.time(const Duration(milliseconds: 500));
      expect(step.barsAt(bpm: 60, beatsPerBar: 4), 1);
      expect(
        step.durationAt(bpm: 60, beatsPerBar: 4),
        const Duration(seconds: 4),
      );
    });

    test('time works with returnToStart and open-ended ramps', () {
      final roundTrip = TempoRamp(
        startBpm: 60,
        goalBpm: 70,
        stepBpm: 5,
        stepLength: RampStepLength.time(const Duration(seconds: 10)),
        returnToStart: true,
      );
      // 10 s at 60/65/70 BPM in 4/4 (4 s, 3.69 s, 3.43 s per bar): 3 bars
      // each, both legs.
      expect(roundTrip.steps, [60, 65, 70, 65, 60]);
      expect(roundTrip.totalBars(beatsPerBar: 4), 15);

      final open = TempoRamp(
        startBpm: 90,
        stepBpm: 4,
        stepLength: RampStepLength.time(const Duration(minutes: 1)),
      );
      expect(open.isOpenEnded, isTrue);
      expect(open.totalBars(beatsPerBar: 4), isNull);
      expect(open.totalDuration(beatsPerBar: 4), isNull);
      expect(open.barsAt(0, beatsPerBar: 4), 23); // 60 s / 2.667 s
    });

    test('validates arguments', () {
      expect(() => RampStepLength.bars(0), throwsArgumentError);
      expect(
        () => RampStepLength.time(Duration.zero),
        throwsArgumentError,
      );
      expect(
        () => RampStepLength.time(const Duration(seconds: -1)),
        throwsArgumentError,
      );
      expect(
        () => RampStepLength.bars(4).barsAt(bpm: 120, beatsPerBar: 0),
        returnsNormally,
      );
      expect(
        () => RampStepLength.time(
          const Duration(seconds: 1),
        ).barsAt(bpm: 120, beatsPerBar: 0),
        throwsArgumentError,
      );
    });
  });

  group('Metronome.startRamp', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('precise_metronome');
    const rampChannel = EventChannel('precise_metronome/ramp');
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
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(rampChannel, null);
    });

    final ramp = TempoRamp(
      startBpm: 80,
      goalBpm: 120,
      stepBpm: 15,
      stepLength: RampStepLength.bars(4),
    );

    test('sends ramp parameters and emits the initial progress', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            rampChannel,
            MockStreamHandler.inline(onListen: (_, _) {}),
          );
      final m = Metronome();
      await m.init();
      calls.clear();

      final progress = <RampProgress>[];
      m.rampProgress.listen(progress.add);

      await m.startRamp(ramp, initialDelay: const Duration(milliseconds: 100));

      final call = calls.firstWhere((c) => c.method == 'startRamp');
      final args = call.arguments as Map;
      expect(args['initialDelayMs'], 100);
      expect(args['startBpm'], 80.0);
      expect(args['goalBpm'], 120.0);
      expect(args['stopAtGoal'], isTrue);
      expect(args['stepBpm'], 15.0);
      expect(args['barsPerStep'], 4);

      expect(m.isPlaying, isTrue);
      expect(m.activeRamp, ramp);
      expect(m.tempo, 80.0);

      await Future<void>.delayed(Duration.zero);
      expect(progress, hasLength(1));
      expect(progress.single.stepIndex, 0);
      expect(progress.single.totalSteps, 4);
      expect(progress.single.bpm, 80.0);
      expect(progress.single.finished, isFalse);
    });

    test('forwards native step and finish events', () async {
      late MockStreamHandlerEventSink sink;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            rampChannel,
            MockStreamHandler.inline(onListen: (_, events) => sink = events),
          );
      final m = Metronome();
      await m.init();

      final progress = <RampProgress>[];
      m.rampProgress.listen(progress.add);
      await m.startRamp(ramp);
      await Future<void>.delayed(Duration.zero);

      sink.success({'stepIndex': 1, 'bpm': 95.0, 'finished': false});
      await Future<void>.delayed(Duration.zero);
      expect(m.tempo, 95.0);
      expect(m.isPlaying, isTrue);

      sink.success({'stepIndex': 3, 'bpm': 120.0, 'finished': true});
      await Future<void>.delayed(Duration.zero);
      expect(m.tempo, 120.0);
      expect(m.isPlaying, isFalse);
      expect(m.activeRamp, isNull);

      expect(progress.map((p) => p.stepIndex), [0, 1, 3]);
      expect(progress.last.finished, isTrue);
      expect(progress.last.totalSteps, 4);
    });

    test('returnToStart is sent and progress counts through both legs',
        () async {
      late MockStreamHandlerEventSink sink;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            rampChannel,
            MockStreamHandler.inline(onListen: (_, events) => sink = events),
          );
      final m = Metronome();
      await m.init();
      calls.clear();

      final roundTrip = TempoRamp(
        startBpm: 60,
        goalBpm: 70,
        stepBpm: 5,
        stepLength: RampStepLength.bars(4),
        returnToStart: true,
      );
      final progress = <RampProgress>[];
      m.rampProgress.listen(progress.add);
      await m.startRamp(roundTrip);
      await Future<void>.delayed(Duration.zero);

      final args =
          calls.firstWhere((c) => c.method == 'startRamp').arguments as Map;
      expect(args['returnToStart'], isTrue);
      expect(args['goalBpm'], 70.0);
      expect(progress.first.totalSteps, 5);

      // The native side keeps one step counter across the turnaround, so
      // the descent continues where the ascent left off.
      for (final step in [
        [1, 65.0],
        [2, 70.0],
        [3, 65.0],
      ]) {
        sink.success({
          'stepIndex': step[0],
          'bpm': step[1],
          'finished': false,
        });
        await Future<void>.delayed(Duration.zero);
      }
      expect(m.tempo, 65.0);
      expect(m.isPlaying, isTrue);
      expect(progress.last.isLastStep, isFalse);

      sink.success({'stepIndex': 4, 'bpm': 60.0, 'finished': true});
      await Future<void>.delayed(Duration.zero);
      expect(m.tempo, 60.0);
      expect(m.isPlaying, isFalse);
      expect(progress.map((p) => p.bpm), [60.0, 65.0, 70.0, 65.0, 60.0]);
      expect(progress.last.isLastStep, isTrue);
      expect(progress.last.finished, isTrue);
    });

    test('holdAtGoal ramp reaches the goal step and keeps playing', () async {
      late MockStreamHandlerEventSink sink;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            rampChannel,
            MockStreamHandler.inline(onListen: (_, events) => sink = events),
          );
      final m = Metronome();
      await m.init();

      final hold = TempoRamp(
        startBpm: 80,
        goalBpm: 120,
        stepBpm: 15,
        stepLength: RampStepLength.bars(4),
        holdAtGoal: true,
      );
      final progress = <RampProgress>[];
      m.rampProgress.listen(progress.add);
      await m.startRamp(hold);
      await Future<void>.delayed(Duration.zero);

      final call = calls.firstWhere((c) => c.method == 'startRamp');
      expect((call.arguments as Map)['stopAtGoal'], isFalse);

      // The native side reports the goal step like any other step and never
      // sends `finished`.
      sink.success({'stepIndex': 3, 'bpm': 120.0, 'finished': false});
      await Future<void>.delayed(Duration.zero);
      expect(m.tempo, 120.0);
      expect(m.isPlaying, isTrue);
      expect(m.activeRamp, hold);
      expect(progress.last.isLastStep, isTrue);
      expect(progress.last.finished, isFalse);
    });

    test('open-ended ramp reports null totalSteps', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            rampChannel,
            MockStreamHandler.inline(onListen: (_, _) {}),
          );
      final m = Metronome();
      await m.init();
      calls.clear();
      final progress = <RampProgress>[];
      m.rampProgress.listen(progress.add);

      await m.startRamp(TempoRamp(startBpm: 100, stepBpm: 4, stepLength: RampStepLength.bars(2)));
      await Future<void>.delayed(Duration.zero);

      final args =
          calls.firstWhere((c) => c.method == 'startRamp').arguments as Map;
      expect(args['stopAtGoal'], isFalse);
      expect(args['goalBpm'], 400.0);
      expect(progress.single.totalSteps, isNull);
    });

    test('stop() clears the active ramp', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            rampChannel,
            MockStreamHandler.inline(onListen: (_, _) {}),
          );
      final m = Metronome();
      await m.init();
      await m.startRamp(ramp);
      await m.stop();
      expect(m.isPlaying, isFalse);
      expect(m.activeRamp, isNull);
    });
  });
}
