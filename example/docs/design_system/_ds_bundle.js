/* @ds-bundle: {"format":4,"namespace":"AccelDesignSystem_faf4ef","components":[{"name":"AccentGrid","sourcePath":"components/core/AccentGrid.jsx"},{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"BeatRing","sourcePath":"components/core/BeatRing.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"Dialog","sourcePath":"components/core/Dialog.jsx"},{"name":"Icon","sourcePath":"components/core/Icon.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"Input","sourcePath":"components/core/Input.jsx"},{"name":"NumberField","sourcePath":"components/core/NumberField.jsx"},{"name":"Segmented","sourcePath":"components/core/Segmented.jsx"},{"name":"Select","sourcePath":"components/core/Select.jsx"},{"name":"Slider","sourcePath":"components/core/Slider.jsx"},{"name":"Switch","sourcePath":"components/core/Switch.jsx"},{"name":"Toast","sourcePath":"components/core/Toast.jsx"},{"name":"Tooltip","sourcePath":"components/core/Tooltip.jsx"}],"sourceHashes":{"components/core/AccentGrid.jsx":"68470c6b6e7f","components/core/Badge.jsx":"ed2d11f17a32","components/core/BeatRing.jsx":"6ebd786f2ff3","components/core/Button.jsx":"e1b4e13ecf6a","components/core/Card.jsx":"6b4c7b0f186d","components/core/Dialog.jsx":"a356664a40f1","components/core/Icon.jsx":"6871abaf9178","components/core/IconButton.jsx":"a77c03a291e9","components/core/Input.jsx":"81323c61aa8a","components/core/NumberField.jsx":"0d645f433874","components/core/Segmented.jsx":"8fb0d502b2f2","components/core/Select.jsx":"7ce8c290e9f8","components/core/Slider.jsx":"2ccedae3cd69","components/core/Switch.jsx":"accaed0fef77","components/core/Toast.jsx":"892015f7ec0b","components/core/Tooltip.jsx":"63855cab7320","ui_kits/accel-app/MetronomeScreen.jsx":"04ece768823a","ui_kits/accel-app/useMetronome.js":"c02ec80f52ed"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.AccelDesignSystem_faf4ef = window.AccelDesignSystem_faf4ef || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/AccentGrid.jsx
try { (() => {
function AccentGrid({
  beats = 4,
  subdiv = 1,
  accents = [],
  onChange,
  label,
  current,
  style
}) {
  const n = beats * subdiv;
  const toggle = i => {
    const s = new Set(accents);
    s.has(i) ? s.delete(i) : s.add(i);
    onChange([...s].sort((a, b) => a - b));
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'baseline'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '600 var(--text-label) var(--font-body)',
      letterSpacing: 'var(--tracking-label)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)'
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 12px var(--font-mono)',
      color: 'var(--text-muted)'
    }
  }, accents.length === 0 ? 'none' : accents.length)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(' + n + ',1fr)',
      gap: subdiv > 1 ? 4 : 6,
      padding: 6,
      borderRadius: 'var(--radius-md)',
      background: 'var(--surface-input)',
      border: '1px solid var(--surface-glass-border)',
      boxSizing: 'border-box'
    }
  }, Array.from({
    length: n
  }).map((_, i) => {
    const on = accents.includes(i);
    const main = i % subdiv === 0;
    const live = current === i;
    return /*#__PURE__*/React.createElement("button", {
      key: i,
      onClick: () => toggle(i),
      "aria-pressed": on,
      title: main ? 'Beat ' + (i / subdiv + 1) : 'Subdivision',
      style: {
        height: 44,
        minWidth: 0,
        padding: 0,
        border: 0,
        borderRadius: 'var(--radius-sm)',
        background: on ? 'var(--accent)' : main ? 'var(--surface-glass-strong)' : 'var(--surface-glass)',
        boxShadow: on ? '0 0 16px var(--accent-glow)' : 'none',
        cursor: 'pointer',
        outline: 'none',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        transform: live ? 'scale(0.9)' : 'none',
        transition: 'all var(--dur-fast) var(--ease-out)'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        width: on ? 8 : main ? 6 : 4,
        height: on ? 8 : main ? 6 : 4,
        borderRadius: '50%',
        background: on ? 'var(--navy-950)' : live ? 'var(--text-primary)' : 'var(--ink-400)',
        transition: 'all var(--dur-fast)'
      }
    }));
  })));
}
Object.assign(__ds_scope, { AccentGrid });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/AccentGrid.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
const tones = {
  neutral: ['var(--surface-glass-strong)', 'var(--text-secondary)'],
  accent: ['var(--accent-soft)', 'var(--coral-300)'],
  positive: ['var(--positive-soft)', 'var(--positive)'],
  warning: ['var(--warning-soft)', 'var(--warning)'],
  info: ['var(--info-soft)', 'var(--info)']
};
function Badge({
  children,
  tone = 'neutral',
  mono = true,
  dot,
  style
}) {
  const [bg, fg] = tones[tone];
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      height: 24,
      padding: '0 10px',
      borderRadius: 'var(--radius-pill)',
      background: bg,
      color: fg,
      font: mono ? '500 12px var(--font-mono)' : '600 12px var(--font-body)',
      whiteSpace: 'nowrap',
      ...style
    }
  }, dot && /*#__PURE__*/React.createElement("span", {
    style: {
      width: 6,
      height: 6,
      borderRadius: '50%',
      background: fg,
      boxShadow: '0 0 8px ' + fg
    }
  }), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/BeatRing.jsx
