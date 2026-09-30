import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const project = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const helperPath = resolve(project, "versions/V1/modules/NordVpnLayout.js");
assert.ok(existsSync(helperPath), "shared slot migration/reorder helper is not implemented");
const source = readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*/m, "");
const sandbox = {};
runInNewContext(`${source}\nglobalThis.api = { migrateV1Order, migrateV2Entries, swapModels };`, sandbox);
const api = sandbox.api;

function model(entries) {
  return {
    entries: entries.map((entry) => ({ ...entry })),
    get count() { return this.entries.length; },
    get(index) { return this.entries[index]; },
    setProperty(index, name, value) { this.entries[index][name] = value; },
  };
}

test("V1 appends G16 to a valid legacy cache without moving old widgets", () => {
  const left = ["G1", "G2", "G3", "G4", "G5", "G6", "G7"];
  const center = ["G8"];
  const right = ["G9", "G10", "G11", "G14", "G12", "G13", "G15"];
  const migrated = api.migrateV1Order(left, center, right);
  assert.deepEqual(Array.from(migrated.right), [...right, "G16"]);
  assert.deepEqual(Array.from(migrated.left), left);
  assert.equal(api.migrateV1Order(left, center, ["G9"]), null);
});

test("V2 adds G19 to a vacant slot and retains each slot's base/extra class", () => {
  const left = [1, 2, 3, 4, 5, 6, 7].map((n) => ({ gid: `G${n}`, extra: false }));
  const center = [{ gid: "G8", extra: false }];
  const right = [9, 10, 11, 12, 13, 14, 15, 16, 17, 18].map((n) => ({ gid: `G${n}`, extra: n > 15 }));
  right.push({ gid: "", extra: true });
  const migrated = api.migrateV2Entries(left, center, right);
  assert.equal(migrated.right[10].gid, "G19");
  assert.equal(migrated.right[10].extra, true);
  assert.equal(right[10].gid, "");
  assert.equal(api.migrateV2Entries(left, center, right.slice(0, -1)), null);
  const currentRight = right.slice(0, -1).concat([{ gid: "G19", extra: true }]);
  const current = api.migrateV2Entries(left, center, currentRight);
  assert.equal(current.right[10].gid, "G19");
});

test("the existing cross-slot drag swap preserves slot metadata", () => {
  const left = model([{ gid: "G19", extra: true }]);
  const right = model([{ gid: "G11", extra: false }]);
  api.swapModels(left, right, 0, 0);
  assert.deepEqual(left.entries, [{ gid: "G11", extra: true }]);
  assert.deepEqual(right.entries, [{ gid: "G19", extra: false }]);
});
