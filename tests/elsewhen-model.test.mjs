import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const read = path => readFileSync(new URL(`../shared/integrations/elsewhen/${path}`, import.meta.url), "utf8");
function loadModule(path) {
  const context = { module: { exports: {} } };
  vm.runInNewContext(read(path).replace(/^\.pragma library\s*/m, ""), context, { filename: path });
  return context.module.exports;
}

const Model = loadModule("Model.js");
const Globe = loadModule("GlobeModel.js");

test("city settings preserve names, IANA zones, coordinates, regions, and legacy fields", () => {
  const input = [{ name: "San Francisco", zone: "America/Los_Angeles", lat: 37.7749, lon: -122.4194, region: "CA" }];
  const parsed = Model.parseCities(input, "");
  assert.deepEqual(JSON.parse(JSON.stringify(parsed)), [{ label: "San Francisco", id: "America/Los_Angeles", lat: 37.7749, lon: -122.4194, region: "CA" }]);
  assert.deepEqual(JSON.parse(JSON.stringify(Model.serializeCities(parsed))), input);
  assert.deepEqual(JSON.parse(JSON.stringify(Model.parseCities([], "Paris|Europe/Paris,Asia/Tokyo"))), [
    { label: "Paris", id: "Europe/Paris" },
    { label: "Tokyo", id: "Asia/Tokyo" },
  ]);
});

test("time-zone probe fixtures produce stable city clock rows", () => {
  const zones = Model.parseCities([
    { name: "Tokyo", zone: "Asia/Tokyo" },
    { name: "Paris", zone: "Europe/Paris" },
  ], "");
  const probe = Model.parseProbe("Asia/Tokyo|JST|+0900\nEurope/Paris|CET|+0100\n");
  const rows = Model.rows(zones, probe, Date.UTC(2026, 0, 1, 12, 0), 0, true);
  assert.deepEqual(JSON.parse(JSON.stringify(rows.map(row => [row.id, row.abbr, row.offsetMinutes, row.hour]))), [
    ["Asia/Tokyo", "JST", 540, 21],
    ["Europe/Paris", "CET", 60, 13],
  ]);
  assert.equal(Model.utcOffsetLabel(330), "UTC+5:30");
});

test("offline city search combines IANA zones and named-city aliases without duplicates", () => {
  const options = Model.zoneOptions("America/New_York\nEurope/Paris\n", []);
  assert.ok(options.some(option => option.value === "America/New_York"));
  assert.ok(options.some(option => option.label === "Miami" && option.value === "America/New_York"));
  assert.equal(Model.searchZones(options, "tokyo", 6)[0].value, "Asia/Tokyo");
  assert.ok(!Model.zoneOptions("America/New_York\n", [{ label: "New York", id: "America/New_York" }])
    .some(option => option.label === "New York" && option.value === "America/New_York"));
});

test("place search parses geocoder results and merges offline matches without losing coordinates", () => {
  assert.equal(Model.placeQuery("  Springfield   Illinois  "), "springfield illinois");
  assert.equal(Model.placeQuery("LA"), "");
  const payload = JSON.stringify({ results: [{
    name: "Springfield", admin1: "Illinois", country_code: "US",
    timezone: "America/Chicago", latitude: 39.78, longitude: -89.64,
  }] });
  const places = Model.placeOptions(payload);
  assert.deepEqual(JSON.parse(JSON.stringify(places)), [{
    label: "Springfield", value: "America/Chicago", lat: 39.78, lon: -89.64, region: "Illinois, US",
  }]);
  const merged = Model.mergePlaces([{ label: "Springfield", value: "America/Chicago" }], places, [], 8);
  assert.equal(merged.length, 1);
  assert.equal(merged[0].lat, 39.78);
  assert.equal(Model.mergePlaces([], places, [{ id: "America/Chicago", lat: 39.78, lon: -89.64 }], 8).length, 0);
  assert.deepEqual(JSON.parse(JSON.stringify(Model.placeOptions("not json"))), []);
});

test("city edits preserve order and the final clock", () => {
  const cities = Model.parseCities([
    { name: "Paris", zone: "Europe/Paris" },
    { name: "Tokyo", zone: "Asia/Tokyo" },
  ], "");
  const moved = Model.moveZone(cities, 0, 1);
  assert.deepEqual(JSON.parse(JSON.stringify(moved.map(city => city.label))), ["Tokyo", "Paris"]);
  assert.equal(Model.removeZoneAt(moved, 0).length, 1);
  assert.equal(Model.removeZoneAt(Model.removeZoneAt(moved, 0), 0).length, 1);
});

test("timezone action builder keeps the selected IANA zone as a distinct argument", () => {
  const argv = Model.timezoneCommand("Europe/Paris");
  assert.equal(argv.at(-1), "Europe/Paris");
  assert.match(argv[2], /timedatectl set-timezone \"\$1\"/);
});

test("geocode command limits the captured response and pins HTTPS transport", () => {
  const argv = Model.geocodeCommand("San Francisco");
  assert.equal(argv[0], "curl");
  assert.ok(argv.includes("--max-filesize"));
  assert.equal(Number(argv[argv.indexOf("--max-filesize") + 1]), 1_048_576);
  assert.ok(argv.includes("--proto"));
  assert.equal(argv[argv.indexOf("--proto") + 1], "=https");
  assert.ok(argv.includes(Model.geocodeUrl("San Francisco")));
});

test("weather fixtures parse temperatures per requested city and reject malformed replies", () => {
  const keys = ["Tokyo|Asia/Tokyo", "Paris|Europe/Paris"];
  const points = [{ lat: 35.68, lon: 139.69 }, { lat: 48.85, lon: 2.35 }];
  const parsed = Model.parseForecast(JSON.stringify([
    { current: { temperature_2m: 18.4, weather_code: 2 } },
    { current: { temperature_2m: -1, weather_code: 71 } },
  ]), keys, 1234, points);
  assert.deepEqual(JSON.parse(JSON.stringify(parsed)), {
    "Tokyo|Asia/Tokyo": { c: 18.4, w: 2, at: 1234, lat: 35.68, lon: 139.69 },
    "Paris|Europe/Paris": { c: -1, w: 71, at: 1234, lat: 48.85, lon: 2.35 },
  });
  assert.deepEqual(JSON.parse(JSON.stringify(Model.parseForecast("bad", keys, 1234, points))), {});
  assert.equal(Model.tempLabel(parsed["Tokyo|Asia/Tokyo"], "F"), "65°F");
});

test("bundled globe data and orthographic projection are usable offline", () => {
  const land = JSON.parse(read("world.json"));
  const cities = JSON.parse(read("cities.json"));
  assert.ok(land.length > 0);
  assert.ok(land.every(ring => Array.isArray(ring) && ring.length >= 8 && ring.length % 2 === 0));
  assert.ok(cities.some(city => city[0] === "Tokyo" && city[1] === "Asia/Tokyo"));
  const center = Globe.project(0, 0, 0, 0, 100);
  assert.equal(center.visible, true);
  assert.ok(Math.abs(center.x) < 1e-9 && Math.abs(center.y) < 1e-9);
  assert.equal(Globe.shortestTurn(350, 10), 20);
  assert.equal(Globe.decimateRing(land[0], 2, 8).length % 2, 0);
});
