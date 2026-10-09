// 3.0 entry module: Three.js and addons from ./vendor (import map), asset preload with a progress
// bar, then the classic game script. file:// is refused earlier by an inline script in index.html.
import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';
import {createAssets30} from './assets-30.js';
globalThis.THREE=THREE;globalThis.RoomEnvironment30=RoomEnvironment;globalThis.BGU30={mergeGeometries};
const bar=document.getElementById('loading30Bar'),label=document.getElementById('loading30Label');
globalThis.ASSETS30=createAssets30({THREE,GLTFLoader,SkeletonUtils,onProgress:f=>{const pct=Math.round(f*100);bar.value=pct;label.textContent='載入素材 '+pct+'%';}});
await ASSETS30.ready;
if(ASSETS30.failed.length)label.textContent='部分素材無法載入，改用基本畫面';
const game=document.createElement('script');game.src='game.js';
game.onload=()=>{document.getElementById('loading30').hidden=true;globalThis.GAME30_READY=true;};
game.onerror=()=>{label.textContent='遊戲程式載入失敗，請重新整理';};
document.body.append(game);
