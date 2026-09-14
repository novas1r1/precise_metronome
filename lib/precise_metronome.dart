/// A sample-accurate, production-grade Flutter metronome.
///
/// Use [Metronome] for the main control surface. Timing is handled entirely
/// on the native side (AVAudioEngine on iOS, Oboe on Android) and is immune
/// to Dart GC pauses.
library;

export 'src/background_config.dart';
export 'src/beat_event.dart';
export 'src/gap_pattern.dart';
export 'src/tempo_ramp.dart';
export 'src/metronome.dart';
export 'src/subdivision.dart';
export 'src/tap_tempo.dart';
export 'src/time_signature.dart';
export 'src/voice.dart';