try { (() => {
function BeatRing({
  beat,
  beatsPerBar = 4,
  accent,
  size = 280,
  direction = 'up',
  children,
  style
}) {
  const color = direction === 'down' ? 'var(--beat-down)' : 'var(--beat-up)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: size,
      height: size,
      flex: 'none',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: '-30%',
      borderRadius: '50%',
      background: 'radial-gradient(circle,' + (direction === 'down' ? 'rgba(111,180,255,0.35)' : 'var(--accent-glow)') + ' 0%,transparent 60%)',
      opacity: accent ? 1 : 0.55,
      transition: 'opacity 150ms',
      pointerEvents: 'none'
    }
  }), beat != null && /*#__PURE__*/React.createElement("div", {
    key: beat,
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: '50%',
      border: '2px solid ' + (accent ? 'var(--beat-accent)' : color),
      animation: 'accel-beat 520ms var(--ease-out) forwards'
    }
  }), /*#__PURE__*/React.createElement("div", {
    key: 'p' + beat,
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: '50%',
      background: 'var(--surface-glass)',
      border: '1px solid var(--surface-glass-border)',
      backdropFilter: 'var(--blur-glass)',
      boxShadow: 'var(--shadow-glass)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      animation: beat != null ? 'accel-pulse 300ms var(--ease-out)' : 'none'
    }
  }, children), /*#__PURE__*/React.createElement("svg", {
    viewBox: "0 0 100 100",
    style: {
      position: 'absolute',
      inset: -14,
      width: 'calc(100% + 28px)',
      height: 'calc(100% + 28px)',
      pointerEvents: 'none'
    }
  }, Array.from({
    length: beatsPerBar
  }).map((_, i) => {
    const a = -Math.PI / 2 + i / beatsPerBar * 2 * Math.PI;
    const on = beat != null && beat % beatsPerBar === i;
    return /*#__PURE__*/React.createElement("circle", {
      key: i,
      cx: 50 + 46 * Math.cos(a),
      cy: 50 + 46 * Math.sin(a),
      r: on ? 2.6 : 1.5,
      fill: on ? i === 0 ? 'var(--beat-accent)' : color : 'var(--ink-400)',
      style: {
        transition: 'all 120ms'
      }
    });
  })));
}
Object.assign(__ds_scope, { BeatRing });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/BeatRing.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const base = {
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  gap: 8,
  border: '1px solid transparent',
  borderRadius: 'var(--radius-pill)',
  fontFamily: 'var(--font-body)',
  fontWeight: 600,
  letterSpacing: '-0.01em',
  cursor: 'pointer',
  transition: 'background var(--dur-fast) var(--ease-out),transform var(--dur-fast) var(--ease-out),box-shadow var(--dur-base) var(--ease-out)',
  whiteSpace: 'nowrap',
  outline: 'none'
};
const sizes = {
  sm: {
    height: 'var(--control-h-sm)',
    padding: '0 14px',
    fontSize: 14
  },
  md: {
    height: 'var(--control-h-md)',
    padding: '0 20px',
    fontSize: 15
  },
  lg: {
    height: 'var(--control-h-lg)',
    padding: '0 28px',
    fontSize: 17
  },
  xl: {
    height: 'var(--control-h-xl)',
    padding: '0 40px',
    fontSize: 20
  }
};
const variants = {
  primary: {
    bg: 'var(--accent)',
    hover: 'var(--accent-hover)',
    press: 'var(--accent-press)',
    color: 'var(--text-on-accent)',
    shadow: 'var(--shadow-accent-glow)'
  },
  secondary: {
    bg: 'var(--surface-glass)',
    hover: 'var(--surface-glass-strong)',
    press: 'var(--surface-glass)',
    color: 'var(--text-primary)',
    border: 'var(--surface-glass-border)'
  },
  ghost: {
    bg: 'transparent',
    hover: 'var(--surface-glass)',
    press: 'var(--surface-glass-strong)',
    color: 'var(--text-secondary)'
  },
  danger: {
    bg: 'var(--accent-soft)',
    hover: 'rgba(255,94,69,0.26)',
    press: 'var(--accent-soft)',
    color: 'var(--coral-300)'
  }
};
function Button({
  variant = 'primary',
  size = 'md',
  children,
  icon,
  disabled,
  glow,
  fullWidth,
  style,
  ...rest
}) {
  const [s, setS] = React.useState('idle');
  const v = variants[variant];
  const bg = s === 'press' ? v.press : s === 'hover' ? v.hover : v.bg;
  return /*#__PURE__*/React.createElement("button", _extends({
    disabled: disabled
  }, rest, {
    onMouseEnter: () => setS('hover'),
    onMouseLeave: () => setS('idle'),
    onMouseDown: () => setS('press'),
    onMouseUp: () => setS('hover'),
    style: {
      ...base,
      ...sizes[size],
      background: bg,
      color: v.color,
      borderColor: v.border || 'transparent',
      boxShadow: glow && variant === 'primary' ? v.shadow : 'none',
      transform: s === 'press' ? 'scale(0.97)' : 'none',
      opacity: disabled ? 0.4 : 1,
      pointerEvents: disabled ? 'none' : 'auto',
      width: fullWidth ? '100%' : undefined,
      ...style
    }
  }), icon && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      width: size === 'sm' ? 16 : 20,
      height: size === 'sm' ? 16 : 20
    }
  }, icon), children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function Card({
  children,
  title,
  action,
  solid,
  padding = 20,
  glow,
  style
}) {
  return /*#__PURE__*/React.createElement("section", {
    style: {
      position: 'relative',
      borderRadius: 'var(--radius-lg)',
      background: solid ? 'var(--surface-card)' : 'var(--surface-glass)',
      border: '1px solid var(--surface-glass-border)',
      backdropFilter: solid ? undefined : 'var(--blur-glass)',
      WebkitBackdropFilter: solid ? undefined : 'var(--blur-glass)',
      boxShadow: glow ? 'var(--shadow-glass), 0 0 60px -20px var(--accent-glow)' : 'var(--shadow-glass)',
      padding,
      boxSizing: 'border-box',
      ...style
    }
  }, (title || action) && /*#__PURE__*/React.createElement("header", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: 12,
      marginBottom: 16
    }
  }, /*#__PURE__*/React.createElement("h3", {
    style: {
      margin: 0,
      font: '600 var(--text-h3) var(--font-display)',
      letterSpacing: 'var(--tracking-tight)'
    }
  }, title), action), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon.jsx
