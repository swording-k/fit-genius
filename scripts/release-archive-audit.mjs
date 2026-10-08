import fs from 'node:fs';
import path from 'node:path';
import cp from 'node:child_process';
const archive = process.argv[2];
if (!archive) throw Error('Pass an .xcarchive path');
const root = path.join(archive, 'Products/Applications/FitGenius.app');
let apps = [], media = [];
function visit(dir) {
  for (let entry of fs.readdirSync(dir, {withFileTypes:true})) {
    const p = path.join(dir, entry.name);
    if(entry.isDirectory()) visit(p);
    else if (entry.name === 'Info.plist' && /\.(app|appex)$/.test(dir)) {
      const plist = JSON.parse(cp.execFileSync('plutil',['-convert','json','-o','-',p]));
      apps.push({bundle:plist.CFBundleIdentifier,version:plist.CFBundleShortVersionString,build:plist.CFBundleVersion});
    } else if (/\.(mp4|mov)$/i.test(entry.name)) media.push(p);
  }
}
visit(root);
if (apps.length !== 3 || !apps.every(x=>x.version==='1.6.0'&&x.build==='20261008')) throw Error('Embedded version mismatch');
if (media.length) throw Error('Development videos must not be bundled into Release: '+media.map(x=>path.basename(x)).join(','));
cp.execFileSync('codesign',['--verify','--deep','--strict',root], {stdio:['ignore','pipe','pipe']});
console.log(JSON.stringify({archive,targets:apps,bundledDevelopmentVideos:0,signatureValid:true},null,2));
