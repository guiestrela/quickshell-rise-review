const fs=require('fs'),assert=require('assert');
const t=fs.readFileSync(process.argv[2],'utf8');
const expr=t.match(/readonly property bool anchoredPanelVisible:([\s\S]*?)\n\n/)[1].trim();
const names=[...new Set(expr.match(/[A-Za-z_][A-Za-z0-9_]*/g))];
function visible(owner){return Function(...names,'return '+expr)(...names.map(n=>n===owner));}
assert.strictEqual(visible('wallpaperManagerVisible'),true,'Wallpaper surface owner is missing from bar inset visibility');
for(const n of ['notifVisible','weatherVisible','displayManagerVisible'])assert.strictEqual(visible(n),true,n+' regressed');
assert.strictEqual(visible('noPopup'),false);
const body=t.match(/function setPanelInsetX\(x\) \{([\s\S]*?)\n    \}/)[1];
const ctx={anchoredPanelVisible:visible('wallpaperManagerVisible'),panelInsetX:0,panelInsetReady:false};
Function('x','with(this){'+body+'}').call(ctx,200);
assert.strictEqual(ctx.panelInsetReady,true);assert.strictEqual(ctx.panelInsetX,200);
console.log('PASS wallpaper inset owner and existing owners; setPanelInsetX accepted');
