// Parser fixtures inline the production function body; real QML probes retain imports.
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
function readQmlSource(path, options) {
  let text = readFileSync(path, options);
  if (typeof text !== 'string' || !String(path).endsWith('.qml')) return text;
  const sharedWidget = text.match(/Shared\.(ClockWidget|ScreenRecordWidget|WallpaperWidget|VoxtypeWidget|ArchUpdaterWidget|BrightnessWidget|BatteryWidget|BluetoothWidget|PowerProfileWidget|NordVPNWidget|TrayWidget|LauncherWidget|ClaudeWidget|MprisWidget)\s*\{/);
  if (sharedWidget) {
    text = readFileSync(resolve(__dirname, '../shared/components/' + sharedWidget[1] + '.qml'), 'utf8');
  }
  const sharedPanel = text.match(/Shared\.(WallpaperManagerQuickPanel|MprisPanel)\s*\{/);
  if (sharedPanel) {
    text = readFileSync(resolve(__dirname, '../shared/panels/' + sharedPanel[1] + '.qml'), 'utf8');
  }
  if (/Shared\.WeatherWidget\s*\{/.test(text)) {
    const adapter=text;
    text=readFileSync(resolve(__dirname,'../shared/components/WeatherWidget.qml'),'utf8');
    for(const field of ['contentColor','loadingGlyph']) {
      const value=adapter.match(new RegExp('    '+field+': ([^\\n]+)'))?.[1]?.replaceAll('widget.','rootMod.');
      if(value) text=text.replace(new RegExp('    (?:required )?property (\\w+) '+field+'[^\\n]*'),
        (_,type)=>'    property '+type+' '+field+': '+value);
    }
  }
  return text.replace(/^    function (\w+)\(([^\n]*)\) \{ return ((?:Theme\w+|\w+Logic))\.\1\((\w+), .* \}$/gm,
    (line, name, args, module, owner) => {
      const js = readFileSync(resolve(__dirname, '../shared/logic/' + module + '.js'), 'utf8');
      const start = js.indexOf('function ' + name + '(');
      if (start < 0) throw new Error('Missing shared method ' + name);
      const end = js.indexOf('\nfunction ', start + 1);
      let body = js.slice(start, end < 0 ? undefined : end).trim();
      body = body.replace(/^function \w+\([^\n]*\) \{/, 'function ' + name + '(' + args + ') {')
        .replace(/\n    var riseState = riseOwner;\n/, '\n').replace(/\briseState\./g, '')
        .replace(/\briseEnvironment\./g, '').replace(/\briseOwner\b/g, owner);
      return '    ' + body;
    });
}
module.exports = { readQmlSource };
