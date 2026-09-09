import React from 'react';
import {Icon} from './Icon.jsx';
export function NumberField({label,value,onChange,min=1,max=999,step=1,unit,size='md',style}){
const big=size==='lg';const h=big?'var(--control-h-xl)':'var(--control-h-lg)';
const clamp=v=>Math.min(max,Math.max(min,v));
const Btn=({d,children})=>{const [h2,setH]=React.useState(false);const [p,setP]=React.useState(false);const dis=d<0?value<=min:value>=max;
return <button disabled={dis} onClick={()=>onChange(clamp(value+d*step))} onMouseEnter={()=>setH(true)} onMouseLeave={()=>{setH(false);setP(false)}} onMouseDown={()=>setP(true)} onMouseUp={()=>setP(false)} style={{width:big?56:44,alignSelf:'stretch',display:'flex',alignItems:'center',justifyContent:'center',border:0,background:h?'var(--surface-glass-strong)':'transparent',color:dis?'var(--text-muted)':'var(--text-primary)',cursor:dis?'default':'pointer',transform:p?'scale(0.9)':'none',transition:'all var(--dur-fast) var(--ease-out)',opacity:dis?0.4:1,outline:'none'}}>{children}</button>};
return <div style={{display:'flex',flexDirection:'column',gap:8,...style}}>
{label&&<span style={{font:'600 var(--text-label) var(--font-body)',letterSpacing:'var(--tracking-label)',textTransform:'uppercase',color:'var(--text-muted)'}}>{label}</span>}
<div style={{display:'flex',alignItems:'stretch',height:h,borderRadius:'var(--radius-md)',background:'var(--surface-input)',border:'1px solid var(--surface-glass-border)',overflow:'hidden'}}>
<Btn d={-1}><Icon name="minus"/></Btn>
<div style={{flex:1,display:'flex',alignItems:'baseline',justifyContent:'center',gap:6,alignSelf:'center'}}>
<input type="number" value={value} min={min} max={max} onChange={e=>onChange(clamp(Number(e.target.value)||min))} style={{width:big?'4ch':'3.2ch',textAlign:'center',background:'transparent',border:0,outline:0,color:'var(--text-primary)',font:(big?'800 30px':'700 24px')+' var(--font-display)',letterSpacing:'var(--tracking-tight)',fontFeatureSettings:'var(--font-features-tabular)',MozAppearance:'textfield'}}/>
{unit&&<span style={{font:'500 11px var(--font-mono)',color:'var(--text-muted)',letterSpacing:'0.1em'}}>{unit}</span>}</div>
<Btn d={1}><Icon name="plus"/></Btn></div></div>;}
