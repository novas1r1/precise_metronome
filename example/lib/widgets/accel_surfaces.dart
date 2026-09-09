import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../design/accel_tokens.dart';
import 'accel_controls.dart';

/// Soft glass surfaces: translucent white over navy, hairline border,
/// 18px backdrop blur, deep soft shadow. No dividers inside — use spacing.
class AccelCard extends StatelessWidget {
  const AccelCard({
    super.key,
    required this.child,
    this.title,
    this.action,
    this.glow = false,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final String? title;
  final Widget? action;
  final bool glow;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // The glow is drawn behind the card and clipped to the area *outside*
    // it: CSS clips an outer box-shadow at the border box, so it never
    // shows through a translucent surface. Flutter's BoxShadow would.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (glow)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipPath(
                clipper: _OutsideRoundedRect(),
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: AccelRadius.lgAll,
                    boxShadow: [
                      BoxShadow(
                        color: AccelColors.accentGlow,
                        blurRadius: 60,
                        spreadRadius: -20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        _surface(context),
      ],
    );
  }

  Widget _surface(BuildContext context) {
    return ClipRRect(
      borderRadius: AccelRadius.lgAll,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: AccelMotion.slow,
          curve: AccelMotion.easeOut,
          padding: padding,
          decoration: BoxDecoration(
            color: AccelColors.surfaceGlass,
            borderRadius: AccelRadius.lgAll,
            border: Border.all(color: AccelColors.surfaceGlassBorder),
            boxShadow: AccelShadow.glass,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || action != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title ?? '',
                        style: AccelType.display(
                          size: 20,
                          weight: 600,
                          letterSpacing: -0.02 * 20,
                        ),
                      ),
                    ),
                    if (action != null) action!,
                  ],
                ),
                const SizedBox(height: 16),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Clips to everything *outside* the card's rounded rect, so a shadow drawn
/// through it only shows as a halo around the card.
class _OutsideRoundedRect extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const bleed = 90.0;
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(
        Rect.fromLTRB(-bleed, -bleed, size.width + bleed, size.height + bleed),
      )
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, AccelRadius.lg),
      );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// The transient status pill that fades up under the header.
class AccelToast extends StatelessWidget {
  const AccelToast({
    super.key,
    required this.message,
    this.icon = Icons.check_rounded,
    this.tone = AccelColors.positive,
  });

  final String message;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 16),
      decoration: BoxDecoration(
        color: AccelColors.navy800,
        borderRadius: AccelRadius.pill,
        border: Border.all(color: AccelColors.borderStrong),
        boxShadow: AccelShadow.float,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: 10),
          Text(message, style: AccelType.display(size: 14, weight: 500)),
        ],
      ),
    );
  }
}

/// The settings sheet: a bottom sheet on the navy-800 surface.
class AccelSheet extends StatelessWidget {
  const AccelSheet({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
  });

  final String title;
  final Widget child;
  final VoidCallback onClose;

  static Future<void> show({
    required BuildContext context,
    required String title,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x99070B18),
      isScrollControlled: true,
      builder: (context) => AccelSheet(
        title: title,
        onClose: () => Navigator.of(context).pop(),
        child: builder(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AccelColors.navy800,
        borderRadius: BorderRadius.only(
          topLeft: AccelRadius.xl,
          topRight: AccelRadius.xl,
        ),
        border: Border(
          top: BorderSide(color: AccelColors.borderStrong),
        ),
        boxShadow: AccelShadow.float,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AccelType.display(
                      size: 26,
                      weight: 700,
                      letterSpacing: -0.02 * 26,
                    ),
                  ),
                ),
                AccelIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  size: AccelControl.sm,
                  ghost: true,
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
