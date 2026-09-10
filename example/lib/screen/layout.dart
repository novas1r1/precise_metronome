import 'package:flutter/widgets.dart';

/// Layout metrics shared by the screen's sections.
abstract final class ScreenLayout {
  /// Horizontal padding between the content and the screen edge.
  static const double gutter = 20;

  /// Mobile-first at 390px: on wider screens the content is centered and
  /// capped at this width.
  static const double maxContentWidth = 480;
}

/// Centers [child] and caps it at [ScreenLayout.maxContentWidth].
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ScreenLayout.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
