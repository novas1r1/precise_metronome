import React from 'react';
export function IconButton({children,size='md',variant='secondary',label,active,disabled,style,...rest}){
const [h,setH]=React.useState(false);const [p,setP]=React.useState(false);
const dim={sm:'var(--control-h-sm)',md:'var(--control-h-md)',lg:'var(--control-h-lg)'}[size];
const bg=active?'var(--accent-soft)':variant==='ghost'?(h?'var(--surface-glass)':'transparent'):(h?'var(--surface-glass-strong)':'var(--surface-glass)');
return <button aria-label={label} title={label} disabled={disabled} {...rest} onMouseEnter={()=>setH(true)} onMouseLeave={()=>{setH(false);setP(false)}} onMouseDown={()=>setP(true)} onMouseUp={()=>setP(false)}
style={{width:dim,height:dim,display:'inline-flex',alignItems:'center',justifyContent:'center',borderRadius:'var(--radius-pill)',border:'1px solid '+(variant==='ghost'&&!active?'transparent':active?'rgba(255,94,69,0.4)':'var(--surface-glass-border)'),background:bg,color:active?'var(--accent)':'var(--text-primary)',cursor:'pointer',transform:p?'scale(0.94)':'none',transition:'all var(--dur-fast) var(--ease-out)',opacity:disabled?0.4:1,outline:'none',...style}}>
<span style={{display:'inline-flex',width:size==='sm'?16:20,height:size==='sm'?16:20}}>{children}</span></button>;}