try { (() => {
const P = {
  play: 'M6 4l14 8-14 8z',
  pause: 'M7 5h4v14H7zM13 5h4v14h-4z',
  plus: 'M12 5v14M5 12h14',
  minus: 'M5 12h14',
  'chevron-down': 'm6 9 6 6 6-6',
  x: 'M18 6 6 18M6 6l12 12',
  settings: 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z',
  'trending-up': 'm22 7-8.5 8.5-5-5L2 17M16 7h6v6',
  repeat: 'm17 2 4 4-4 4M3 11v-1a4 4 0 0 1 4-4h14M7 22l-4-4 4-4M21 13v1a4 4 0 0 1-4 4H3',
  check: 'M20 6 9 17l-5-5',
  volume: 'M11 5 6 9H2v6h4l5 4zM15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14',
  info: 'M12 16v-4M12 8h.01M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0z',
  'rotate-ccw': 'M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8M3 3v5h5'
};
function Icon({
  name,
  size = 20,
  stroke = 1.75,
  style
}) {
  return /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: name === 'play' || name === 'pause' ? 'currentColor' : 'none',
    stroke: "currentColor",
    strokeWidth: stroke,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    style: {
      display: 'block',
      flex: 'none',
      ...style
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: P[name] || ''
  }));
}
Icon.names = Object.keys(P);
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function IconButton({
  children,
  size = 'md',
  variant = 'secondary',
  label,
  active,
  disabled,
  style,
  ...rest
}) {
  const [h, setH] = React.useState(false);
  const [p, setP] = React.useState(false);
  const dim = {
    sm: 'var(--control-h-sm)',
    md: 'var(--control-h-md)',
    lg: 'var(--control-h-lg)'
  }[size];
  const bg = active ? 'var(--accent-soft)' : variant === 'ghost' ? h ? 'var(--surface-glass)' : 'transparent' : h ? 'var(--surface-glass-strong)' : 'var(--surface-glass)';
  return /*#__PURE__*/React.createElement("button", _extends({
    "aria-label": label,
    title: label,
    disabled: disabled
  }, rest, {
    onMouseEnter: () => setH(true),
    onMouseLeave: () => {
      setH(false);
      setP(false);
    },
    onMouseDown: () => setP(true),
    onMouseUp: () => setP(false),
    style: {
      width: dim,
      height: dim,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      borderRadius: 'var(--radius-pill)',
      border: '1px solid ' + (variant === 'ghost' && !active ? 'transparent' : active ? 'rgba(255,94,69,0.4)' : 'var(--surface-glass-border)'),
      background: bg,
      color: active ? 'var(--accent)' : 'var(--text-primary)',
      cursor: 'pointer',
      transform: p ? 'scale(0.94)' : 'none',
      transition: 'all var(--dur-fast) var(--ease-out)',
      opacity: disabled ? 0.4 : 1,
      outline: 'none',
      ...style
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      width: size === 'sm' ? 16 : 20,
      height: size === 'sm' ? 16 : 20
    }
  }, children));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/core/Dialog.jsx
try { (() => {
function Dialog({
  open,
  onClose,
  title,
  children,
  footer,
  sheet
}) {
  if (!open) return null;
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClose,
    style: {
      position: 'absolute',
      inset: 0,
      zIndex: 50,
      display: 'flex',
      alignItems: sheet ? 'flex-end' : 'center',
      justifyContent: 'center',
      padding: sheet ? 0 : 24,
      background: 'rgba(7,11,24,0.6)',
      backdropFilter: 'blur(8px)',
      animation: 'accel-fade-up var(--dur-base) var(--ease-out)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      width: '100%',
      maxWidth: 420,
      background: 'var(--navy-800)',
      border: '1px solid var(--border-strong)',
      borderRadius: sheet ? 'var(--radius-xl) var(--radius-xl) 0 0' : 'var(--radius-xl)',
      boxShadow: 'var(--shadow-float)',
      padding: 24,
      boxSizing: 'border-box',
      animation: 'accel-fade-up var(--dur-slow) var(--ease-out)'
    }
  }, /*#__PURE__*/React.createElement("header", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      marginBottom: 16
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      margin: 0,
      font: '700 var(--text-h2) var(--font-display)',
      letterSpacing: 'var(--tracking-tight)'
    }
  }, title), /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    label: "Close",
    variant: "ghost",
    size: "sm",
    onClick: onClose
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "x",
    size: 18
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      color: 'var(--text-secondary)',
      fontSize: 15
    }
  }, children), footer && /*#__PURE__*/React.createElement("footer", {
    style: {
      display: 'flex',
      gap: 10,
      justifyContent: 'flex-end',
      marginTop: 24
    }
  }, footer)));
}
Object.assign(__ds_scope, { Dialog });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Dialog.jsx", error: String((e && e.message) || e) }); }

