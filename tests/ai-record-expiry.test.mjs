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

test('future mtimes and a backwards clock are not fresh', () => {
    assert.equal(api.aiUsageMtimeFresh({}, {}, 1001, 1000), false);
    assert.equal(api.aiUsageMtimeFresh({}, {}, 0, 1000), false);
    assert.equal(api.aiUsageMtimeFresh({}, {}, Number.NaN, 1000), false);
    assert.equal(api.aiUsageMtimeFresh({}, {}, 1000, Number.NaN), false);
});

test('invalid TTL values fail closed', () => {
    for (const ttl of [0, -1, Number.NaN, Number.POSITIVE_INFINITY, -Infinity, null, 'invalid']) {
        assert.equal(api.aiUsageMtimeFresh({}, {}, 1000, 1001, ttl), false, `TTL ${ttl}`);
    }
    assert.equal(api.aiUsageMtimeFresh({}, {}, 1000, 1899.999, 900), true);
});

const providers = [
    { id: 'Claude', cache: 'claude-usage.json', freshField: 'aiClFresh' },
    { id: 'Codex', cache: 'codex-usage.json', freshField: 'aiCxFresh' },
    { id: 'OpenCode', cache: 'opencode-usage.json', freshField: 'aiOcFresh' },
    { id: 'Copilot', cache: 'copilot-usage.json', freshField: 'aiCpFresh' },
];

function balancedBlock(source, openIndex) {
    let depth = 0;
    let quote = null;
    let escaped = false;
    let lineComment = false;
    let blockComment = false;
    for (let i = openIndex; i < source.length; i += 1) {
        const ch = source[i];
        const next = source[i + 1];
        if (lineComment) {
            if (ch === '\\n') lineComment = false;
            continue;
        }
        if (blockComment) {
            if (ch === '*' && next === '/') { blockComment = false; i += 1; }
            continue;
        }
        if (quote) {
            if (escaped) escaped = false;
            else if (ch === '\\\\') escaped = true;
            else if (ch === quote) quote = null;
            continue;
        }
        if (ch === '/' && next === '/') { lineComment = true; i += 1; continue; }
        if (ch === '/' && next === '*') { blockComment = true; i += 1; continue; }
        if (ch === '\\"' || ch === "'" || ch === '`') { quote = ch; continue; }
        if (ch === '{') depth += 1;
        else if (ch === '}' && --depth === 0) return source.slice(openIndex + 1, i);
    }
    throw new Error(`Unbalanced QML block at ${openIndex}`);
}

function providerReader(themeSource, provider) {
    const idIndex = themeSource.indexOf(`id: aiRead${provider.id}`);
    assert.notEqual(idIndex, -1, `${provider.id}: reader id`);
    const processStart = themeSource.lastIndexOf('Process {', idIndex);
    const processOpen = themeSource.indexOf('{', processStart);
    const processBody = balancedBlock(themeSource, processOpen);
    const handlerIndex = processBody.indexOf('onStreamFinished:');
    assert.notEqual(handlerIndex, -1, `${provider.id}: completion callback`);
    const handlerOpen = processBody.indexOf('{', handlerIndex);
    return { processBody, handler: balancedBlock(processBody, handlerOpen) };
}

test('each provider callback recomputes freshness at its last read independently', () => {
    const payload = JSON.stringify({
        '5h-utilization': 0.25,
        '7d-utilization': 0.4,
        schemaVersion: 3,
        _source: 'local',
        buckets: [{ id: 'codex', isGeneral: true, windows: [{ minutes: 300, utilization: 0.25 }] }],
    });
    for (const { variant, source: themeSource } of themes) {
        for (const provider of providers) {
            const { processBody, handler } = providerReader(themeSource, provider);
            assert.ok(processBody.includes(`.cache/${provider.cache}`), `${variant}/${provider.id}: isolated cache path`);
            assert.ok(handler.includes('ThemeAiUsage.aiUsageMtimeFresh(theme, {}, mtime, Date.now() / 1000)'), `${variant}/${provider.id}: current reader clock`);
            const fields = providers.map((entry) => entry.freshField);
            const owner = Object.fromEntries(fields.map((field) => [field, field !== provider.freshField]));
            owner.aiPct = (value) => Math.round((Number(value) || 0) * 100);
            owner.aiWindowLabel = (minutes) => api.aiWindowLabel(owner, {}, minutes);
            owner.aiCodexWindowFromCache = (window) => api.aiCodexWindowFromCache(owner, {}, window);
            owner.aiCodexWindowsFromArray = (windows) => api.aiCodexWindowsFromArray(owner, {}, windows);
            owner.aiCodexLegacyWindowsFromCache = (data) => api.aiCodexLegacyWindowsFromCache(owner, {}, data);
            owner.aiCodexBucketsFromCache = (data) => api.aiCodexBucketsFromCache(owner, {}, data);
            owner.aiCodexGeneralBucket = (buckets) => api.aiCodexGeneralBucket(owner, {}, buckets);
            owner.aiPlanLabel = (plan) => api.aiPlanLabel(owner, {}, plan);
            owner.aiApplyCodexCache = (data, ageOk) => api.aiApplyCodexCache(owner, {}, data, ageOk);
            owner.aiResetCodexUsage = () => { owner.aiCxFresh = false; };
            owner.aiApplyCopilotCache = (data, ageOk) => api.aiApplyCopilotCache(owner, {}, data, ageOk);
            owner.aiResetCopilotUsage = () => { owner.aiCpFresh = false; };
            let nowMs = 1899999;
            const context = vm.createContext({
                Date: { now: () => nowMs },
                ThemeAiUsage: api,
                theme: owner,
            });
            const callback = vm.runInContext(`(function() { ${handler} })`, context);
            callback.call({ text: `1000${String.fromCharCode(10)}${payload}` });
            assert.equal(owner[provider.freshField], true, `${variant}/${provider.id}: fresh at last read`);
            for (const field of fields.filter((name) => name !== provider.freshField))
                assert.equal(owner[field], true, `${variant}/${provider.id}: leaves ${field} unchanged`);

            nowMs = 1900000;
            callback.call({ text: `1000${String.fromCharCode(10)}${payload}` });
            assert.equal(owner[provider.freshField], false, `${variant}/${provider.id}: expires when reader clock advances`);
            for (const field of fields.filter((name) => name !== provider.freshField))
                assert.equal(owner[field], true, `${variant}/${provider.id}: stale result is provider-local`);

            callback.call({ text: `1900${String.fromCharCode(10)}${payload}` });
            assert.equal(owner[provider.freshField], true, `${variant}/${provider.id}: refreshed file is fresh on next read`);
        }
    }
});
