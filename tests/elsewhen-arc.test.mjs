import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../shared/integrations/elsewhen/Arc.js", import.meta.url), "utf8");
const context = { module: { exports: {} } };
vm.runInNewContext(source, context, { filename: "Arc.js" });
const Arc = context.module.exports;

test("arc layout centers glyphs and turns end glyphs along a shallow crown", () => {
  const result = Arc.layout([10, 10, 10], 6, false);
  assert.equal(result.chars.length, 3);
  assert.ok(result.width > 0);
  assert.ok(result.height > 0);
  assert.equal(result.chars[1].rotation, 0);
  assert.ok(result.chars[0].rotation < 0);
  assert.ok(result.chars[2].rotation > 0);
  assert.ok(result.chars[0].y > result.chars[1].y);
  assert.ok(result.chars[2].y > result.chars[1].y);
});

test("flat and empty arc layouts have stable zero-curvature geometry", () => {
  const flat = Arc.layout([8, 9, 7], 0, false);
  assert.equal(flat.width, 24);
  assert.equal(flat.height, 0);
  assert.deepEqual(JSON.parse(JSON.stringify(flat.chars)), [
    { x: 0, y: 0, rotation: 0 },
    { x: 8, y: 0, rotation: 0 },
    { x: 17, y: 0, rotation: 0 },
  ]);
  assert.deepEqual(JSON.parse(JSON.stringify(Arc.layout([], 6, false))), {
    width: 0, height: 0, chars: [],
  });
});

test("excessive rise is clamped to finite, sub-right-angle glyph turns", () => {
  const result = Arc.layout([8, 9, 7], 1e9, false);
  assert.ok(Number.isFinite(result.width) && Number.isFinite(result.height));
  assert.ok(result.chars.every(char => Number.isFinite(char.x)
    && Number.isFinite(char.y) && Math.abs(char.rotation) < 90));
});
