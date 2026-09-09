const {Button,IconButton,Icon,NumberField,Select,Switch,Segmented,Slider,Card,Badge,Dialog,Toast,BeatRing,AccentGrid}=window.AccelDesignSystem_faf4ef;
const lbl={font:'600 var(--text-label) var(--font-body)',letterSpacing:'var(--tracking-label)',textTransform:'uppercase',color:'var(--text-muted)'};
function MetronomeScreen(){
const [startBpm,setStart]=React.useState(60);const [bars,setBars]=React.useState(4);const [step,setStep]=React.useState(5);
const [target,setTarget]=React.useState(120);const [useTarget,setUseTarget]=React.useState(true);const [rampDown,setRampDown]=React.useState(true);
const [dynamic,setDynamic]=React.useState(true);const [subdiv,setSubdiv]=React.useState(1);const [sig,setSig]=React.useState('4/4');
const [accents,setAccents]=React.useState([0]);
const [settings,setSettings]=React.useState(false);const [vol,setVol]=React.useState(80);
const m=window.useMetronome({startBpm,bars,step,target:useTarget?target:null,rampDown,dynamic,subdiv,sig,accents});
const beatsPerBar=Number(sig.split('/')[0]);
React.useEffect(()=>{setAccents([0])},[sig,subdiv]);
const [toast,setToast]=React.useState(null);
React.useEffect(()=>{if(m.done){setToast(rampDown?'Back at '+startBpm+' BPM':'Target reached — '+target+' BPM');const t=setTimeout(()=>setToast(null),2600);return()=>clearTimeout(t)}},[m.done]);
const next=m.dir==='up'?m.bpm+step:m.bpm-step;
const stepPct=m.running&&dynamic?((m.bar+((m.beat??0)%beatsPerBar+1)/beatsPerBar)/bars)*100:0;
return <div style={{position:'relative',width:390,height:844,margin:'0 auto',overflow:'hidden',background:'var(--bg)',fontFamily:'var(--font-body)',color:'var(--text-primary)',display:'flex',flexDirection:'column'}}>
<div style={{position:'absolute',top:-120,left:'50%',transform:'translateX(-50%)',width:520,height:520,borderRadius:'50%',background:'radial-gradient(circle,'+(m.dir==='down'?'rgba(111,180,255,0.22)':'rgba(255,94,69,0.28)')+' 0%,transparent 62%)',opacity:m.running?1:0.5,transition:'opacity 600ms, background 600ms',pointerEvents:'none'}}/>
<header style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'56px 20px 0',position:'relative'}}>
<span style={{font:'800 22px var(--font-display)',letterSpacing:'-0.05em'}}>Accel</span>
<div style={{display:'flex',gap:8,alignItems:'center'}}>{dynamic&&<Badge tone={m.dir==='down'?'info':'accent'} dot={m.running}>{m.running?(m.dir==='up'?'+':'−')+step+' → '+next:'dynamic'}</Badge>}<IconButton label="Settings" variant="ghost" onClick={()=>setSettings(true)}><Icon name="settings"/></IconButton></div></header>
<div style={{flex:1,overflowY:'auto',scrollbarWidth:'none',padding:'16px 20px 120px',display:'flex',flexDirection:'column',gap:16,position:'relative'}}>
<div style={{display:'flex',justifyContent:'center',padding:'12px 0 8px'}}>
<BeatRing beat={m.beat} beatsPerBar={beatsPerBar} accent={m.beat!=null&&accents.includes((m.beat%beatsPerBar)*subdiv)} direction={m.dir} size={250}>
<div style={{display:'flex',flexDirection:'column',alignItems:'center',gap:2}}>
<span key={m.bpm} style={{font:'800 96px/0.9 var(--font-display)',letterSpacing:'var(--tracking-display)',fontFeatureSettings:'var(--font-features-tabular)',animation:'accel-fade-up var(--dur-slow) var(--ease-spring)'}}>{m.bpm}</span>
<span style={{font:'500 11px var(--font-mono)',letterSpacing:'var(--tracking-label)',color:'var(--text-muted)'}}>BPM</span>
{m.running&&dynamic&&<span style={{font:'500 12px var(--font-mono)',color:'var(--text-secondary)',marginTop:6}}>bar {Math.min(m.bar+1,bars)} / {bars}</span>}
</div></BeatRing></div>
{dynamic&&<div style={{height:3,borderRadius:2,background:'var(--surface-glass-strong)',overflow:'hidden'}}><div style={{height:'100%',width:stepPct+'%',background:m.dir==='down'?'var(--info)':'var(--accent)',transition:'width 200ms linear'}}/></div>}
<div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}><Select label="Time signature" value={sig} onChange={setSig} valueStyle={{fontSize:24}} options={['2/4','3/4','4/4','5/4','6/8','7/8','12/8'].map(v=>({value:v,label:v}))}/>
<Segmented label="Subdivision" value={subdiv} onChange={setSubdiv} options={[{value:1,label:'♩'},{value:2,label:'♪♪'},{value:3,label:'♪³'},{value:4,label:'♬♬'}]}/></div>
<AccentGrid label="Accents" beats={beatsPerBar} subdiv={subdiv} accents={accents} onChange={setAccents} current={m.slot}/>
<Card title="Dynamic mode" glow={dynamic&&m.running} action={<Switch checked={dynamic} onChange={setDynamic}/>}>
<div style={{display:'flex',flexDirection:'column',gap:14,opacity:dynamic?1:0.45,transition:'opacity var(--dur-base)'}}>
<NumberField label="Start tempo" unit="BPM" value={startBpm} min={20} max={300} size="lg" onChange={setStart}/>
<div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10}}><NumberField label="Bar count" value={bars} min={1} max={64} onChange={setBars}/><NumberField label="Increase by BPM" value={step} min={1} max={50} onChange={setStep}/></div>
<Switch label="Stop at target" checked={useTarget} onChange={setUseTarget}/>
{useTarget&&<NumberField label="Target tempo" unit="BPM" value={target} min={startBpm+step} max={400} step={5} onChange={setTarget}/>}
<Switch label="Ramp back down" checked={rampDown} onChange={setRampDown} disabled={!useTarget}/>
</div></Card>
</div>
<div style={{position:'absolute',left:0,right:0,bottom:0,padding:'16px 20px 32px',background:'linear-gradient(180deg,transparent,var(--bg) 40%)',display:'flex',gap:10,alignItems:'center'}}>
<IconButton label="Reset" size="lg" onClick={m.stop} disabled={!m.running}><Icon name="rotate-ccw"/></IconButton>
<Button size="xl" fullWidth glow={!m.running} variant={m.running?'secondary':'primary'} icon={<Icon name={m.running?'pause':'play'} size={22}/>} onClick={m.toggle}>{m.running?'Stop':'Start'}</Button></div>
{toast&&<div style={{position:'absolute',top:110,left:0,right:0,display:'flex',justifyContent:'center',pointerEvents:'none'}}><Toast tone="positive" icon={<Icon name="check" size={18}/>}>{toast}</Toast></div>}
<Dialog open={settings} onClose={()=>setSettings(false)} title="Settings" sheet footer={<Button onClick={()=>setSettings(false)}>Done</Button>}>
<div style={{display:'flex',flexDirection:'column',gap:18}}><Slider label="Volume" value={vol} format={v=>v+'%'} onChange={setVol}/><Switch label="Haptics" checked={false} onChange={()=>{}}/></div></Dialog>
</div>}
window.MetronomeScreen=MetronomeScreen;
