import React from 'react';
export function Segmented({options,value,onChange,size='md',label,style}){
const i=options.findIndex(o=>o.value===value);const n=options.length;
return <div style={{display:'flex',flexDirection:'column',gap:8,...style}}>
{label&&<span style={{font:'600 var(--text-label) var(--font-body)',letterSpacing:'var(--tracking-label)',textTransform:'uppercase',color:'var(--text-muted)'}}>{label}</span>}
<div style={{position:'relative',display:'grid',gridTemplateColumns:'repeat('+n+',1fr)',padding:4,height:size==='sm'?'var(--control-h-sm)':'var(--control-h-md)',boxSizing:'border-box',borderRadius:'var(--radius-md)',background:'var(--surface-input)',border:'1px solid var(--surface-glass-border)'}}>
<span style={{position:'absolute',top:4,bottom:4,left:'calc(4px + '+(100/n*Math.max(i,0))+'% - '+(8/n*Math.max(i,0))+'px)',width:'calc('+(100/n)+'% - '+(8/n)+'px)',borderRadius:'var(--radius-sm)',background:'var(--surface-glass-strong)',border:'1px solid var(--border-strong)',boxSizing:'border-box',transition:'left var(--dur-base) var(--ease-spring)',opacity:i<0?0:1}}/>
{options.map(o=><button key={o.value} onClick={()=>onChange(o.value)} style={{position:'relative',zIndex:1,background:'transparent',border:0,color:o.value===value?'var(--text-primary)':'var(--text-secondary)',font:(size==='sm'?'600 13px':'600 14px')+' var(--font-body)',cursor:'pointer',outline:'none',transition:'color var(--dur-fast)',display:'flex',alignItems:'center',justifyContent:'center',gap:6,padding:0}}>{o.icon}{o.label}</button>)}</div></div>;}
