import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../accel_metronome.dart';
import '../design/accel_tokens.dart';

/// The dial. On every beat a ring expands out of it and fades
/// (`accel-beat`: scale 1 → 1.9, 520ms, ease-out) while the glass disc
/// pulses (`accel-pulse`: 1 → 1.045). Dots around the rim mark the beats
/// of the bar; the current one grows and takes the beat color.
///
/// The ring is driven by [beatTick] rather than by a local timer: the
/// package delivers `BeatEvent`s close to the moment the click is heard,
/// so what you see is the click you just heard, not a Dart approximation
/// of it.
class BeatRing extends StatefulWidget {
  const BeatRing({
    super.key,
    required this.beatTick,
    required this.beatIndex,
    required this.beatsPerBar,
    required this.accent,
    required this.direction,
    required this.running,
    required this.size,
    required this.child,
  });

  final int beatTick;
  final int? beatIndex;
  final int beatsPerBar;
  final bool accent;
  final TempoDirection direction;
  final bool running;
  final double size;
  final Widget child;

  @override
  State<BeatRing> createState() => _BeatRingState();
}

class _BeatRingState extends State<BeatRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AccelMotion.beat,
  );

  @override
  void didUpdateWidget(BeatRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.beatTick != oldWidget.beatTick) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _beatColor => widget.accent
      ? AccelColors.beatAccent
      : widget.direction == TempoDirection.down
      ? AccelColors.beatDown
      : AccelColors.beatUp;

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.direction == TempoDirection.down
        ? AccelColors.beatDown
        : AccelColors.accent;

    return SizedBox(
      width: widget.size + 28,
      height: widget.size + 28,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // accel-beat: ease-out over the ring's whole life.
          final t = AccelMotion.easeOut.transform(_controller.value);
          // accel-pulse: a short squeeze on the disc itself, 300/520 of
          // the ring's duration.
          final pulseT = (_controller.value * AccelMotion.beat.inMilliseconds /
                  300)
              .clamp(0.0, 1.0);
          final pulse = 1 + 0.045 * math.sin(pulseT * math.pi);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Radial glow behind the dial, brighter on an accent.
              IgnorePointer(
                child: AnimatedContainer(
                  duration: AccelMotion.fast,
                  width: widget.size * 1.6,
                  height: widget.size * 1.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        glowColor.withValues(
                          alpha: widget.accent ? 0.35 : 0.2,
                        ),
                        glowColor.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.6],
                    ),
                  ),
                ),
              ),
              // The expanding beat ring: it fades out as it grows, so it is
              // gone by the time it reaches 1.9× (`accel-beat` animates
              // scale and opacity together).
              if (widget.running && _controller.value > 0)
                IgnorePointer(
                  child: Opacity(
                    opacity: (0.9 * (1 - t)).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1 + 0.9 * t,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _beatColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              // The glass disc.
              Transform.scale(
                scale: widget.running ? pulse : 1,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AccelColors.surfaceGlass,
                        border: Border.all(
                          color: AccelColors.surfaceGlassBorder,
                        ),
                        boxShadow: AccelShadow.glass,
                      ),
                      child: Center(child: child),
                    ),
                  ),
                ),
              ),
              // Beat dots around the rim.
              IgnorePointer(
                child: CustomPaint(
                  size: Size.square(widget.size + 28),
                  painter: _BeatDotsPainter(
                    beatsPerBar: widget.beatsPerBar,
                    activeBeat: widget.running ? widget.beatIndex : null,
                    activeColor: _beatColor,
                    downbeatColor: AccelColors.beatAccent,
                  ),
                ),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _BeatDotsPainter extends CustomPainter {
  _BeatDotsPainter({
    required this.beatsPerBar,
    required this.activeBeat,
    required this.activeColor,
    required this.downbeatColor,
  });

  final int beatsPerBar;
  final int? activeBeat;
  final Color activeColor;
  final Color downbeatColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.46;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < beatsPerBar; i++) {
      final angle = -math.pi / 2 + i / beatsPerBar * 2 * math.pi;
      final on = activeBeat != null && activeBeat! % beatsPerBar == i;
      paint.color = on
          ? (i == 0 ? downbeatColor : activeColor)
          : AccelColors.ink400;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        on ? size.width * 0.026 : size.width * 0.015,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BeatDotsPainter old) =>
      old.beatsPerBar != beatsPerBar ||
      old.activeBeat != activeBeat ||
      old.activeColor != activeColor;
}
