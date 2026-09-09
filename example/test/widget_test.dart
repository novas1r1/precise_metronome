// Smoke tests — the Accel screen renders, starts a ramp with the settings
// shown on screen, and follows the native ramp/beat events.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precise_metronome_example/main.dart';
import 'package:precise_metronome_example/widgets/accel_controls.dart';

/// Stand-in for the native engine.
class _FakeEngine {
  final List<MethodCall> calls = [];
  MockStreamHandlerEventSink? ramp;
  MockStreamHandlerEventSink? beats;

  static const _method = MethodChannel('precise_metronome');
  static const _rampChannel = EventChannel('precise_metronome/ramp');
  static const _beatChannel = EventChannel('precise_metronome/beats');

  /// Must be called from inside the `testWidgets` body: a MockStreamHandler
  /// installed in `setUp` delivers its events in the enclosing zone, which
  /// `pumpAndSettle` never flushes, so the events would silently go missing.
  ///
  /// Also gives the test a phone-shaped viewport. The default 800x600 is
  /// wider and much shorter than any phone, so the screen scrolls and the
  /// ListView unmounts rows the tests need.
  void install(WidgetTester tester) {
    tester.view.physicalSize = const Size(780, 2600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_method, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      _rampChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          ramp = sink;
        },
      ),
    );
    messenger.setMockStreamHandler(
      _beatChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          beats = sink;
        },
      ),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(_method, null);
      messenger.setMockStreamHandler(_rampChannel, null);
      messenger.setMockStreamHandler(_beatChannel, null);
    });
  }

  Iterable<String> get methods => calls.map((c) => c.method);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the dial at the start tempo', (tester) async {
    _FakeEngine().install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    expect(find.text('Accel'), findsOneWidget);
    expect(find.text('BPM'), findsWidgets);
    expect(find.text('60'), findsWidgets);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Dynamic mode'), findsOneWidget);
  });

  testWidgets('shows the ramp plan for the current settings', (tester) async {
    _FakeEngine().install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    // Defaults: 60 → 120 in steps of 5, ramping back down again. The plan
    // comes straight from TempoRamp.steps, elided around the turnaround.
    expect(
      find.text('60 → 65 → … → 120 → … → 60  ·  25 steps  ·  100 bars'),
      findsOneWidget,
    );
  });

  testWidgets('Start sends a returnToStart ramp and follows it', (
    tester,
  ) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    engine.calls.clear();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    final args =
        engine.calls.firstWhere((c) => c.method == 'startRamp').arguments
            as Map;
    expect(args['startBpm'], 60.0);
    expect(args['goalBpm'], 120.0);
    expect(args['stepBpm'], 5.0);
    expect(args['barsPerStep'], 4);
    expect(args['returnToStart'], isTrue);
    expect(find.text('Stop'), findsOneWidget);

    // A tempo step from the native ramp moves the dial.
    engine.ramp!.success({'stepIndex': 1, 'bpm': 65.0, 'finished': false});
    await tester.pumpAndSettle();
    expect(find.text('65'), findsWidgets);

    // A beat event drives the bar counter.
    engine.beats!.success({'bar': 0, 'beat': 2, 'pulse': 0, 'accent': false});
    await tester.pumpAndSettle();
    expect(find.text('bar 1 / 4'), findsOneWidget);
  });

  testWidgets('a running ramp does not rewrite the start tempo setting', (
    tester,
  ) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    engine.ramp!.success({'stepIndex': 4, 'bpm': 80.0, 'finished': false});
    await tester.pumpAndSettle();

    // The dial follows the ramp...
    expect(find.text('80'), findsOneWidget);
    // ...but the stepper and the plan still describe the ramp the user set.
    expect(find.text('60'), findsOneWidget);
    expect(find.textContaining('60 → 65 → … → 120'), findsOneWidget);
  });

  testWidgets('the return leg is marked and the ramp ends itself', (
    tester,
  ) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    // 60 → 120 in steps of 5 is 13 steps up; step 13 starts the way back.
    engine.ramp!.success({'stepIndex': 12, 'bpm': 120.0, 'finished': false});
    await tester.pumpAndSettle();
    engine.ramp!.success({'stepIndex': 13, 'bpm': 115.0, 'finished': false});
    await tester.pumpAndSettle();
    expect(find.text('115'), findsWidgets);
    expect(find.textContaining('−5 →'), findsOneWidget);

    engine.ramp!.success({'stepIndex': 24, 'bpm': 60.0, 'finished': true});
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget, reason: 'it stopped itself');
    expect(find.text('Back at 60 BPM'), findsOneWidget);
  });

  testWidgets('the accent grid follows the time signature', (tester) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('accent-slot-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('accent-slot-4')), findsNothing);

    await _pickSignature(tester, '7/8');

    expect(find.byKey(const ValueKey('accent-slot-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('accent-slot-7')), findsNothing);

    final pattern = _lastAccentPattern(engine);
    expect(pattern.length, 7);
    expect(pattern.first, isTrue);
    expect(pattern.sublist(1), everyElement(false));
  });

  testWidgets('the accent grid follows the subdivision', (tester) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    // Triplets: 4 beats x 3 pulses = 12 cells.
    await _pickSubdivision(tester, '♪³');

    expect(find.byKey(const ValueKey('accent-slot-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('accent-slot-12')), findsNothing);
    expect(_lastAccentPattern(engine).length, 12);
  });

  testWidgets('a subdivision pulse can be accented', (tester) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    await _pickSubdivision(tester, '♪♪');
    engine.calls.clear();

    // Slot 3 is the off-beat of beat 2 — the "and" of two.
    final cell = find.byKey(const ValueKey('accent-slot-3'));
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();

    final pattern = _lastAccentPattern(engine);
    expect(pattern, [true, false, false, true, false, false, false, false]);
  });

  testWidgets('changing subdivision keeps beat accents, drops sub accents', (
    tester,
  ) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    await _pickSubdivision(tester, '♪♪');
    final offBeat = find.byKey(const ValueKey('accent-slot-3'));
    await tester.ensureVisible(offBeat);
    await tester.pumpAndSettle();
    await tester.tap(offBeat);
    await tester.pumpAndSettle();
    expect(_lastAccentPattern(engine)[3], isTrue);

    engine.calls.clear();
    await _pickSubdivision(tester, '♩');

    final pattern = _lastAccentPattern(engine);
    expect(pattern.length, 4, reason: 'back to one cell per beat');
    expect(pattern, [true, false, false, false]);
  });

  testWidgets('turning dynamic mode off starts a plain metronome', (
    tester,
  ) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    // The first switch in the tree is the card header's dynamic-mode
    // toggle; it sits below the fold in the test viewport.
    final toggle = find.byType(AccelSwitch).first;
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('TEMPO'), findsOneWidget, reason: 'the label swaps over');

    engine.calls.clear();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(engine.methods, contains('start'));
    expect(engine.methods, isNot(contains('startRamp')));
  });
}

/// Opens the time-signature dropdown and picks an option.
Future<void> _pickSignature(WidgetTester tester, String label) async {
  final trigger = find.text('4/4').first;
  await tester.ensureVisible(trigger);
  await tester.pumpAndSettle();
  await tester.tap(trigger);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Taps one segment of the subdivision picker.
Future<void> _pickSubdivision(WidgetTester tester, String glyph) async {
  final segment = find.text(glyph);
  await tester.ensureVisible(segment);
  await tester.pumpAndSettle();
  await tester.tap(segment);
  await tester.pumpAndSettle();
}

/// The accent pattern of the most recent `setAccentPattern` call.
List<bool> _lastAccentPattern(_FakeEngine engine) {
  final call = engine.calls.lastWhere(
    (c) => c.method == 'setAccentPattern' || c.method == 'setTimeSignature',
  );
  return ((call.arguments as Map)['accentPattern'] as List).cast<bool>();
}
