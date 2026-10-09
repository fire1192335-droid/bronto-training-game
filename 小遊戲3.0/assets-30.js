// 3.0 asset preloader: reads assets/manifest.json, loads every preload asset, and exposes them
// synchronously as globalThis.ASSETS30 before game.js starts. Failures are recorded, never thrown,
// so a missing model leaves the 2.1 visuals in place.
// Everything a loaded asset owns is shared by all of its clones (SkeletonUtils.clone reuses geometry/material objects),
// so mark it: runtime disposal of a detached clone must skip userData.shared30 resources.
function mark30(scene){const seen=new Set(),mk=o=>{if(o&&!seen.has(o)){seen.add(o);o.userData=o.userData||{};o.userData.shared30=true;}};
 scene.traverse(o=>{mk(o.geometry);for(const m of [].concat(o.material||[])){mk(m);for(const v of Object.values(m))if(v&&v.isTexture)mk(v);}});}
export function createAssets30({THREE,GLTFLoader,SkeletonUtils,base='assets/',onProgress=()=>{}}){
 const store=new Map(),failed=[];
 const api={failed,loadedBytes:0,totalBytes:0,has:id=>store.has(id)&&!store.get(id).pending,
  model:id=>{const s=store.get(id)?.scene;return s?(SkeletonUtils?SkeletonUtils.clone(s):s.clone(true)):null;},
  animations:id=>store.get(id)?.animations??[],texture:id=>store.get(id)?.texture??null,url:id=>store.get(id)?.url??null,
  configureTextureSampling:renderer=>{const max=renderer?.capabilities?.getMaxAnisotropy?.()??1;for(const {texture} of store.values())if(texture&&texture.anisotropy!==max){texture.anisotropy=max;texture.needsUpdate=true;}return max;},ready:null};
 api.ready=(async()=>{
  let manifest;
  try{const r=await fetch(base+'manifest.json');if(!r.ok)throw Error('HTTP '+r.status);manifest=await r.json();}
  catch(error){failed.push({id:'manifest',url:base+'manifest.json',error:String(error)});console.warn('[assets30] manifest',error);onProgress(1);return api;}
  const list=manifest.assets||[],pre=list.filter(a=>a.preload!==false),done=new Map();
  for(const a of list)if(a.preload===false)store.set(a.id,{url:base+a.url});
  api.totalBytes=pre.reduce((s,a)=>s+(a.bytes||0),0);
  const report=()=>{api.loadedBytes=[...done.values()].reduce((s,v)=>s+v,0);onProgress(api.totalBytes?Math.min(1,api.loadedBytes/api.totalBytes):1);};
  const gltf=new GLTFLoader(),tex=new THREE.TextureLoader();
  await Promise.all(pre.map(async a=>{const url=base+a.url;
   try{
    if(a.type==='gltf'){const g=await gltf.loadAsync(url,e=>{if(e.lengthComputable){done.set(a.id,Math.min(e.loaded,a.bytes||e.loaded));report();}});mark30(g.scene);store.set(a.id,{url,scene:g.scene,animations:g.animations||[],gltf:g});}
    else if(a.type==='texture'){const t=await tex.loadAsync(url);t.userData.shared30=true;t.colorSpace=a.colorSpace==='srgb'?THREE.SRGBColorSpace:THREE.NoColorSpace;store.set(a.id,{url,texture:t});}
    else throw Error('unknown asset type '+a.type);
   }catch(error){failed.push({id:a.id,url,error:String(error?.message||error)});console.warn('[assets30]',a.id,error);}
   done.set(a.id,a.bytes||0);report();}));
  report();return api;})();
 return api;
}
