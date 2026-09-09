The beat visualiser: a glass dial that fires an expanding ring each beat and shows bar-position dots around the rim. Put the BPM number in children.

```jsx
<BeatRing beat={beat} beatsPerBar={4} accent={beat%4===0} direction="up"><span>120</span></BeatRing>
```

Increment `beat` every tick; `direction="down"` switches glow to sky blue during the descending ramp.
