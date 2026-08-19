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
        barsPerStep: 4,
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
        barsPerStep: 2,
      );
      expect(ramp.steps, [100, 110, 120, 130]);
    });

    test('descending ramp', () {
      final ramp = TempoRamp(
        startBpm: 120,
        goalBpm: 90,
        stepBpm: 20,
        barsPerStep: 1,
      );
      expect(ramp.ascending, isFalse);
      expect(ramp.steps, [120, 100, 90]);
    });

    test('start == goal is a single step', () {
      final ramp = TempoRamp(
        startBpm: 100,
        goalBpm: 100,
        stepBpm: 5,
        barsPerStep: 3,
      );
      expect(ramp.totalSteps, 1);
      expect(ramp.steps, [100]);
    });

    test('open-ended ramp climbs to maxBpm and never finishes', () {
      final ramp = TempoRamp(startBpm: 380, stepBpm: 15, barsPerStep: 2);
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
        barsPerStep: 4,
        holdAtGoal: true,
      );
      expect(ramp.isOpenEnded, isFalse);
      expect(ramp.stopsAtGoal, isFalse);
      expect(ramp.totalSteps, 4);
      expect(ramp.toMap()['stopAtGoal'], isFalse);
      expect(ramp.toMap()['goalBpm'], 120.0);
      expect(ramp.toString(), contains('hold at goal'));

      final plain = TempoRamp(startBpm: 80, goalBpm: 120, stepBpm: 15, barsPerStep: 4);
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
        () => TempoRamp(startBpm: 10, goalBpm: 120, stepBpm: 5, barsPerStep: 1),
        throwsArgumentError,
      );
      expect(
        () => TempoRamp(startBpm: 80, goalBpm: 401, stepBpm: 5, barsPerStep: 1),
        throwsArgumentError,
      );
      expect(
        () => TempoRamp(startBpm: 80, goalBpm: 120, stepBpm: 0, barsPerStep: 1),
        throwsArgumentError,
      );
      expect(
        () => TempoRamp(startBpm: 80, goalBpm: 120, stepBpm: 5, barsPerStep: 0),
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
      barsPerStep: 4,
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
        barsPerStep: 4,
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

      await m.startRamp(TempoRamp(startBpm: 100, stepBpm: 4, barsPerStep: 2));
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
