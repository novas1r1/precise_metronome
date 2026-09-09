import React from 'react';
const tones={neutral:['var(--surface-glass-strong)','var(--text-secondary)'],accent:['var(--accent-soft)','var(--coral-300)'],positive:['var(--positive-soft)','var(--positive)'],warning:['var(--warning-soft)','var(--warning)'],info:['var(--info-soft)','var(--info)']};
export function Badge({children,tone='neutral',mono=true,dot,style}){const [bg,fg]=tones[tone];
return <span style={{display:'inline-flex',alignItems:'center',gap:6,height:24,padding:'0 10px',borderRadius:'var(--radius-pill)',background:bg,color:fg,font:(mono?'500 12px var(--font-mono)':'600 12px var(--font-body)'),whiteSpace:'nowrap',...style}}>{dot&&<span style={{width:6,height:6,borderRadius:'50%',background:fg,boxShadow:'0 0 8px '+fg}}/>}{children}</span>;}