// components/core/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Input({
  label,
  hint,
  unit,
  error,
  style,
  inputStyle,
  ...rest
}) {
  const [f, setF] = React.useState(false);
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '600 var(--text-label) var(--font-body)',
      letterSpacing: 'var(--tracking-label)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)'
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      height: 'var(--control-h-md)',
      padding: '0 14px',
      borderRadius: 'var(--radius-md)',
      background: 'var(--surface-input)',
      border: '1px solid ' + (error ? 'var(--danger)' : f ? 'var(--accent)' : 'var(--surface-glass-border)'),
      boxShadow: f ? 'var(--focus-ring)' : 'none',
      transition: 'all var(--dur-fast) var(--ease-out)'
    }
  }, /*#__PURE__*/React.createElement("input", _extends({}, rest, {
    onFocus: () => setF(true),
    onBlur: () => setF(false),
    style: {
      flex: 1,
      minWidth: 0,
      background: 'transparent',
      border: 0,
      outline: 0,
      color: 'var(--text-primary)',
      font: '500 16px var(--font-body)',
      fontFeatureSettings: 'var(--font-features-tabular)',
      ...inputStyle
    }
  })), unit && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 12px var(--font-mono)',
      color: 'var(--text-muted)',
      letterSpacing: '0.08em'
    }
  }, unit)), (hint || error) && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '12px var(--font-mono)',
      color: error ? 'var(--danger)' : 'var(--text-muted)'
    }
  }, error || hint));
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Input.jsx", error: String((e && e.message) || e) }); }

// components/core/NumberField.jsx
try { (() => {
function NumberField({
  label,
  value,
  onChange,
  min = 1,
  max = 999,
  step = 1,
  unit,
  size = 'md',
  style
}) {
  const big = size === 'lg';
  const h = big ? 'var(--control-h-xl)' : 'var(--control-h-lg)';
  const clamp = v => Math.min(max, Math.max(min, v));
  const Btn = ({
    d,
    children
  }) => {
    const [h2, setH] = React.useState(false);
    const [p, setP] = React.useState(false);
    const dis = d < 0 ? value <= min : value >= max;
    return /*#__PURE__*/React.createElement("button", {
      disabled: dis,
      onClick: () => onChange(clamp(value + d * step)),
      onMouseEnter: () => setH(true),
      onMouseLeave: () => {
        setH(false);
        setP(false);
      },
      onMouseDown: () => setP(true),
      onMouseUp: () => setP(false),
      style: {
        width: big ? 56 : 44,
        alignSelf: 'stretch',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        border: 0,
        background: h ? 'var(--surface-glass-strong)' : 'transparent',
        color: dis ? 'var(--text-muted)' : 'var(--text-primary)',
        cursor: dis ? 'default' : 'pointer',
        transform: p ? 'scale(0.9)' : 'none',
        transition: 'all var(--dur-fast) var(--ease-out)',
        opacity: dis ? 0.4 : 1,
        outline: 'none'
      }
    }, children);
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '600 var(--text-label) var(--font-body)',
      letterSpacing: 'var(--tracking-label)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)'
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'stretch',
      height: h,
      borderRadius: 'var(--radius-md)',
      background: 'var(--surface-input)',
      border: '1px solid var(--surface-glass-border)',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement(Btn, {
    d: -1
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "minus"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      alignItems: 'baseline',
      justifyContent: 'center',
      gap: 6,
      alignSelf: 'center'
    }
  }, /*#__PURE__*/React.createElement("input", {
    type: "number",
    value: value,
    min: min,
    max: max,
    onChange: e => onChange(clamp(Number(e.target.value) || min)),
    style: {
      width: big ? '4ch' : '3.2ch',
      textAlign: 'center',
      background: 'transparent',
      border: 0,
      outline: 0,
      color: 'var(--text-primary)',
      font: (big ? '800 30px' : '700 24px') + ' var(--font-display)',
      letterSpacing: 'var(--tracking-tight)',
      fontFeatureSettings: 'var(--font-features-tabular)',
      MozAppearance: 'textfield'
    }
  }), unit && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 11px var(--font-mono)',
      color: 'var(--text-muted)',
      letterSpacing: '0.1em'
    }
  }, unit)), /*#__PURE__*/React.createElement(Btn, {
    d: 1
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "plus"
  }))));
}
Object.assign(__ds_scope, { NumberField });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/NumberField.jsx", error: String((e && e.message) || e) }); }

