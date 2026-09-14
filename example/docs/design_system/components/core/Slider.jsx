import React from 'react';
export function Slider({value,min=0,max=100,step=1,onChange,label,format,style}){
const pct=(value-min)/(max-min)*100;
return <div style={{display:'flex',flexDirection:'column',gap:10,...style}}>
{(label||format)&&<div style={{display:'flex',justifyContent:'space-between'}}>{label&&<span style={{font:'600 var(--text-label) var(--font-body)',letterSpacing:'var(--tracking-label)',textTransform:'uppercase',color:'var(--text-muted)'}}>{label}</span>}{format&&<span style={{font:'500 12px var(--font-mono)',color:'var(--text-secondary)'}}>{format(value)}</span>}</div>}
<div style={{position:'relative',height:28,display:'flex',alignItems:'center'}}>
<div style={{position:'absolute',left:0,right:0,height:6,borderRadius:3,background:'var(--surface-glass-strong)'}}/><div style={{position:'absolute',left:0,width:pct+'%',height:6,borderRadius:3,background:'var(--accent)',boxShadow:'0 0 12px var(--accent-glow)'}}/>
<div style={{position:'absolute',left:'calc('+pct+'% - 12px)',width:24,height:24,borderRadius:'50%',background:'var(--ink-100)',boxShadow:'0 4px 12px rgba(0,0,0,0.5)',pointerEvents:'none'}}/>
<input type="range" min={min} max={max} step={step} value={value} onChange={e=>onChange(Number(e.target.value))} style={{position:'absolute',inset:0,width:'100%',opacity:0,cursor:'pointer',margin:0}}/></div></div>;}
