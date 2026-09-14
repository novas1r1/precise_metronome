Pill-shaped action button; use primary (coral) for the single main action on a screen, secondary (glass) for the rest, ghost for tertiary.

```jsx
<Button variant="primary" size="lg" glow>Start</Button>
<Button variant="secondary" icon={<Icon name="settings"/>}>Settings</Button>
```

Props: variant primary|secondary|ghost|danger; size sm|md|lg|xl; `glow` adds the coral glow (transport only); `fullWidth`.
