import 'package:flutter/material.dart';

import '../design/accel_tokens.dart';
import '../widgets/accel_controls.dart';
import 'layout.dart';

/// Start/stop and reset, on a gradient that fades the scrolling content out
/// before it reaches the buttons. Meant to sit at the bottom of a `Stack`.
class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.playing,
    required this.enabled,
    required this.onToggle,
    required this.onReset,
  });

  final bool playing;

  /// Whether the engine is ready to be started.
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00070B18), AccelColors.bg],
          stops: [0, 0.55],
        ),
      ),
      child: SafeArea(
        top: false,
        child: ContentWidth(
          child: Padding(
            // The extra top padding gives the gradient room to fade.
            padding: const EdgeInsets.fromLTRB(
              ScreenLayout.gutter,
              56,
              ScreenLayout.gutter,
              16,
            ),
            child: Row(
              children: [
                AccelIconButton(
                  icon: Icons.replay_rounded,
                  tooltip: 'Reset',
                  size: AccelControl.lg,
                  onPressed: playing ? onReset : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AccelButton(
                    label: playing ? 'Stop' : 'Start',
                    icon: playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: AccelButtonSize.xl,
                    fullWidth: true,
                    glow: !playing,
                    variant: playing
                        ? AccelButtonVariant.secondary
                        : AccelButtonVariant.primary,
                    onPressed: enabled ? onToggle : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
