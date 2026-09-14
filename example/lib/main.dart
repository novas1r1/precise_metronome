import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/accel_tokens.dart';
import 'metronome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AccelColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AccelApp());
}

/// Accel — a dynamic metronome built on `precise_metronome`, styled with
/// the Accel design system in `docs/design_system/`.
class AccelApp extends StatelessWidget {
  const AccelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AccelColors.bg,
        fontFamily: AccelType.displayFamily,
        colorScheme: const ColorScheme.dark(
          surface: AccelColors.bg,
          primary: AccelColors.accent,
          secondary: AccelColors.accent,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const MetronomeScreen(),
    );
  }
}
