import React from 'react';
export function Tooltip({label,children,side='top'}){
const [v,setV]=React.useState(false);
const pos=side==='bottom'?{top:'calc(100% + 8px)'}:{bottom:'calc(100% + 8px)'};
return <span style={{position:'relative',display:'inline-flex'}} onMouseEnter={()=>setV(true)} onMouseLeave={()=>setV(false)}>{children}
{v&&<span role="tooltip" style={{position:'absolute',left:'50%',transform:'translateX(-50%)',...pos,zIndex:30,whiteSpace:'nowrap',padding:'6px 10px',borderRadius:'var(--radius-sm)',background:'var(--ink-100)',color:'var(--navy-950)',font:'500 12px var(--font-body)',boxShadow:'var(--shadow-float)',animation:'accel-fade-up var(--dur-fast) var(--ease-out)'}}>{label}</span>}</span>;}
