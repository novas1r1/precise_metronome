// Smoke tests — the Accel screen renders, starts a ramp with the settings
// shown on screen, and follows the native ramp/beat events.

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precise_metronome_example/main.dart';
import 'package:precise_metronome_example/screen/gap_presets_sheet.dart';
import 'package:precise_metronome_example/widgets/accel_controls.dart';
import 'package:precise_metronome_example/widgets/accel_surfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // A fresh settings store for every test: the app starts on its
    // defaults and writes nothing to the device.
    SharedPreferences.setMockInitialValues({});
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
      find.text(
        '60 → 65 → … → 120 → … → 60  ·  25 steps  ·  100 bars  ·  ~4:42',
      ),
      findsOneWidget,
    );
  });

  testWidgets('timed steps send stepMs and count down on the dial', (
    tester,
  ) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    // One minute per step by default. Each step is rounded up to whole
    // bars at its own tempo, so the plan's bar count grows with the tempo.
    expect(find.text('1:00'), findsOneWidget);
    expect(
      find.textContaining('25 steps  ·  564 bars  ·  ~25:25'),
      findsOneWidget,
    );

    await tester.tap(find.text('30s'));
    await tester.pumpAndSettle();
    expect(find.text('0:30'), findsOneWidget);

    engine.calls.clear();
    await tester.tap(find.text('Start'));
    // Not pumpAndSettle: the countdown ticks once a second while playing.
    await tester.pump();

    final args =
        engine.calls.firstWhere((c) => c.method == 'startRamp').arguments
            as Map;
    expect(args['stepMs'], 30000);
    expect(args['barsPerStep'], 0);

    engine.beats!.success({'bar': 0, 'beat': 0, 'pulse': 0, 'accent': true});
    await tester.pump();
    expect(find.textContaining(' left'), findsOneWidget);
    expect(find.textContaining('bar 1 /'), findsNothing);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(find.textContaining(' left'), findsNothing);
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

  testWidgets('the settings sheet offers every built-in voice', (tester) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    for (final label in ['Tone', 'Click', 'Wood', 'Mechanical', 'Blip']) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }
    expect(
      find.text('Volume'),
      findsNothing,
      reason: 'the label is uppercased',
    );
    expect(find.text('VOLUME'), findsOneWidget);

    engine.calls.clear();
    await tester.tap(find.text('Mechanical'));
    await tester.pumpAndSettle();

    final call = engine.calls.lastWhere((c) => c.method == 'setVoice');
    expect((call.arguments as Map)['voice'], 'mechanical');
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

  testWidgets('the gap trainer plays a pattern instead of a ramp', (
    tester,
  ) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    await _toggleCard(tester, 'Gap trainer');
    // The two trainers take turns, so the tempo field is a plain tempo now.
    expect(find.text('TEMPO'), findsOneWidget);
    expect(find.text('Fixed'), findsOneWidget);

    engine.calls.clear();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(engine.methods, contains('start'));
    expect(engine.methods, isNot(contains('startRamp')));
    final plan = engine.calls.firstWhere((c) => c.method == 'setGapPlan');
    // Two bars of click, two silent, over the eight bars sent ahead.
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

  testWidgets('a random pattern hides the bars coming up', (tester) async {
    _FakeEngine().install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    await _toggleCard(tester, 'Gap trainer');
    expect(find.text('click'), findsNWidgets(4), reason: 'fixed 2/2 previews');

    await tester.tap(find.text('Random'));
    await tester.pumpAndSettle();
    expect(find.text('?'), findsNWidgets(6));
    expect(find.text('Chance of silence'.toUpperCase()), findsOneWidget);
  });

  testWidgets('a silent bar reads on the badge and the status line', (
    tester,
  ) async {
    final engine = _FakeEngine()..install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    await _toggleCard(tester, 'Gap trainer');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    engine.beats!.success({
      'bar': 2,
      'beat': 0,
      'pulse': 0,
      'accent': true,
      'muted': true,
      'landing': false,
      'gapSegment': 1,
      'gapBar': 2,
    });
    await tester.pumpAndSettle();
    expect(find.text('Silent — hold the tempo'), findsOneWidget);
    expect(find.text('silent'), findsOneWidget, reason: 'the header badge');

    engine.beats!.success({
      'bar': 4,
      'beat': 0,
      'pulse': 0,
      'accent': true,
      'muted': false,
      'landing': true,
      'gapSegment': 1,
      'gapBar': 4,
    });
    await tester.pumpAndSettle();
    expect(find.text('Landing — were you on it?'), findsOneWidget);
    expect(find.text('landing'), findsOneWidget);
  });

  testWidgets('a preset can be played, saved and deleted', (tester) async {
    _FakeEngine().install(tester);
    await tester.pumpWidget(const AccelApp());
    await tester.pumpAndSettle();

    await _toggleCard(tester, 'Gap trainer');
    await _openPresets(tester);

    // The five built-in presets, and nothing of the user's yet. The names
    // are scoped to the sheet: "Ladder" also labels the card's mode picker
    // behind it.
    Finder inSheet(String text) => find.descendant(
      of: find.byType(GapPresetsSheet),
      matching: find.text(text),
    );
    for (final name in ['Warm-up', 'Classic', 'Advanced', 'Ladder']) {
      expect(inSheet(name), findsOneWidget, reason: '$name is missing');
    }
    expect(find.text('none yet'), findsOneWidget);

    // Playing one applies its settings: the ladder brings its own fields.
    await tester.tap(inSheet('Ladder'));
    await tester.pumpAndSettle();
    expect(find.text('FIRST GAP'), findsOneWidget);

    // Saving the settings in play puts them in the list.
    await _openPresets(tester);
    final field = find.descendant(
      of: find.byType(GapPresetsSheet),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'My ladder');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('none yet'), findsNothing);
    expect(find.text('My ladder'), findsWidgets);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('none yet'), findsOneWidget);
  });
}

/// Opens the presets sheet from the gap trainer card.
Future<void> _openPresets(WidgetTester tester) async {
  final button = find.byIcon(Icons.bookmark_add_rounded);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Flips the switch in the header of the card titled [title], scrolling it
/// into the list first — the cards below the fold are not built until then.
Future<void> _toggleCard(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  final card = find.ancestor(
    of: find.text(title),
    matching: find.byType(AccelCard),
  );
  final toggle = find
      .descendant(of: card, matching: find.byType(AccelSwitch))
      .first;
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
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
