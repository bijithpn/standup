/** Import the MIT-licensed authored models, not approximated screenshots.
 * Node 22+; usage: node tool/import_oneworks_heads.mjs /path/to/oneworks/avatar
 * The source checkout is read-only. No npm packages or renderer are installed.
 */
import {registerHooks} from 'node:module';
import {existsSync,readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {execFileSync} from 'node:child_process';
import {refinePet} from './pet_character_refinements.mjs';
const root=resolve(process.argv[2]??'/private/tmp/oneworks-avatar-reference');
registerHooks({
 resolve(specifier,context,next){
  if(specifier==='@oneworks/avatar')return {url:pathToFileURL(root+'/packages/avatar/src/index.ts').href,shortCircuit:true};
  if(specifier.startsWith('.')&&context.parentURL){
   let path=fileURLToPath(new URL(specifier,context.parentURL));
   if(!existsSync(path)){
    if(path.endsWith('.js')&&existsSync(path.slice(0,-3)+'.ts'))path=path.slice(0,-3)+'.ts';
    else if(existsSync(path+'.ts'))path+='.ts';
   }
   if(existsSync(path))return {url:pathToFileURL(path).href,shortCircuit:true};
  }
  return next(specifier,context);
 },
 load(url,context,next){
  const result=next(url,context);
  if(url===pathToFileURL(root+'/src/avatarGeometry.ts').href){
   // Authoring-only access to upstream's actual surface sampler. Persist its
   // local 3D results; the Flutter renderer applies its live rig and pose.
   return {...result,source:result.source.toString()+'\nexport {getFacePoint,getFaceNormal,getShapeFacePoint,getShapeFaceNormal,getSurfacePoint};\n'};
  }
  return result;
 }
});
const model=await import(pathToFileURL(root+'/src/avatarEntityPresets.ts').href);
const geo=await import(pathToFileURL(root+'/src/avatarGeometry.ts').href);
const breeds=await import(pathToFileURL(root+'/src/avatarBreedTemplates.ts').href);
const core=await import(pathToFileURL(root+'/packages/avatar/src/index.ts').href);
const output=JSON.parse(readFileSync('assets/avatars/scenes/avatar_scenes.json','utf8'));
const foundation=new Set(['cat','dog','parrot','capybara','seal']);
const onlyFoundation=process.argv.includes('--foundation');
function bindMarkings(parts,marks){
 return marks.flatMap(mark=>{
  const host=parts.find(p=>p.id===mark.targetPartId);if(!host)return [];
  const spec=geo.getAvatarBodyCompilerShapeSpec(host.shape);
  const options={bottomTaper:host.bottomTaper,roundness:host.roundness,topScale:host.topScale,cutAngle:host.cutAngle};
  const surfaceRegions=geo.buildAvatarSurfaceDecalLocalBoundaries(mark,host.shape,options).map(region=>region.map(point=>{
   const face=mark.side==='face';
   const n=(face?geo.getFaceNormal:geo.getShapeFaceNormal)(spec,point,options);
   const p=(face?geo.getFacePoint:geo.getShapeFacePoint)(spec,point,options);
   if(!face){p.x+=n.x*1.2;p.y+=n.y*1.2;p.z+=n.z*1.2;}
   return [p.x,p.y,p.z,n.x,n.y,n.z].map(v=>Number(v.toFixed(6)));
  }));
  return [{...mark,surfaceRegions}];
 });
}
function store(name,parts,scene,faceStyle,marks){
 if(onlyFoundation&&!foundation.has(name))return;
 const refined=refinePet(name,parts,scene,faceStyle,marks);
 parts=refined.parts;scene=refined.scene;faceStyle=refined.face;marks=refined.marks;
 parts=parts.filter(p=>! /^(torso|chest|paw|forepaw|wing|flipper|tail)/.test(p.id)).map(p=>({...p,scaleZ:p.scaleZ??Math.min(p.scaleX,p.scaleY)}));
 output[name]={parts,scene,faceStyle:{...faceStyle,height:name==='bun'?Math.max(faceStyle.height,30):faceStyle.height,eyeShape:'reference-rounded',eyeOffsetY:faceStyle.eyeOffsetY??({dog:-22,capybara:-18,seal:-16,beaver:-12,monkey:-10,'guinea-pig':-8,ferret:-8}[name]??0)},markings:bindMarkings(parts,marks)};
}
for(const name of model.AVATAR_BUILT_IN_ENTITY_PRESETS){
 const scene=model.getAvatarEntityPresetScene(name);
 store(name,model.createAvatarEntityParts(name),scene,model.getAvatarEntityPresetFaceStyle(name),scene.surfaceDecals);
}
for(const [name,id] of [['panda','giant-panda'],['red-panda','red-panda'],['raccoon','raccoon']]){
 const template=breeds.getAvatarBearBreedTemplate(id);
 const resolved=breeds.resolveAvatarBearBreedTemplate({...template,followByDefault:[]},'breakmate-reference');
 const scene=model.getAvatarEntityPresetScene('bear');
 const parts=resolved.entityParts;
 const marks=core.resolveAvatarCoatPatternDecals({entityParts:parts,entityPreset:'bear',paletteId:resolved.paletteId,pattern:{...resolved.coatPattern,enabled:true}});
 store(name,parts,scene,resolved.faceStyle,marks);
}
writeFileSync('assets/avatars/scenes/avatar_scenes.json',JSON.stringify(output)+'\n');
const geometryChecks=[];
for(const [preset,definition] of Object.entries(output)){
 const part=definition.parts.find(p=>p.face);
 if(!part)continue;
 for(const longitude of [-.7,0,.7]){for(const latitude of [-.4,0,.4]){
  const point=geo.getSurfacePoint(geo.getAvatarBodyCompilerShapeSpec(part.shape),longitude,latitude,false,part);
  geometryChecks.push({preset,partId:part.id,longitude,latitude,point:[point.x,point.y,point.z]});
 }}
}
const commit=execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8'}).trim();
writeFileSync('assets/avatars/scenes/oneworks_source.json',JSON.stringify({repository:'https://github.com/oneworks-ai/avatar',commit,license:'../LICENSE',importer:'tool/import_oneworks_heads.mjs',parts:'Authored upstream models, including upstream bear breed definitions for panda, red panda and raccoon.',markings:'Upstream boundaries and surface sampling in part-local 3D coordinates.',foundationOnly:onlyFoundation,geometryChecks,adaptations:'Original proportions and palettes retained except for documented local refinements. Dog face is raised per upstream renderer; other muzzle-bearing heads use small eye-placement corrections to prevent occlusion. Local matte art direction and alpaca/sheep/parrot refinements are applied by pet_character_refinements.mjs.'},null,2)+'\n');
console.log(`Imported ${onlyFoundation?5:Object.keys(output).length} heads from OneWorks ${commit}`);
