// Smoke test — verifies the example app renders without throwing.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:precise_metronome_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('precise_metronome'),
      (call) async => null,
    );
  });

  testWidgets('MetronomeApp renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MetronomeApp());
    expect(find.text('precise_metronome'), findsOneWidget);
  });
}