// components/core/Segmented.jsx
try { (() => {
function Segmented({
  options,
  value,
  onChange,
  size = 'md',
  label,
  style
}) {
  const i = options.findIndex(o => o.value === value);
  const n = options.length;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '600 var(--text-label) var(--font-body)',
      letterSpacing: 'var(--tracking-label)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)'
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'grid',
      gridTemplateColumns: 'repeat(' + n + ',1fr)',
      padding: 4,
      height: size === 'sm' ? 'var(--control-h-sm)' : 'var(--control-h-md)',
      boxSizing: 'border-box',
      borderRadius: 'var(--radius-md)',
      background: 'var(--surface-input)',
      border: '1px solid var(--surface-glass-border)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 4,
      bottom: 4,
      left: 'calc(4px + ' + 100 / n * Math.max(i, 0) + '% - ' + 8 / n * Math.max(i, 0) + 'px)',
      width: 'calc(' + 100 / n + '% - ' + 8 / n + 'px)',
      borderRadius: 'var(--radius-sm)',
      background: 'var(--surface-glass-strong)',
      border: '1px solid var(--border-strong)',
      boxSizing: 'border-box',
      transition: 'left var(--dur-base) var(--ease-spring)',
      opacity: i < 0 ? 0 : 1
    }
  }), options.map(o => /*#__PURE__*/React.createElement("button", {
    key: o.value,
    onClick: () => onChange(o.value),
    style: {
      position: 'relative',
      zIndex: 1,
      background: 'transparent',
      border: 0,
      color: o.value === value ? 'var(--text-primary)' : 'var(--text-secondary)',
      font: (size === 'sm' ? '600 13px' : '600 14px') + ' var(--font-body)',
      cursor: 'pointer',
      outline: 'none',
      transition: 'color var(--dur-fast)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 6,
      padding: 0
    }
  }, o.icon, o.label))));
}
Object.assign(__ds_scope, { Segmented });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Segmented.jsx", error: String((e && e.message) || e) }); }

// components/core/Select.jsx
try { (() => {
function Select({
  label,
  value,
  options,
  onChange,
  style,
  valueStyle
}) {
  const [open, setOpen] = React.useState(false);
  const cur = options.find(o => o.value === value);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      position: 'relative',
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '600 var(--text-label) var(--font-body)',
      letterSpacing: 'var(--tracking-label)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)'
    }
  }, label), /*#__PURE__*/React.createElement("button", {
    onClick: () => setOpen(!open),
    style: {
      height: 'var(--control-h-md)',
      padding: '0 14px',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: 8,
      borderRadius: 'var(--radius-md)',
      background: 'var(--surface-input)',
      border: '1px solid ' + (open ? 'var(--accent)' : 'var(--surface-glass-border)'),
      color: 'var(--text-primary)',
      font: '500 16px var(--font-body)',
      cursor: 'pointer',
      outline: 'none'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: valueStyle
  }, cur ? cur.label : '—'), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-muted)',
      transform: open ? 'rotate(180deg)' : 'none',
      transition: 'transform var(--dur-base) var(--ease-out)',
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 18
  }))), open && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: '100%',
      left: 0,
      right: 0,
      marginTop: 6,
      zIndex: 20,
      padding: 6,
      borderRadius: 'var(--radius-md)',
      background: 'var(--navy-800)',
      border: '1px solid var(--border-strong)',
      boxShadow: 'var(--shadow-float)',
      animation: 'accel-fade-up var(--dur-base) var(--ease-out)'
    }
  }, options.map(o => /*#__PURE__*/React.createElement("div", {
    key: o.value,
    onClick: () => {
      onChange(o.value);
      setOpen(false);
    },
    style: {
      padding: '10px 12px',
      borderRadius: 'var(--radius-sm)',
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      cursor: 'pointer',
      background: o.value === value ? 'var(--accent-soft)' : 'transparent',
      color: o.value === value ? 'var(--coral-300)' : 'var(--text-primary)',
      font: '500 15px var(--font-body)'
    }
  }, o.label, o.value === value && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "check",
    size: 16
  })))));
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Select.jsx", error: String((e && e.message) || e) }); }

// components/core/Slider.jsx
try { (() => {
function Slider({
  value,
  min = 0,
  max = 100,
  step = 1,
  onChange,
  label,
  format,
  style
}) {
  const pct = (value - min) / (max - min) * 100;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      ...style
    }
  }, (label || format) && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between'
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '600 var(--text-label) var(--font-body)',
      letterSpacing: 'var(--tracking-label)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)'
    }
  }, label), format && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 12px var(--font-mono)',
      color: 'var(--text-secondary)'
    }
  }, format(value))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height: 28,
      display: 'flex',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      height: 6,
      borderRadius: 3,
      background: 'var(--surface-glass-strong)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      width: pct + '%',
      height: 6,
      borderRadius: 3,
      background: 'var(--accent)',
      boxShadow: '0 0 12px var(--accent-glow)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 'calc(' + pct + '% - 12px)',
      width: 24,
      height: 24,
      borderRadius: '50%',
      background: 'var(--ink-100)',
      boxShadow: '0 4px 12px rgba(0,0,0,0.5)',
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement("input", {
    type: "range",
    min: min,
    max: max,
    step: step,
    value: value,
    onChange: e => onChange(Number(e.target.value)),
    style: {
      position: 'absolute',
      inset: 0,
      width: '100%',
      opacity: 0,
      cursor: 'pointer',
      margin: 0
    }
  })));
}
Object.assign(__ds_scope, { Slider });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Slider.jsx", error: String((e && e.message) || e) }); }

