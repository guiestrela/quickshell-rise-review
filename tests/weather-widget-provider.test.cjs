const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const helper = path.join(root, 'versions/V1/integrations/WeatherData.js');
assert.ok(fs.existsSync(helper), 'Weather widget must use the configured location/provider, not only the failing wttr endpoint');
const ctx = {}; vm.createContext(ctx); vm.runInContext(fs.readFileSync(helper, 'utf8').replace(/^\.pragma library\s*/, ''), ctx);
const settings = { name: 'Fixture city', latitude: -10, longitude: -40 };
const url = new URL(ctx.weatherUrl(settings));
assert.equal(url.hostname, 'api.open-meteo.com');
assert.equal(url.searchParams.get('latitude'), '-10');
assert.equal(url.searchParams.get('longitude'), '-40');
assert.equal(new URL(ctx.weatherUrl({name:'City & other'})).pathname, '/City%20%26%20other');
assert.equal(new URL(ctx.weatherUrl({latitude:91, longitude:0})).hostname, 'wttr.in');
for (const [code,expected] of [[0,113],[2,116],[3,119],[45,143],[53,266],[63,308],[73,338],[95,389]]) {
 const data=ctx.normalize({current:{temperature_2m:0,weather_code:code,is_day:0}},settings);
 assert.equal(data.current_condition[0].weatherCode,expected);
 assert.equal(data.current_condition[0].temp_C,'0');
 assert.equal(data.isNight,true);
 assert.equal(data.nearest_area[0].areaName[0].value,'Fixture city');
}
assert.throws(()=>ctx.normalize({current:{temperature_2m:20}},settings));
assert.throws(()=>ctx.normalize({current:{temperature_2m:null,weather_code:0}},settings));
const wttr={current_condition:[{weatherCode:'113',temp_C:'20'}]}; assert.equal(ctx.normalize(wttr,{}),wttr);
for (const variant of ['versions/V1','versions/V1/variants/V2']) {
 const src=fs.readFileSync(path.join(root,variant,'modules/WeatherWidget.qml'),'utf8');
 assert.match(src,/WeatherData\.weatherUrl\(rootMod\.requestSettings\)/);
 assert.match(src,/WeatherData\.normalize\(JSON\.parse\(txt\), rootMod\.requestSettings\)/);
 assert.match(src,/\.cache\/quickshell-rise\/weather-location/);
 assert.match(src,/running: rootMod\.locationReady &&/);
}
console.log('PASS configured provider, schema, weather codes, night, zero temperature, malformed replies and V1/V2 wiring');
