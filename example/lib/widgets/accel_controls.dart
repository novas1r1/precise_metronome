import 'package:flutter/material.dart';

import '../design/accel_tokens.dart';

/// Accel's control primitives, transcribed from
/// `docs/design_system/components/core/*.jsx`.
///
/// Icons stand in for Lucide with Material's rounded set — the design
/// system flags its own icons as a placeholder until a brand set exists.

// ---------------------------------------------------------------- helpers

/// Press feedback shared by every tappable control: scale down, no ripple.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onTap,
    required this.builder,
    this.pressedScale = 0.97,
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool pressed) builder;
  final double pressedScale;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: AccelMotion.fast,
        curve: AccelMotion.easeOut,
        child: widget.builder(context, _pressed),
      ),
    );
  }
}

/// The tiny tracked all-caps label above a control.
class AccelLabel extends StatelessWidget {
  const AccelLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(text.toUpperCase(), style: AccelType.label());
    if (trailing == null) return label;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [label, trailing!],
    );
  }
}

// ----------------------------------------------------------------- button

enum AccelButtonVariant { primary, secondary }

enum AccelButtonSize { md, lg, xl }

class AccelButton extends StatelessWidget {
  const AccelButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AccelButtonVariant.primary,
    this.size = AccelButtonSize.md,
    this.glow = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AccelButtonVariant variant;
  final AccelButtonSize size;
  final bool glow;
  final bool fullWidth;

  double get _height => switch (size) {
    AccelButtonSize.md => AccelControl.md,
    AccelButtonSize.lg => AccelControl.lg,
    AccelButtonSize.xl => AccelControl.xl,
  };

  double get _fontSize => switch (size) {
    AccelButtonSize.md => 15,
    AccelButtonSize.lg => 17,
    AccelButtonSize.xl => 20,
  };

