import 'package:flutter/material.dart';

import '../accel_metronome.dart';
import '../design/accel_tokens.dart';

/// The gap trainer's bar strip: the bar playing and the ones coming up.
///
/// Each cell says what it is — `click`, `gap`, or `?` for a bar a random
/// pattern keeps to itself — so the strip reads without relying on colour.
/// The bar playing wears the accent border.
class GapStrip extends StatelessWidget {
  const GapStrip({super.key, required this.cells});

  final List<GapStripCell> cells;

  static String _describe(GapStripCell cell) => switch (cell.silent) {
    null => 'unknown',
    true => 'gap',
    false => 'click',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Bars coming up: ${cells.map(_describe).join(', ')}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final (index, cell) in cells.indexed) ...[
            if (index > 0) const SizedBox(width: 5),
            Expanded(child: _StripCell(cell: cell)),
          ],
        ],
      ),
    );
  }
}

class _StripCell extends StatelessWidget {
  const _StripCell({required this.cell});

  final GapStripCell cell;

  @override
  Widget build(BuildContext context) {
    final silent = cell.silent;
    final label = switch (silent) {
      null => '?',
      true => 'gap',
      false => 'click',
    };
    final textColor = cell.current
        ? AccelColors.coral300
        : silent == false
        ? AccelColors.textSecondary
        : AccelColors.textMuted;

    return AnimatedContainer(
      duration: AccelMotion.fast,
      curve: AccelMotion.easeOut,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // A clicking bar is filled, a gap is left empty.
        color: silent == false
            ? AccelColors.surfaceGlassStrong
            : Colors.transparent,
        borderRadius: AccelRadius.smAll,
        border: Border.all(
          color: cell.current
              ? AccelColors.accent
              : AccelColors.surfaceGlassBorder,
          width: cell.current ? 2 : 1,
        ),
      ),
      child: Text(label, style: AccelType.mono(size: 10, color: textColor)),
    );
  }
}