// components/core/Switch.jsx
try { (() => {
function Switch({
  checked,
  onChange,
  label,
  description,
  disabled,
  style
}) {
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: 16,
      cursor: disabled ? 'default' : 'pointer',
      opacity: disabled ? 0.4 : 1,
      ...style
    }
  }, (label || description) && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 2
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 16px var(--font-body)',
      color: 'var(--text-primary)'
    }
  }, label), description && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '13px var(--font-body)',
      color: 'var(--text-secondary)'
    }
  }, description)), /*#__PURE__*/React.createElement("span", {
    onClick: () => !disabled && onChange(!checked),
    role: "switch",
    "aria-checked": checked,
    style: {
      position: 'relative',
      width: 52,
      height: 30,
      flex: 'none',
      borderRadius: 'var(--radius-pill)',
      background: checked ? 'var(--accent)' : 'var(--surface-glass-strong)',
      border: '1px solid ' + (checked ? 'transparent' : 'var(--surface-glass-border)'),
      boxShadow: checked ? '0 0 18px var(--accent-glow)' : 'none',
      transition: 'all var(--dur-base) var(--ease-out)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 3,
      left: checked ? 24 : 3,
      width: 22,
      height: 22,
      borderRadius: '50%',
      background: checked ? 'var(--navy-950)' : 'var(--ink-200)',
      transition: 'left var(--dur-base) var(--ease-spring),background var(--dur-base)'
    }
  })));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Switch.jsx", error: String((e && e.message) || e) }); }

// components/core/Toast.jsx
try { (() => {
function Toast({
  children,
  tone = 'neutral',
  icon,
  style
}) {
  const color = {
    neutral: 'var(--text-primary)',
    positive: 'var(--positive)',
    accent: 'var(--accent)',
    info: 'var(--info)'
  }[tone];
  return /*#__PURE__*/React.createElement("div", {
    role: "status",
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 10,
      height: 44,
      padding: '0 16px 0 14px',
      borderRadius: 'var(--radius-pill)',
      background: 'var(--navy-800)',
      border: '1px solid var(--border-strong)',
      boxShadow: 'var(--shadow-float)',
      color: 'var(--text-primary)',
      font: '500 14px var(--font-body)',
      animation: 'accel-fade-up var(--dur-slow) var(--ease-out)',
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color,
      display: 'flex'
    }
  }, icon || /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "info",
    size: 18
  })), children);
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Toast.jsx", error: String((e && e.message) || e) }); }