  @override
  Widget build(BuildContext context) {
    final primary = variant == AccelButtonVariant.primary;
    final enabled = onPressed != null;
    final foreground = primary
        ? AccelColors.textOnAccent
        : AccelColors.textPrimary;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: _Pressable(
        onTap: onPressed,
        builder: (context, pressed) => AnimatedContainer(
          duration: AccelMotion.base,
          curve: AccelMotion.easeOut,
          height: _height,
          width: fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: size == AccelButtonSize.xl ? 40 : 24),
          decoration: BoxDecoration(
            color: primary
                ? (pressed ? AccelColors.accentPress : AccelColors.accent)
                : (pressed
                      ? AccelColors.surfaceGlass
                      : AccelColors.surfaceGlassStrong),
            borderRadius: AccelRadius.pill,
            border: Border.all(
              color: primary
                  ? Colors.transparent
                  : AccelColors.surfaceGlassBorder,
            ),
            boxShadow: glow && primary && enabled
                ? AccelShadow.accentGlow()
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _fontSize + 2, color: foreground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AccelType.display(
                  size: _fontSize,
                  weight: 600,
                  letterSpacing: -0.01 * _fontSize,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccelIconButton extends StatelessWidget {
  const AccelIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = AccelControl.md,
    this.ghost = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      label: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: _Pressable(
          onTap: onPressed,
          pressedScale: 0.94,
          builder: (context, pressed) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: ghost
                  ? (pressed ? AccelColors.surfaceGlass : Colors.transparent)
                  : (pressed
                        ? AccelColors.surfaceGlassStrong
                        : AccelColors.surfaceGlass),
              borderRadius: AccelRadius.pill,
              border: Border.all(
                color: ghost
                    ? Colors.transparent
                    : AccelColors.surfaceGlassBorder,
              ),
            ),
            child: Icon(
              icon,
              size: size * 0.45,
              color: ghost
                  ? AccelColors.textSecondary
                  : AccelColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ badge

enum AccelBadgeTone { neutral, accent, info, positive }

class AccelBadge extends StatelessWidget {
  const AccelBadge({
    super.key,
    required this.label,
    this.tone = AccelBadgeTone.neutral,
    this.dot = false,
  });

  final String label;
  final AccelBadgeTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      AccelBadgeTone.neutral => (
        AccelColors.surfaceGlassStrong,
        AccelColors.textSecondary,
      ),
      AccelBadgeTone.accent => (AccelColors.accentSoft, AccelColors.coral300),
      AccelBadgeTone.info => (AccelColors.infoSoft, AccelColors.info),
      AccelBadgeTone.positive => (
        AccelColors.positiveSoft,
        AccelColors.positive,
      ),
    };

    return AnimatedContainer(
      duration: AccelMotion.base,
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AccelRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: foreground, blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: AccelType.mono(size: 12, color: foreground)),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- switch

class AccelSwitch extends StatelessWidget {
  const AccelSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.description,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final track = AnimatedContainer(
      duration: AccelMotion.base,
      curve: AccelMotion.easeOut,
      width: 52,
      height: 30,
      decoration: BoxDecoration(
        color: value ? AccelColors.accent : AccelColors.surfaceGlassStrong,
        borderRadius: AccelRadius.pill,
        border: Border.all(
          color: value ? Colors.transparent : AccelColors.surfaceGlassBorder,
        ),
        boxShadow: value ? AccelShadow.accentGlow(opacity: 0.6) : null,
      ),
      child: AnimatedAlign(
        duration: AccelMotion.base,
        curve: AccelMotion.spring,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? AccelColors.navy950 : AccelColors.ink200,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: label == null
            ? track
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label!,
                          style: AccelType.display(size: 16, weight: 500),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            description!,
                            style: AccelType.display(
                              size: 13,
                              weight: 400,
                              color: AccelColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  track,
                ],
              ),
      ),
    );
  }
}

// -------------------------------------------------------------- segmented

class AccelSegmentedOption<T> {
  const AccelSegmentedOption(this.value, this.label);
  final T value;
  final String label;
}

class AccelSegmented<T> extends StatelessWidget {
  const AccelSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.labelStyle,
  });

  final List<AccelSegmentedOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? label;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final index = options.indexWhere((o) => o.value == value);
    final control = LayoutBuilder(
      builder: (context, constraints) {
        final inner = constraints.maxWidth - 8;
        final slot = inner / options.length;
        return Container(
          height: AccelControl.md,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AccelColors.surfaceInput,
            borderRadius: AccelRadius.mdAll,
            border: Border.all(color: AccelColors.surfaceGlassBorder),
          ),
          child: Stack(
            children: [
              if (index >= 0)
                AnimatedPositioned(
                  duration: AccelMotion.base,
                  curve: AccelMotion.spring,
                  left: slot * index,
                  width: slot,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AccelColors.surfaceGlassStrong,
                      borderRadius: AccelRadius.smAll,
                      border: Border.all(color: AccelColors.borderStrong),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(option.value),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: AccelMotion.fast,
                            style:
                                (labelStyle ??
                                        AccelType.display(
                                          size: 14,
                                          weight: 600,
                                        ))
                                    .copyWith(
                                      color: option.value == value
                                          ? AccelColors.textPrimary
                                          : AccelColors.textSecondary,
                                    ),
                            child: Text(option.label),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (label == null) return control;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccelLabel(label!),
        const SizedBox(height: 8),
        control,
      ],
    );
  }
}

// ----------------------------------------------------------------- slider

class AccelSlider extends StatelessWidget {
  const AccelSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.label,
    this.readout,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final String? label;
  final String? readout;

  @override
  Widget build(BuildContext context) {
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null || readout != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null) AccelLabel(label!),
              if (readout != null)
                Text(readout!, style: AccelType.mono(size: 12)),
            ],
          ),
          const SizedBox(height: 10),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            void update(Offset local) {
              final next =
                  min +
                  (local.dx / constraints.maxWidth).clamp(0.0, 1.0) *
                      (max - min);
              onChanged(next);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => update(d.localPosition),
              onHorizontalDragUpdate: (d) => update(d.localPosition),
              child: SizedBox(
                height: 28,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: AccelColors.surfaceGlassStrong,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AccelColors.accent,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: AccelShadow.accentGlow(opacity: 0.5),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (constraints.maxWidth - 24) * fraction,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AccelColors.ink100,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x80000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ number field

/// The stepper at the heart of dynamic mode: minus / value / plus.
class AccelNumberField extends StatelessWidget {
  const AccelNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
    this.step = 1,
    this.unit,
    this.large = false,
    this.enabled = true,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final String? unit;
  final bool large;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, double delta) {
      final canPress =
          enabled && (delta < 0 ? value > min : value < max);
      return _Pressable(
        onTap: canPress
            ? () => onChanged((value + delta * step).clamp(min, max))
            : null,
        pressedScale: 0.9,
        builder: (context, pressed) => Container(
          width: large ? 56 : 44,
          height: double.infinity,
          color: pressed ? AccelColors.surfaceGlassStrong : Colors.transparent,
          child: Icon(
            icon,
            size: 20,
            color: canPress ? AccelColors.textPrimary : AccelColors.textMuted,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccelLabel(label),
        const SizedBox(height: 8),
        Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            height: large ? AccelControl.xl : AccelControl.lg,
            decoration: BoxDecoration(
              color: AccelColors.surfaceInput,
              borderRadius: AccelRadius.mdAll,
              border: Border.all(color: AccelColors.surfaceGlassBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                button(Icons.remove_rounded, -1),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatted,
                        style: AccelType.display(
                          size: large ? 30 : 24,
                          weight: large ? 800 : 700,
                          letterSpacing: -0.02 * (large ? 30 : 24),
                          tabularFigures: true,
                        ),
                      ),
                      if (unit != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          unit!,
                          style: AccelType.mono(
                            size: 11,
                            letterSpacing: 1.1,
                            color: AccelColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                button(Icons.add_rounded, 1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _formatted => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}
