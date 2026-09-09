import React from 'react';
import {IconButton} from './IconButton.jsx';
import {Icon} from './Icon.jsx';
export function Dialog({open,onClose,title,children,footer,sheet}){
if(!open)return null;
return <div onClick={onClose} style={{position:'absolute',inset:0,zIndex:50,display:'flex',alignItems:sheet?'flex-end':'center',justifyContent:'center',padding:sheet?0:24,background:'rgba(7,11,24,0.6)',backdropFilter:'blur(8px)',animation:'accel-fade-up var(--dur-base) var(--ease-out)'}}>
<div onClick={e=>e.stopPropagation()} style={{width:'100%',maxWidth:420,background:'var(--navy-800)',border:'1px solid var(--border-strong)',borderRadius:sheet?'var(--radius-xl) var(--radius-xl) 0 0':'var(--radius-xl)',boxShadow:'var(--shadow-float)',padding:24,boxSizing:'border-box',animation:'accel-fade-up var(--dur-slow) var(--ease-out)'}}>
<header style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:16}}><h2 style={{margin:0,font:'700 var(--text-h2) var(--font-display)',letterSpacing:'var(--tracking-tight)'}}>{title}</h2><IconButton label="Close" variant="ghost" size="sm" onClick={onClose}><Icon name="x" size={18}/></IconButton></header>
<div style={{color:'var(--text-secondary)',fontSize:15}}>{children}</div>
{footer&&<footer style={{display:'flex',gap:10,justifyContent:'flex-end',marginTop:24}}>{footer}</footer>}</div></div>;}
