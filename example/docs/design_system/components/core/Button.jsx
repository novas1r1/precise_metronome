import React from 'react';
const base={display:'inline-flex',alignItems:'center',justifyContent:'center',gap:8,border:'1px solid transparent',borderRadius:'var(--radius-pill)',fontFamily:'var(--font-body)',fontWeight:600,letterSpacing:'-0.01em',cursor:'pointer',transition:'background var(--dur-fast) var(--ease-out),transform var(--dur-fast) var(--ease-out),box-shadow var(--dur-base) var(--ease-out)',whiteSpace:'nowrap',outline:'none'};
const sizes={sm:{height:'var(--control-h-sm)',padding:'0 14px',fontSize:14},md:{height:'var(--control-h-md)',padding:'0 20px',fontSize:15},lg:{height:'var(--control-h-lg)',padding:'0 28px',fontSize:17},xl:{height:'var(--control-h-xl)',padding:'0 40px',fontSize:20}};
const variants={
primary:{bg:'var(--accent)',hover:'var(--accent-hover)',press:'var(--accent-press)',color:'var(--text-on-accent)',shadow:'var(--shadow-accent-glow)'},
secondary:{bg:'var(--surface-glass)',hover:'var(--surface-glass-strong)',press:'var(--surface-glass)',color:'var(--text-primary)',border:'var(--surface-glass-border)'},
ghost:{bg:'transparent',hover:'var(--surface-glass)',press:'var(--surface-glass-strong)',color:'var(--text-secondary)'},
danger:{bg:'var(--accent-soft)',hover:'rgba(255,94,69,0.26)',press:'var(--accent-soft)',color:'var(--coral-300)'}};
export function Button({variant='primary',size='md',children,icon,disabled,glow,fullWidth,style,...rest}){
const [s,setS]=React.useState('idle');const v=variants[variant];
const bg=s==='press'?v.press:s==='hover'?v.hover:v.bg;
return <button disabled={disabled} {...rest} onMouseEnter={()=>setS('hover')} onMouseLeave={()=>setS('idle')} onMouseDown={()=>setS('press')} onMouseUp={()=>setS('hover')}
style={{...base,...sizes[size],background:bg,color:v.color,borderColor:v.border||'transparent',boxShadow:glow&&variant==='primary'?v.shadow:'none',transform:s==='press'?'scale(0.97)':'none',opacity:disabled?0.4:1,pointerEvents:disabled?'none':'auto',width:fullWidth?'100%':undefined,...style}}>
{icon&&<span style={{display:'inline-flex',width:size==='sm'?16:20,height:size==='sm'?16:20}}>{icon}</span>}{children}</button>;}
