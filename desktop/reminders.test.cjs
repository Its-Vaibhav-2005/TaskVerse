const {test}=require('node:test');
const assert=require('node:assert/strict');
const {TrackVerseDatabase}=require('./database.cjs');
const {HabitReminders}=require('./reminders.cjs');

const habit={id:'water',name:'Drink water',category:'Wellness',color:1,icon:1,created:'2026-10-01',weekdays:[1,2,3,4,5,6,7],months:['2026-10-01'],checks:[],dailyTarget:8,dailyCounts:{},reminder:{enabled:true,time:'09:00',interval:60}};
function fixture(t){
  const db=new TrackVerseDatabase(':memory:');db.save([habit]);
  t.after(()=>db.close());
  const messages=[],manager={list:()=>[{id:'local',alias:'Personal habits'}],store:()=>db};
  const scheduler=new HabitReminders(manager,{notify:message=>messages.push(message),onError:error=>{throw error;}});
  return {db,messages,scheduler,manager};
}

test('partial counts persist, only target completion checks the day, and corrections reopen it',t=>{
  const {db}=fixture(t),now=new Date(2026,9,24,10),day='2026-10-24';
  db.setCount('water',day,3,now);
  assert.equal(db.load()[0].dailyCounts[day],3);assert.deepEqual(db.load()[0].checks,[]);
  db.setCount('water',day,8,now);assert.deepEqual(db.load()[0].checks,[day]);
  db.setCount('water',day,7,now);assert.deepEqual(db.load()[0].checks,[]);
  for(const value of [-1,9,1.5,'2'])assert.throws(()=>db.setCount('water',day,value,now));
  assert.throws(()=>db.setCount('water','2026-10-23',1,now),/Only today/);
  assert.equal(db.load()[0].dailyCounts[day],7);
  const snapshot={format:'trackverse',version:1,habits:db.load(),months:['2026-10-01']};
  db.save([]);db.restore(snapshot);assert.deepEqual(db.load()[0],snapshot.habits[0]);
});

test('reminders start on time, repeat once per interval, and survive scheduler restarts without duplicates',t=>{
  const {db,messages,scheduler,manager}=fixture(t);
  scheduler.tick(new Date(2026,9,24,8,59));assert.equal(messages.length,0);
  scheduler.tick(new Date(2026,9,24,9));scheduler.tick(new Date(2026,9,24,9,15));assert.equal(messages.length,1);
  const restarted=new HabitReminders(manager,{notify:m=>messages.push(m)});
  restarted.tick(new Date(2026,9,24,9,59));assert.equal(messages.length,1);
  db.setCount('water','2026-10-24',3,new Date(2026,9,24,10));
  restarted.tick(new Date(2026,9,24,10));assert.equal(messages.length,2);assert.match(messages[1].body,/3\/8 today/);
  restarted.tick(new Date(2026,9,24,15,45));assert.equal(messages.length,3); // No burst after sleep.
  db.setCount('water','2026-10-24',8,new Date(2026,9,24,16));
  restarted.tick(new Date(2026,9,24,16));assert.equal(messages.length,3);
  restarted.tick(new Date(2026,9,25,9));assert.equal(messages.length,4);assert.match(messages[3].body,/0\/8/);
});

test('schedule changes, disabled reminders, non-scheduled days and deleted habits take effect',t=>{
  const {db,messages,scheduler}=fixture(t);
  const update=patch=>db.save([{...db.load()[0],...patch}]);
  update({reminder:{enabled:true,time:'11:30',interval:15}});
  scheduler.tick(new Date(2026,9,24,11,29));assert.equal(messages.length,0);
  scheduler.tick(new Date(2026,9,24,11,30));scheduler.tick(new Date(2026,9,24,11,45));assert.equal(messages.length,2);
  update({reminder:{enabled:false,time:'11:30',interval:15}});
  scheduler.tick(new Date(2026,9,24,12));assert.equal(messages.length,2);
  update({reminder:habit.reminder,weekdays:[1]});scheduler.tick(new Date(2026,9,24,12));assert.equal(messages.length,2);
  update({weekdays:habit.weekdays,months:['2026-11-01']});scheduler.tick(new Date(2026,9,24,12));assert.equal(messages.length,2);
  db.save([]);scheduler.tick(new Date(2026,9,24,13));assert.equal(messages.length,2);
});

test('invalid goals and reminder backups fail without replacing valid data',t=>{
  const {db}=fixture(t);
  for(const patch of [{dailyTarget:0},{dailyTarget:100},{dailyCounts:{'bad':1}},{dailyCounts:{'2026-10-24':-1}},{reminder:{enabled:true,time:'25:00',interval:60}},{reminder:{enabled:true,time:'09:00',interval:0}}]){
    assert.throws(()=>db.save([{...habit,...patch}]));assert.equal(db.load()[0].dailyTarget,8);
  }
});