// components/core/Tooltip.jsx
try { (() => {
function Tooltip({
  label,
  children,
  side = 'top'
}) {
  const [v, setV] = React.useState(false);
  const pos = side === 'bottom' ? {
    top: 'calc(100% + 8px)'
  } : {
    bottom: 'calc(100% + 8px)'
  };
  return /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'relative',
      display: 'inline-flex'
    },
    onMouseEnter: () => setV(true),
    onMouseLeave: () => setV(false)
  }, children, v && /*#__PURE__*/React.createElement("span", {
    role: "tooltip",
    style: {
      position: 'absolute',
      left: '50%',
      transform: 'translateX(-50%)',
      ...pos,
      zIndex: 30,
      whiteSpace: 'nowrap',
      padding: '6px 10px',
      borderRadius: 'var(--radius-sm)',
      background: 'var(--ink-100)',
      color: 'var(--navy-950)',
      font: '500 12px var(--font-body)',
      boxShadow: 'var(--shadow-float)',
      animation: 'accel-fade-up var(--dur-fast) var(--ease-out)'
    }
  }, label));
}
Object.assign(__ds_scope, { Tooltip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Tooltip.jsx", error: String((e && e.message) || e) }); }

// ui_kits/accel-app/MetronomeScreen.jsx
try { (() => {
const {
  Button,
  IconButton,
  Icon,
  NumberField,
  Select,
  Switch,
  Segmented,
  Slider,
  Card,
  Badge,
  Dialog,
  Toast,
  BeatRing,
  AccentGrid
} = window.AccelDesignSystem_faf4ef;
const lbl = {
  font: '600 var(--text-label) var(--font-body)',
  letterSpacing: 'var(--tracking-label)',
  textTransform: 'uppercase',
  color: 'var(--text-muted)'
};
function MetronomeScreen() {
  const [startBpm, setStart] = React.useState(60);
  const [bars, setBars] = React.useState(4);
  const [step, setStep] = React.useState(5);
  const [target, setTarget] = React.useState(120);
  const [useTarget, setUseTarget] = React.useState(true);
  const [rampDown, setRampDown] = React.useState(true);
  const [dynamic, setDynamic] = React.useState(true);
  const [subdiv, setSubdiv] = React.useState(1);
  const [sig, setSig] = React.useState('4/4');
  const [accents, setAccents] = React.useState([0]);
  const [settings, setSettings] = React.useState(false);
  const [vol, setVol] = React.useState(80);
  const m = window.useMetronome({
    startBpm,
    bars,
    step,
    target: useTarget ? target : null,
    rampDown,
    dynamic,
    subdiv,
    sig,
    accents
  });
  const beatsPerBar = Number(sig.split('/')[0]);
  React.useEffect(() => {
    setAccents([0]);
  }, [sig, subdiv]);
  const [toast, setToast] = React.useState(null);
  React.useEffect(() => {
    if (m.done) {
      setToast(rampDown ? 'Back at ' + startBpm + ' BPM' : 'Target reached — ' + target + ' BPM');
      const t = setTimeout(() => setToast(null), 2600);
      return () => clearTimeout(t);
    }
  }, [m.done]);
  const next = m.dir === 'up' ? m.bpm + step : m.bpm - step;
  const stepPct = m.running && dynamic ? (m.bar + ((m.beat ?? 0) % beatsPerBar + 1) / beatsPerBar) / bars * 100 : 0;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: 390,
      height: 844,
      margin: '0 auto',
      overflow: 'hidden',
      background: 'var(--bg)',
      fontFamily: 'var(--font-body)',
      color: 'var(--text-primary)',
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: -120,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 520,
      height: 520,
      borderRadius: '50%',
      background: 'radial-gradient(circle,' + (m.dir === 'down' ? 'rgba(111,180,255,0.22)' : 'rgba(255,94,69,0.28)') + ' 0%,transparent 62%)',
      opacity: m.running ? 1 : 0.5,
      transition: 'opacity 600ms, background 600ms',
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement("header", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '56px 20px 0',
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '800 22px var(--font-display)',
      letterSpacing: '-0.05em'
    }
  }, "Accel"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      alignItems: 'center'
    }
  }, dynamic && /*#__PURE__*/React.createElement(Badge, {
    tone: m.dir === 'down' ? 'info' : 'accent',
    dot: m.running
  }, m.running ? (m.dir === 'up' ? '+' : '−') + step + ' → ' + next : 'dynamic'), /*#__PURE__*/React.createElement(IconButton, {
    label: "Settings",
    variant: "ghost",
    onClick: () => setSettings(true)
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "settings"
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: 'auto',
      scrollbarWidth: 'none',
      padding: '16px 20px 120px',
      display: 'flex',
      flexDirection: 'column',
      gap: 16,
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center',
      padding: '12px 0 8px'
    }
  }, /*#__PURE__*/React.createElement(BeatRing, {
    beat: m.beat,
    beatsPerBar: beatsPerBar,
    accent: m.beat != null && accents.includes(m.beat % beatsPerBar * subdiv),
    direction: m.dir,
    size: 250
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 2
    }
  }, /*#__PURE__*/React.createElement("span", {
    key: m.bpm,
    style: {
      font: '800 96px/0.9 var(--font-display)',
      letterSpacing: 'var(--tracking-display)',
      fontFeatureSettings: 'var(--font-features-tabular)',
      animation: 'accel-fade-up var(--dur-slow) var(--ease-spring)'
    }
  }, m.bpm), /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 11px var(--font-mono)',
      letterSpacing: 'var(--tracking-label)',
      color: 'var(--text-muted)'
    }
  }, "BPM"), m.running && dynamic && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 12px var(--font-mono)',
      color: 'var(--text-secondary)',
      marginTop: 6
    }
  }, "bar ", Math.min(m.bar + 1, bars), " / ", bars)))), dynamic && /*#__PURE__*/React.createElement("div", {
    style: {
      height: 3,
      borderRadius: 2,
      background: 'var(--surface-glass-strong)',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      width: stepPct + '%',
      background: m.dir === 'down' ? 'var(--info)' : 'var(--accent)',
      transition: 'width 200ms linear'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Select, {
    label: "Time signature",
    value: sig,
    onChange: setSig,
    valueStyle: {
      fontSize: 24
    },
    options: ['2/4', '3/4', '4/4', '5/4', '6/8', '7/8', '12/8'].map(v => ({
      value: v,
      label: v
    }))
  }), /*#__PURE__*/React.createElement(Segmented, {
    label: "Subdivision",
    value: subdiv,
    onChange: setSubdiv,
    options: [{
      value: 1,
      label: '♩'
    }, {
      value: 2,
      label: '♪♪'
    }, {
      value: 3,
      label: '♪³'
    }, {
      value: 4,
      label: '♬♬'
    }]
  })), /*#__PURE__*/React.createElement(AccentGrid, {
    label: "Accents",
    beats: beatsPerBar,
    subdiv: subdiv,
    accents: accents,
    onChange: setAccents,
    current: m.slot
  }), /*#__PURE__*/React.createElement(Card, {
    title: "Dynamic mode",
    glow: dynamic && m.running,
    action: /*#__PURE__*/React.createElement(Switch, {
      checked: dynamic,
      onChange: setDynamic
    })
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 14,
      opacity: dynamic ? 1 : 0.45,
      transition: 'opacity var(--dur-base)'
    }
  }, /*#__PURE__*/React.createElement(NumberField, {
    label: "Start tempo",
    unit: "BPM",
    value: startBpm,
    min: 20,
    max: 300,
    size: "lg",
    onChange: setStart
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(NumberField, {
    label: "Bar count",
    value: bars,
    min: 1,
    max: 64,
    onChange: setBars
  }), /*#__PURE__*/React.createElement(NumberField, {
    label: "Increase by BPM",
    value: step,
    min: 1,
    max: 50,
    onChange: setStep
  })), /*#__PURE__*/React.createElement(Switch, {
    label: "Stop at target",
    checked: useTarget,
    onChange: setUseTarget
  }), useTarget && /*#__PURE__*/React.createElement(NumberField, {
    label: "Target tempo",
    unit: "BPM",
    value: target,
    min: startBpm + step,
    max: 400,
    step: 5,
    onChange: setTarget
  }), /*#__PURE__*/React.createElement(Switch, {
    label: "Ramp back down",
    checked: rampDown,
    onChange: setRampDown,
    disabled: !useTarget
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      padding: '16px 20px 32px',
      background: 'linear-gradient(180deg,transparent,var(--bg) 40%)',
      display: 'flex',
      gap: 10,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    label: "Reset",
    size: "lg",
    onClick: m.stop,
    disabled: !m.running
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "rotate-ccw"
  })), /*#__PURE__*/React.createElement(Button, {
    size: "xl",
    fullWidth: true,
    glow: !m.running,
    variant: m.running ? 'secondary' : 'primary',
    icon: /*#__PURE__*/React.createElement(Icon, {
      name: m.running ? 'pause' : 'play',
      size: 22
    }),
    onClick: m.toggle
  }, m.running ? 'Stop' : 'Start')), toast && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 110,
      left: 0,
      right: 0,
      display: 'flex',
      justifyContent: 'center',
      pointerEvents: 'none'
    }
  }, /*#__PURE__*/React.createElement(Toast, {
    tone: "positive",
    icon: /*#__PURE__*/React.createElement(Icon, {
      name: "check",
      size: 18
    })
  }, toast)), /*#__PURE__*/React.createElement(Dialog, {
    open: settings,
    onClose: () => setSettings(false),
    title: "Settings",
    sheet: true,
    footer: /*#__PURE__*/React.createElement(Button, {
      onClick: () => setSettings(false)
    }, "Done")
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 18
    }
  }, /*#__PURE__*/React.createElement(Slider, {
    label: "Volume",
    value: vol,
    format: v => v + '%',
    onChange: setVol
  }), /*#__PURE__*/React.createElement(Switch, {
    label: "Haptics",
    checked: false,
    onChange: () => {}
  }))));
}
window.MetronomeScreen = MetronomeScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/accel-app/MetronomeScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/accel-app/useMetronome.js
try { (() => {
// Scheduler + dynamic ramp logic. window.useMetronome
window.useMetronome = function useMetronome(cfg) {
  const [running, setRunning] = React.useState(false);
  const [bpm, setBpm] = React.useState(cfg.startBpm);
  const [beat, setBeat] = React.useState(null); // absolute beat count
  const [bar, setBar] = React.useState(0); // bars completed in current step
  const [dir, setDir] = React.useState('up');
  const [done, setDone] = React.useState(false);
  const st = React.useRef({});
  const ctx = React.useRef(null);
  const cfgRef = React.useRef(cfg);
  cfgRef.current = cfg;
  const [slot, setSlot] = React.useState(null);
  React.useEffect(() => {
    if (!running) setBpm(cfg.startBpm);
  }, [cfg.startBpm, running]);
  const click = (t, accent, sub) => {
    const c = ctx.current;
    const o = c.createOscillator();
    const g = c.createGain();
    o.frequency.value = accent ? 1600 : sub ? 700 : 1000;
    g.gain.setValueAtTime(sub ? 0.12 : accent ? 0.5 : 0.3, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.05);
    o.connect(g).connect(c.destination);
    o.start(t);
    o.stop(t + 0.06);
  };
  const start = () => {
    if (!ctx.current) ctx.current = new (window.AudioContext || window.webkitAudioContext)();
    ctx.current.resume();
    const s = st.current;
    s.bpm = cfg.startBpm;
    s.beatInBar = 0;
    s.bar = 0;
    s.dir = 'up';
    s.beatIdx = 0;
    s.subIdx = 0;
    s.next = ctx.current.currentTime + 0.1;
    s.done = false;
    setBpm(cfg.startBpm);
    setBar(0);
    setDir('up');
    setDone(false);
    setRunning(true);
    const [num] = cfg.sig.split('/').map(Number);
    s.timer = setInterval(() => {
      const c = ctx.current;
      while (s.next < c.currentTime + 0.12) {
        const isMain = s.subIdx === 0;
        const sl = s.beatInBar * cfg.subdiv + s.subIdx;
        const acc = (cfgRef.current.accents || []).includes(sl);
        click(s.next, acc, !isMain && !acc);
        setSlot(sl);
        if (isMain) {
          const idx = s.beatIdx;
          setBeat(idx);
          // after each main beat, advance
          s.beatIdx++;
          s.beatInBar++;
          if (s.beatInBar >= num) {
            s.beatInBar = 0;
            s.bar++;
            if (cfg.dynamic && s.bar >= cfg.bars) {
              s.bar = 0;
              let nb = s.dir === 'up' ? s.bpm + cfg.step : s.bpm - cfg.step;
              if (s.dir === 'up' && cfg.target && nb >= cfg.target) {
                nb = cfg.target;
                if (cfg.rampDown) s.dir = 'down';else {
                  s.done = true;
                  setDone(true);
                }
              }
              if (s.dir === 'down' && nb <= cfg.startBpm) {
                nb = cfg.startBpm;
                s.done = true;
                setDone(true);
              }
              s.bpm = nb;
              setBpm(nb);
              setDir(s.dir);
            }
            setBar(s.bar);
          }
        }
        s.subIdx = (s.subIdx + 1) % cfg.subdiv;
        s.next += 60 / s.bpm / cfg.subdiv;
      }
    }, 25);
  };
  const stop = () => {
    clearInterval(st.current.timer);
    setRunning(false);
    setBeat(null);
    setSlot(null);
    setBar(0);
  };
  React.useEffect(() => () => clearInterval(st.current.timer), []);
  return {
    running,
    bpm,
    beat,
    slot,
    bar,
    dir,
    done,
    start,
    stop,
    toggle: () => running ? stop() : start()
  };
};
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/accel-app/useMetronome.js", error: String((e && e.message) || e) }); }

__ds_ns.AccentGrid = __ds_scope.AccentGrid;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.BeatRing = __ds_scope.BeatRing;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Dialog = __ds_scope.Dialog;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.NumberField = __ds_scope.NumberField;

__ds_ns.Segmented = __ds_scope.Segmented;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Slider = __ds_scope.Slider;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.Tooltip = __ds_scope.Tooltip;

})();
