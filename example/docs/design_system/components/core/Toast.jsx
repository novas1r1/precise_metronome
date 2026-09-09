import React from 'react';
import {Icon} from './Icon.jsx';
export function Toast({children,tone='neutral',icon,style}){
const color={neutral:'var(--text-primary)',positive:'var(--positive)',accent:'var(--accent)',info:'var(--info)'}[tone];
return <div role="status" style={{display:'inline-flex',alignItems:'center',gap:10,height:44,padding:'0 16px 0 14px',borderRadius:'var(--radius-pill)',background:'var(--navy-800)',border:'1px solid var(--border-strong)',boxShadow:'var(--shadow-float)',color:'var(--text-primary)',font:'500 14px var(--font-body)',animation:'accel-fade-up var(--dur-slow) var(--ease-out)',...style}}>
<span style={{color,display:'flex'}}>{icon||<Icon name="info" size={18}/>}</span>{children}</div>;}
