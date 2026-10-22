const {randomUUID}=require('node:crypto');
class Pomodoro {
  constructor(manager,{now=()=>Date.now(),onSave=()=>{}}={}){
    this.manager=manager;this.now=now;this.onSave=onSave;
    this.state={work:25,break:5,phase:'work',remaining:1500,running:false,...manager.root.getPreference('pomodoro',{})};
    // An interrupted app resumes paused; never invent unattended hours after a crash.
    this.state.running=false;this.persist();
  }
  persist(){this.manager.root.setPreference('pomodoro',this.state);}
  checkpoint(){
    const s=this.state;if(!s.running)return;
    const elapsed=Math.max(0,Math.min(s.remaining,(this.now()-s.anchor)/1000));
    if(elapsed<0.01)return;
    s.remaining=Math.max(0,s.remaining-elapsed);s.anchor=this.now();
    if(s.phase==='work'&&s.session){
      const record={...s.session,seconds:(s.session.seconds||0)+elapsed};
      this.manager.mutate(s.workspaceId,db=>db.saveFocusSession(record));s.session=record;this.onSave(s.workspaceId);
    }
    if(s.remaining<=0){s.running=false;s.phase=s.phase==='work'?'break':'work';s.remaining=s[s.phase]*60;s.session=null;}
    this.persist();
  }
  read(){const s=this.state;return {...s,remaining:s.running?Math.max(0,s.remaining-(this.now()-s.anchor)/1000):s.remaining};}
  action(action,data={}){
    this.checkpoint();const s=this.state;
    if(action==='configure'){
      if(s.running||s.session)throw Error('Reset this session before changing its setup.');
      if(!Number.isInteger(data.work)||data.work<1||data.work>180||!Number.isInteger(data.break)||data.break<1||data.break>60)throw Error('Use 1–180 work minutes and 1–60 break minutes.');
      s.work=data.work;s.break=data.break;s.phase='work';s.remaining=s.work*60;s.habitId=data.habitId||null;
    }else if(action==='start'){
      if(!s.running){
        if(s.phase==='work'&&!s.session){
          const db=this.manager.store(),habit=db.load().find(h=>h.id===(data.habitId||s.habitId));
          if(!habit)throw Error('Select a habit first.');
          s.workspaceId=this.manager.activeId;s.habitId=habit.id;
          s.session={id:randomUUID(),habitId:habit.id,name:habit.name,color:habit.color,started:new Date(this.now()).toISOString(),seconds:0};
        }
        s.running=true;s.anchor=this.now();
      }
    }else if(action==='pause'){s.running=false;}
    else if(action==='reset'){s.running=false;s.session=null;s.phase='work';s.remaining=s.work*60;}
    else throw Error('Unknown timer action');
    this.persist();return this.read();
  }
}
module.exports={Pomodoro};
