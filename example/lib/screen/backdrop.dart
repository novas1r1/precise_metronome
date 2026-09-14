import 'package:flutter/material.dart';

import '../design/accel_tokens.dart';

/// One large radial coral glow behind the dial, switching to sky blue
/// while the ramp steps back down and brightening while the metronome
/// runs.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.running, required this.descending});

  final bool running;
  final bool descending;

  static const double _size = 520;

  @override
  Widget build(BuildContext context) {
    final color = descending ? AccelColors.beatDown : AccelColors.accent;
    return IgnorePointer(
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: running ? 0.28 : 0.14),
                color.withValues(alpha: 0),
              ],
              stops: const [0, 0.62],
            ),
          ),
        ),
      ),
    );
  }
}
