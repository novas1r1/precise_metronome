import React from 'react';
export function AccentGrid({beats=4,subdiv=1,accents=[],onChange,label,current,style}){
const n=beats*subdiv;
const toggle=i=>{const s=new Set(accents);s.has(i)?s.delete(i):s.add(i);onChange([...s].sort((a,b)=>a-b))};
return <div style={{display:'flex',flexDirection:'column',gap:8,...style}}>
{label&&<div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline'}}><span style={{font:'600 var(--text-label) var(--font-body)',letterSpacing:'var(--tracking-label)',textTransform:'uppercase',color:'var(--text-muted)'}}>{label}</span><span style={{font:'500 12px var(--font-mono)',color:'var(--text-muted)'}}>{accents.length===0?'none':accents.length}</span></div>}
<div style={{display:'grid',gridTemplateColumns:'repeat('+n+',1fr)',gap:subdiv>1?4:6,padding:6,borderRadius:'var(--radius-md)',background:'var(--surface-input)',border:'1px solid var(--surface-glass-border)',boxSizing:'border-box'}}>
{Array.from({length:n}).map((_,i)=>{const on=accents.includes(i);const main=i%subdiv===0;const live=current===i;
return <button key={i} onClick={()=>toggle(i)} aria-pressed={on} title={main?'Beat '+(i/subdiv+1):'Subdivision'} style={{height:44,minWidth:0,padding:0,border:0,borderRadius:'var(--radius-sm)',background:on?'var(--accent)':main?'var(--surface-glass-strong)':'var(--surface-glass)',boxShadow:on?'0 0 16px var(--accent-glow)':'none',cursor:'pointer',outline:'none',display:'flex',alignItems:'center',justifyContent:'center',transform:live?'scale(0.9)':'none',transition:'all var(--dur-fast) var(--ease-out)'}}>
<span style={{width:on?8:main?6:4,height:on?8:main?6:4,borderRadius:'50%',background:on?'var(--navy-950)':live?'var(--text-primary)':'var(--ink-400)',transition:'all var(--dur-fast)'}}/></button>})}</div></div>;}
