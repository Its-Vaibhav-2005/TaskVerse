const {isDeepStrictEqual: equal}=require('node:util');
// Merge only independent edits. Missing keys mean deletion, never an empty value.
function merge(base,local,remote,key='') {
  if(equal(local,remote)||equal(base,remote))return local;
  if(equal(base,local))return remote;
  if(base&&local&&remote&&[base,local,remote].every(v=>typeof v==='object'&&!Array.isArray(v))) {
    if('dailyTarget' in base && (
      (!equal(base.dailyTarget,local.dailyTarget)&&(!equal(base.dailyCounts,remote.dailyCounts)||!equal(base.checks,remote.checks))) ||
      (!equal(base.dailyTarget,remote.dailyTarget)&&(!equal(base.dailyCounts,local.dailyCounts)||!equal(base.checks,local.checks)))
    ))throw Error('Target and completion changed together');
    const result={};
    for(const k of new Set([...Object.keys(base),...Object.keys(local),...Object.keys(remote)])) {
      const value=merge(base[k],local[k],remote[k],k);
      if(value!==undefined)result[k]=value;
    }
    return result;
  }
  if([base,local,remote].every(Array.isArray)) {
    if(['habits','focusSessions'].includes(key)) {
      const maps=[base,local,remote].map(a=>Object.fromEntries(a.map(v=>[v.id,v])));
      return Object.values(merge(...maps));
    }
    if(['checks','months'].includes(key)) {
      const result=[];
      for(const value of new Set([...base,...local,...remote])) {
        if(merge(base.includes(value),local.includes(value),remote.includes(value)))result.push(value);
      }
      return result.sort();
    }
  }
  throw Error('Overlapping changes');
}
function mergeSnapshot(base,local,remote) {
  if(!base)return null;
  try{return merge(base,local,remote);}catch{return null;}
}
module.exports={mergeSnapshot};
