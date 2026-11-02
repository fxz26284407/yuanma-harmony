import {execFileSync} from 'node:child_process';
import {access,mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const source=fileURLToPath(new URL('../.local/noise-c',import.meta.url));
const revision='cfe25410979a87391bb9ac8d4d4bef64e9f268c6';
await mkdir(fileURLToPath(new URL('../.local/',import.meta.url)),{recursive:true});
try{await access(source);}catch{
 execFileSync('git',['clone','--no-checkout','https://github.com/rweather/noise-c.git',source],{stdio:'inherit'});
 execFileSync('git',['-C',source,'checkout','--detach',revision],{stdio:'inherit'});
}
const git=(...args)=>execFileSync('git',['-C',source,...args],{encoding:'utf8'}).trim();
if(git('rev-parse','HEAD')!==revision||git('status','--porcelain'))throw Error('Native cryptography requires the unchanged pinned Noise-C revision '+revision);
