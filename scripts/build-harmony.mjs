import './prepare-crypto.mjs';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const ide='/Applications/DevEco-Studio.app/Contents';
execFileSync(`${ide}/tools/hvigor/bin/hvigorw`,['--mode','module','-p','product=default','-p','module=entry@default','assembleHap','--no-daemon'],{cwd:fileURLToPath(new URL('../harmony/',import.meta.url)),env:{...process.env,NODE_HOME:`${ide}/tools/node`,DEVECO_SDK_HOME:`${ide}/sdk`},stdio:'inherit'});
