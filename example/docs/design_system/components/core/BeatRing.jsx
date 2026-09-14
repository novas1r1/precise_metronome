import React from 'react';
export function BeatRing({beat,beatsPerBar=4,accent,size=280,direction='up',children,style}){
const color=direction==='down'?'var(--beat-down)':'var(--beat-up)';
return <div style={{position:'relative',width:size,height:size,flex:'none',...style}}>
<div style={{position:'absolute',inset:'-30%',borderRadius:'50%',background:'radial-gradient(circle,'+(direction==='down'?'rgba(111,180,255,0.35)':'var(--accent-glow)')+' 0%,transparent 60%)',opacity:accent?1:0.55,transition:'opacity 150ms',pointerEvents:'none'}}/>
{beat!=null&&<div key={beat} style={{position:'absolute',inset:0,borderRadius:'50%',border:'2px solid '+(accent?'var(--beat-accent)':color),animation:'accel-beat 520ms var(--ease-out) forwards'}}/>}
<div key={'p'+beat} style={{position:'absolute',inset:0,borderRadius:'50%',background:'var(--surface-glass)',border:'1px solid var(--surface-glass-border)',backdropFilter:'var(--blur-glass)',boxShadow:'var(--shadow-glass)',display:'flex',alignItems:'center',justifyContent:'center',animation:beat!=null?'accel-pulse 300ms var(--ease-out)':'none'}}>{children}</div>
<svg viewBox="0 0 100 100" style={{position:'absolute',inset:-14,width:'calc(100% + 28px)',height:'calc(100% + 28px)',pointerEvents:'none'}}>{Array.from({length:beatsPerBar}).map((_,i)=>{const a=-Math.PI/2+i/beatsPerBar*2*Math.PI;const on=beat!=null&&(beat%beatsPerBar)===i;return <circle key={i} cx={50+46*Math.cos(a)} cy={50+46*Math.sin(a)} r={on?2.6:1.5} fill={on?(i===0?'var(--beat-accent)':color):'var(--ink-400)'} style={{transition:'all 120ms'}}/>})}</svg></div>;}
