import React from 'react';
export function Input({label,hint,unit,error,style,inputStyle,...rest}){
const [f,setF]=React.useState(false);
return <label style={{display:'flex',flexDirection:'column',gap:8,...style}}>
{label&&<span style={{font:'600 var(--text-label) var(--font-body)',letterSpacing:'var(--tracking-label)',textTransform:'uppercase',color:'var(--text-muted)'}}>{label}</span>}
<span style={{display:'flex',alignItems:'center',height:'var(--control-h-md)',padding:'0 14px',borderRadius:'var(--radius-md)',background:'var(--surface-input)',border:'1px solid '+(error?'var(--danger)':f?'var(--accent)':'var(--surface-glass-border)'),boxShadow:f?'var(--focus-ring)':'none',transition:'all var(--dur-fast) var(--ease-out)'}}>
<input {...rest} onFocus={()=>setF(true)} onBlur={()=>setF(false)} style={{flex:1,minWidth:0,background:'transparent',border:0,outline:0,color:'var(--text-primary)',font:'500 16px var(--font-body)',fontFeatureSettings:'var(--font-features-tabular)',...inputStyle}}/>
{unit&&<span style={{font:'500 12px var(--font-mono)',color:'var(--text-muted)',letterSpacing:'0.08em'}}>{unit}</span>}</span>
{(hint||error)&&<span style={{font:'12px var(--font-mono)',color:error?'var(--danger)':'var(--text-muted)'}}>{error||hint}</span>}</label>;}
