import 'package:flutter/material.dart';

import '../design/accel_tokens.dart';
import 'layout.dart';

/// Shown in place of the controls when the native audio engine failed to
/// initialise.
class EngineErrorView extends StatelessWidget {
  const EngineErrorView({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ScreenLayout.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'The audio engine did not start',
            style: AccelType.display(size: 20, weight: 600),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: AccelType.mono(size: 12, color: AccelColors.textMuted),
          ),
        ],
      ),
    );
  }
}
