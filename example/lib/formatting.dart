/// Number and time formatting shared by the screen and its model.
library;

/// A tempo for display: whole numbers without a decimal point, anything
/// else to one decimal place — `120`, `97.5`.
String formatBpm(double bpm) => bpm == bpm.roundToDouble()
    ? bpm.round().toString()
    : bpm.toStringAsFixed(1);

/// A duration as a clock reading: `m:ss`, or `h:mm:ss` from an hour up.
String formatClock(Duration duration) {
  final total = duration.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}
