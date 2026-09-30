// Compile-free regression for the Copilot branch of the AI usage cache parse.
// Extracts the real functions out of a Theme.qml and runs them against a cache
// fixture, so the widget's view of Copilot is pinned without needing a live bar.
//
// Usage: node tests/qr04n-copilot-parse.mjs <Theme.qml> <copilot-usage.json>
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const [themePath, cachePath] = process.argv.slice(2);
if (!themePath || !cachePath) {
  console.error("usage: node qr04n-copilot-parse.mjs <Theme.qml> <copilot-usage.json>");
  process.exit(2);
}

const src = readFileSync(themePath, "utf8");

// Pull one top-level `function name(...) { ... }` out of the QML source.
function grab(name) {
  const start = src.indexOf(`function ${name}(`);
  assert.ok(start >= 0, `function ${name}() is missing from ${themePath}`);
  let depth = 0;
  for (let j = src.indexOf("{", start); j < src.length; j++) {
    if (src[j] === "{") depth++;
    else if (src[j] === "}" && --depth === 0) return src.slice(start, j + 1);
  }
  throw new Error(`could not extract function ${name}()`);
}

const NAMES = ["aiPct", "aiWindowLabel", "aiCodexWindowFromCache", "aiCodexWindowsFromArray",
               "aiResetCopilotUsage", "aiApplyCopilotCache"];
const body = NAMES.map(grab).join("\n");

// The extracted functions call each other through `theme.`, mirroring how QML
// resolves sibling methods on the Theme object.
const theme = {};
for (const name of NAMES) {
  theme[name] = new Function("theme", `${body}; return ${name};`)(theme);
}

const live = JSON.parse(readFileSync(cachePath, "utf8"));

// ── the live cache: Copilot is a monthly window, not 5h/7d ──
theme.aiApplyCopilotCache(live, true);
assert.equal(theme.aiCpHas, true, "cache should register as having data");
assert.equal(theme.aiCpFresh, true);
assert.equal(theme.aiCpLabel, "30d", "the monthly window must be labelled 30d");
assert.equal(theme.aiCpResetTs, live.windows[0].reset, "reset timestamp must pass through");
assert.ok(theme.aiCpResetTs > 0);
assert.equal(theme.aiCpCreditsUsed, live._credits_used);
assert.equal(theme.aiCpCreditsEntitlement, live._credits_entitlement);
assert.equal(theme.aiCpStatus, live.status);
assert.equal(theme.aiCpPct, Math.min(100, Math.round(live.windows[0].utilization * 100)));

// ── unlimited: never fabricate a percentage ──
theme.aiApplyCopilotCache({
  windows: [{ minutes: 43200, label: "30d", utilization: 0, reset: 1790812800 }],
  _unlimited: true, _plan: "Individual",
}, true);
assert.equal(theme.aiCpUnlimited, true);
assert.equal(theme.aiCpPct, 0, "an unlimited quota has no usage percentage to chart");

// ── the staleness gate the bar relies on ──
theme.aiApplyCopilotCache({
  windows: [{ minutes: 43200, utilization: 1, reset: 1790812800 }], _source: "stale",
}, true);
assert.equal(theme.aiCpFresh, false, "_source=stale must not count as fresh");
theme.aiApplyCopilotCache(live, false);
assert.equal(theme.aiCpFresh, false, "an old mtime must not count as fresh");

// ── buckets fallback when the flat windows array is absent ──
theme.aiApplyCopilotCache({ buckets: [{ id: "copilot", windows: live.windows }] }, true);
assert.equal(theme.aiCpHas, true, "must fall back to buckets[0].windows");
assert.equal(theme.aiCpPct, 100);

// ── a broken/empty cache has to zero everything, never leave a stale number ──
theme.aiApplyCopilotCache({}, true);
assert.equal(theme.aiCpHas, false);
assert.equal(theme.aiCpPct, 0);
assert.equal(theme.aiCpCreditsUsed, 0);
assert.equal(theme.aiCpCreditsEntitlement, 0);
assert.equal(theme.aiCpResetTs, 0);
theme.aiApplyCopilotCache(null, true);
assert.equal(theme.aiCpHas, false);

// ── F15: out-of-range utilization must clamp, not overflow the bars ──
theme.aiApplyCopilotCache({ windows: [{ minutes: 43200, utilization: 1.8, reset: 1 }] }, true);
assert.equal(theme.aiCpPct, 100);
theme.aiApplyCopilotCache({ windows: [{ minutes: 43200, utilization: -3, reset: 1 }] }, true);
assert.equal(theme.aiCpPct, 0);

console.log("QR04N_COPILOT_PARSE_PASS");