import React from 'react';
export function Card({children,title,action,solid,padding=20,glow,style}){
return <section style={{position:'relative',borderRadius:'var(--radius-lg)',background:solid?'var(--surface-card)':'var(--surface-glass)',border:'1px solid var(--surface-glass-border)',backdropFilter:solid?undefined:'var(--blur-glass)',WebkitBackdropFilter:solid?undefined:'var(--blur-glass)',boxShadow:glow?'var(--shadow-glass), 0 0 60px -20px var(--accent-glow)':'var(--shadow-glass)',padding,boxSizing:'border-box',...style}}>
{(title||action)&&<header style={{display:'flex',alignItems:'center',justifyContent:'space-between',gap:12,marginBottom:16}}><h3 style={{margin:0,font:'600 var(--text-h3) var(--font-display)',letterSpacing:'var(--tracking-tight)'}}>{title}</h3>{action}</header>}
{children}</section>;}
