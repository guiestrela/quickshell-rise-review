import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const api = {};
const source = readFileSync(new URL('../shared/logic/ThemeAiUsage.js', import.meta.url), 'utf8')
    .replace(/^\.pragma library\s*/m, '');
vm.runInNewContext(source, api, { filename: 'ThemeAiUsage.js' });
const themes = ['V1', 'V2'].map((variant) => ({
    variant,
    source: readFileSync(new URL(`../variants/${variant}/Theme.qml`, import.meta.url), 'utf8'),
}));

test('all provider readers in both variants share the common freshness contract', () => {
    const call = 'ThemeAiUsage.aiUsageMtimeFresh(theme, {}, mtime, Date.now() / 1000)';
    for (const { variant, source: themeSource } of themes) {
        assert.equal(themeSource.split(call).length - 1, 4, `${variant}: four local provider readers`);
        assert.doesNotMatch(themeSource, /Date\.now\(\) \/ 1000 - mtime/);
    }
});

test('AI records expire at the exact 15-minute boundary', () => {
    assert.equal(api.aiUsageMtimeFresh({}, {}, 1000, 1899.999), true);
    assert.equal(api.aiUsageMtimeFresh({}, {}, 1000, 1900), false);
});

test('future, invalid and non-positive mtimes are not fresh', () => {
    assert.equal(api.aiUsageMtimeFresh({}, {}, 1001, 1000), false);
    assert.equal(api.aiUsageMtimeFresh({}, {}, 0, 1000), false);
    assert.equal(api.aiUsageMtimeFresh({}, {}, Number.NaN, 1000), false);
    assert.equal(api.aiUsageMtimeFresh({}, {}, 1000, Number.NaN), false);
});
