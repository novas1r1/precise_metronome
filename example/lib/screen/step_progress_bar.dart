import 'package:flutter/material.dart';

import '../design/accel_tokens.dart';

/// The thin line under the dial showing how far the current ramp step has
/// progressed, in the ramp's direction color.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.progress,
    required this.descending,
  });

  /// 0..1 through the current step.
  final double progress;
  final bool descending;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 3,
        backgroundColor: AccelColors.surfaceGlassStrong,
        valueColor: AlwaysStoppedAnimation(
          descending ? AccelColors.info : AccelColors.accent,
        ),
      ),
    );
  }
}
