import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precise_metronome/precise_metronome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('precise_metronome');
  const beatChannel = EventChannel('precise_metronome/beats');
  final List<MethodCall> calls = [];
  MockStreamHandlerEventSink? sink;
  var listenCount = 0;
  var cancelCount = 0;

  setUp(() {
    calls.clear();
    sink = null;
    listenCount = 0;
    cancelCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      beatChannel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          sink = events;
          listenCount++;
        },
        onCancel: (_) => cancelCount++,
      ),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(beatChannel, null);
  });

  Iterable<MethodCall> beatCalls() =>
      calls.where((c) => c.method == 'setBeatEvents');

  test('listening enables native beat events, cancelling disables them',
      () async {
    final m = Metronome();
    await m.init();
    calls.clear();
    expect(beatCalls(), isEmpty);

    final sub = m.beats.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(listenCount, 1);
    final enable = beatCalls().single.arguments as Map;
    expect(enable['enabled'], isTrue);
    expect(enable['includeSubdivisions'], isFalse);

    await sub.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(cancelCount, 1);
    final disable = beatCalls().last.arguments as Map;
    expect(disable['enabled'], isFalse);
  });

  test('forwards native events as BeatEvent', () async {
    final m = Metronome();
    await m.init();
    final received = <BeatEvent>[];
    m.beats.listen(received.add);
    await Future<void>.delayed(Duration.zero);

    sink!.success({'bar': 2, 'beat': 0, 'pulse': 0, 'accent': true});
    sink!.success({'bar': 2, 'beat': 1, 'pulse': 1, 'accent': false});
    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(2));
    expect(received[0].barIndex, 2);
    expect(received[0].isDownbeat, isTrue);
    expect(received[0].accent, isTrue);
    expect(received[1].beatIndex, 1);
    expect(received[1].pulseIndex, 1);
    expect(received[1].isMainBeat, isFalse);
  });

  test('setBeatEventOptions re-pushes while listening', () async {
    final m = Metronome();
    await m.init();
    m.beats.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    calls.clear();

    await m.setBeatEventOptions(includeSubdivisions: true);
    expect(m.includeSubdivisionsInBeats, isTrue);
    final args = beatCalls().single.arguments as Map;
    expect(args['enabled'], isTrue);
    expect(args['includeSubdivisions'], isTrue);
  });

  test('a listener attached before init() is enabled by init()', () async {
    final m = Metronome();
    m.beats.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(beatCalls(), isEmpty);

    await m.init();
    expect(beatCalls(), hasLength(1));
    expect(listenCount, 1);
  });
}
