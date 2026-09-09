import 'package:flutter/material.dart';

import '../design/accel_tokens.dart';
import 'accel_controls.dart';

/// A compact dropdown: the trigger takes the accent border while open and
/// the panel fades up beneath it on navy-800.
class AccelSelect<T> extends StatefulWidget {
  const AccelSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.valueStyle,
  });

  final String label;
  final T value;
  final List<AccelSegmentedOption<T>> options;
  final ValueChanged<T> onChanged;
  final TextStyle? valueStyle;

  @override
  State<AccelSelect<T>> createState() => _AccelSelectState<T>();
}

class _AccelSelectState<T> extends State<AccelSelect<T>> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    final open = _portal.isShowing;
    final current = widget.options
        .where((o) => o.value == widget.value)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccelLabel(widget.label),
        const SizedBox(height: 8),
        CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: _buildPanel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(_portal.toggle),
              child: AnimatedContainer(
                duration: AccelMotion.fast,
                height: AccelControl.md,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AccelColors.surfaceInput,
                  borderRadius: AccelRadius.mdAll,
                  border: Border.all(
                    color: open
                        ? AccelColors.accent
                        : AccelColors.surfaceGlassBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        current?.label ?? '—',
                        style:
                            widget.valueStyle ??
                            AccelType.display(size: 16, weight: 500),
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: AccelMotion.base,
                      curve: AccelMotion.easeOut,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AccelColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    return Stack(
      children: [
        // Tap anywhere else to dismiss.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(_portal.hide),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AccelMotion.base,
              curve: AccelMotion.easeOut,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: child,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AccelColors.navy800,
                    borderRadius: AccelRadius.mdAll,
                    border: Border.all(color: AccelColors.borderStrong),
                    boxShadow: AccelShadow.float,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final option in widget.options)
                        _Option(
                          label: option.label,
                          selected: option.value == widget.value,
                          onTap: () {
                            widget.onChanged(option.value);
                            setState(_portal.hide);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AccelColors.accentSoft : Colors.transparent,
          borderRadius: AccelRadius.smAll,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AccelType.display(
                  size: 15,
                  weight: 500,
                  color: selected
                      ? AccelColors.coral300
                      : AccelColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: AccelColors.coral300,
              ),
          ],
        ),
      ),
    );
  }
}
