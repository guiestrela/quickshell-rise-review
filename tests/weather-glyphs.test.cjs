const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ctx = {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../shared/integrations/WeatherData.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), ctx);
const groups = [
    [[113], 0xe30d, 0xe32b], [[116], 0xe302, 0xe32e],
    [[119, 122], 0xe33d], [[143, 248, 260], 0xe313],
    [[176, 263, 266, 293, 296, 353], 0xe308, 0xe333],
    [[179, 227, 230, 323, 326, 368], 0xe30a, 0xe327],
    [[182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377], 0xe3ad],
    [[200, 386, 389, 392, 395], 0xe31d],
    [[299, 302, 305, 308, 356, 359], 0xe318],
    [[329, 332, 335, 338, 371], 0xe31a],
    [[undefined, null, '', 'invalid', 999], 0xe33d],
];
for (const [codes, day, night = day] of groups) {
    for (const code of codes) {
        assert.equal(ctx.glyphForCode(code, false), String.fromCodePoint(day));
        assert.equal(ctx.glyphForCode(code, true), String.fromCodePoint(night));
        if (code != null) assert.equal(ctx.glyphForCode(String(code), false), String.fromCodePoint(day));
    }
}
console.log('PASS shared weather glyphs: all mapped codes, day/night, strings and unknown conditions');
