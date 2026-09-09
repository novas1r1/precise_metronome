// Scheduler + dynamic ramp logic. window.useMetronome
window.useMetronome=function useMetronome(cfg){
const [running,setRunning]=React.useState(false);
const [bpm,setBpm]=React.useState(cfg.startBpm);
const [beat,setBeat]=React.useState(null); // absolute beat count
const [bar,setBar]=React.useState(0); // bars completed in current step
const [dir,setDir]=React.useState('up');
const [done,setDone]=React.useState(false);
const st=React.useRef({});const ctx=React.useRef(null);const cfgRef=React.useRef(cfg);cfgRef.current=cfg;const [slot,setSlot]=React.useState(null);
React.useEffect(()=>{if(!running)setBpm(cfg.startBpm)},[cfg.startBpm,running]);
const click=(t,accent,sub)=>{const c=ctx.current;const o=c.createOscillator();const g=c.createGain();o.frequency.value=accent?1600:sub?700:1000;g.gain.setValueAtTime(sub?0.12:accent?0.5:0.3,t);g.gain.exponentialRampToValueAtTime(0.0001,t+0.05);o.connect(g).connect(c.destination);o.start(t);o.stop(t+0.06)};
const start=()=>{if(!ctx.current)ctx.current=new (window.AudioContext||window.webkitAudioContext)();ctx.current.resume();
const s=st.current;s.bpm=cfg.startBpm;s.beatInBar=0;s.bar=0;s.dir='up';s.beatIdx=0;s.subIdx=0;s.next=ctx.current.currentTime+0.1;s.done=false;
setBpm(cfg.startBpm);setBar(0);setDir('up');setDone(false);setRunning(true);
const [num]=cfg.sig.split('/').map(Number);
s.timer=setInterval(()=>{const c=ctx.current;while(s.next<c.currentTime+0.12){
const isMain=s.subIdx===0;const sl=s.beatInBar*cfg.subdiv+s.subIdx;const acc=(cfgRef.current.accents||[]).includes(sl);
click(s.next,acc,!isMain&&!acc);setSlot(sl);
if(isMain){const idx=s.beatIdx;setBeat(idx);
// after each main beat, advance
s.beatIdx++;s.beatInBar++;
if(s.beatInBar>=num){s.beatInBar=0;s.bar++;
if(cfg.dynamic&&s.bar>=cfg.bars){s.bar=0;
let nb=s.dir==='up'?s.bpm+cfg.step:s.bpm-cfg.step;
if(s.dir==='up'&&cfg.target&&nb>=cfg.target){nb=cfg.target;if(cfg.rampDown)s.dir='down';else{s.done=true;setDone(true)}}
if(s.dir==='down'&&nb<=cfg.startBpm){nb=cfg.startBpm;s.done=true;setDone(true)}
s.bpm=nb;setBpm(nb);setDir(s.dir)}
setBar(s.bar)}}
s.subIdx=(s.subIdx+1)%cfg.subdiv;
s.next+=60/s.bpm/cfg.subdiv;}},25)};
const stop=()=>{clearInterval(st.current.timer);setRunning(false);setBeat(null);setSlot(null);setBar(0)};
React.useEffect(()=>()=>clearInterval(st.current.timer),[]);
return {running,bpm,beat,slot,bar,dir,done,start,stop,toggle:()=>running?stop():start()};
};
