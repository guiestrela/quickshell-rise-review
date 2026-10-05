import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// Executes the production writer expression and loader body, not QML Process.
for (const [variant, relative, offset] of [['V1','versions/V1/Theme.qml',35],['V2','versions/V1/variants/V2/Theme.qml',47]]) {
  const source=readFileSync(new URL('../'+relative,import.meta.url),'utf8');
  const expression=source.slice(source.indexOf('function saveWidgets()')).match(/var line =([\s\S]*?)widgetSaveProc.command/)[1];
  const loader=source.slice(source.indexOf('id: widgetLoadProc'));
  const body=loader.slice(loader.indexOf('var parts ='),loader.indexOf('theme._widgetsLoaded = true'));
  const identifiers=expression.replace(/\/\/[^\n]*/g,'').replace(/"[^"]*"/g,'').match(/\b[A-Za-z_]\w*\b/g);
  function save(enabled, auto) {
    const context=Object.fromEntries(identifiers.map(key=>[key,false]));
    Object.assign(context,{modDisplayManager:enabled,displayManagerAutoWorkspaces:auto,workspaceMode:'10',pickerStyle:'hearthstone',workspaceStyle:'numbers',barPosition:'top',aiTool:'claude',launcherLogoMode:'text',launcherLogoText:'omarchy',launcherLogoIcon:'omarchy'});
    context.serializeWidgetColorStyles=()=>'-';
    return vm.runInNewContext('var line ='+expression+'; line',context);
  }
  function load(text) {
    const theme={modDisplayManager:false,displayManagerAutoWorkspaces:true,launcherLogoTextValid:()=>true,launcherLogoIconValid:()=>true};
    for(const match of body.matchAll(/theme\.(\w+)\(/g)) if(!theme[match[1]]) theme[match[1]]=()=>{};
    vm.runInNewContext(body,{theme,text});
    return theme;
  }
  for (const enabled of [false,true]) for (const auto of [false,true]) {
    const text=save(enabled,auto), fields=text.trim().split(' ');
    assert.equal(fields[5+offset],enabled?'1':'0',variant+' visibility offset');
    assert.equal(fields[5+offset+1],auto?'1':'0',variant+' workspace offset');
    const restored=load(text);
    assert.equal(restored.modDisplayManager,enabled);
    assert.equal(restored.displayManagerAutoWorkspaces,auto);
    const old=load(fields.slice(0,5+offset).join(' '));
    assert.equal(old.modDisplayManager,false,variant+' old cache defaults');
    assert.equal(old.displayManagerAutoWorkspaces,true,variant+' old workspace default');
  }
}
console.log('DISPLAY_PERSISTENCE_PASS V1/V2 production JS writer/loader; old caches; not QML file I/O');
