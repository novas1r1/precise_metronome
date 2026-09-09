import React from 'react';
import {Icon} from './Icon.jsx';
export function Select({label,value,options,onChange,style,valueStyle}){
const [open,setOpen]=React.useState(false);const cur=options.find(o=>o.value===value);
return <div style={{display:'flex',flexDirection:'column',gap:8,position:'relative',...style}}>
{label&&<span style={{font:'600 var(--text-label) var(--font-body)',letterSpacing:'var(--tracking-label)',textTransform:'uppercase',color:'var(--text-muted)'}}>{label}</span>}
<button onClick={()=>setOpen(!open)} style={{height:'var(--control-h-md)',padding:'0 14px',display:'flex',alignItems:'center',justifyContent:'space-between',gap:8,borderRadius:'var(--radius-md)',background:'var(--surface-input)',border:'1px solid '+(open?'var(--accent)':'var(--surface-glass-border)'),color:'var(--text-primary)',font:'500 16px var(--font-body)',cursor:'pointer',outline:'none'}}>
<span style={valueStyle}>{cur?cur.label:'—'}</span><span style={{color:'var(--text-muted)',transform:open?'rotate(180deg)':'none',transition:'transform var(--dur-base) var(--ease-out)',display:'flex'}}><Icon name="chevron-down" size={18}/></span></button>
{open&&<div style={{position:'absolute',top:'100%',left:0,right:0,marginTop:6,zIndex:20,padding:6,borderRadius:'var(--radius-md)',background:'var(--navy-800)',border:'1px solid var(--border-strong)',boxShadow:'var(--shadow-float)',animation:'accel-fade-up var(--dur-base) var(--ease-out)'}}>
{options.map(o=><div key={o.value} onClick={()=>{onChange(o.value);setOpen(false)}} style={{padding:'10px 12px',borderRadius:'var(--radius-sm)',display:'flex',justifyContent:'space-between',alignItems:'center',cursor:'pointer',background:o.value===value?'var(--accent-soft)':'transparent',color:o.value===value?'var(--coral-300)':'var(--text-primary)',font:'500 15px var(--font-body)'}}>{o.label}{o.value===value&&<Icon name="check" size={16}/>}</div>)}</div>}</div>;}
