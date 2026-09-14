One slot per beat × subdivision in the current bar; tap slots to set 0, 1 or n accents (coral, glowing). Main beats are slightly brighter than subdivision slots.

```jsx
<AccentGrid label="Accents" beats={4} subdiv={2} accents={[0,4]} onChange={setAccents} current={liveSlot}/>
```

`current` highlights the slot currently playing. Reset accents to `[0]` when beats or subdiv change.
