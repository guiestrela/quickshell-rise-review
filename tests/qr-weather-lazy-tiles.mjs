import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const project = resolve(fileURLToPath(new URL("..", import.meta.url)));
const variants = [
  ["V1", "versions/V1/modules/WeatherRadar.qml"],
  ["V2", "versions/V1/variants/V2/modules/WeatherRadar.qml"]
];

for (const [name, path] of variants) {
  const qml = readFileSync(resolve(project, path), "utf8");
  assert.match(qml, /readonly property bool tilesActive\s*:\s*root\.weatherVisible/, `${name}: tiles must follow weatherVisible`);
  assert.match(qml, /Repeater\s*\{\s*model\s*:\s*radar\.tilesActive\s*\?\s*9\s*:\s*0/, `${name}: closed panel must not materialize tile delegates`);
  assert.match(qml, /source\s*:\s*radar\.tilesActive\s*&&\s*parent\.visible\s*\?[\s\S]*?:\s*""/, `${name}: Esri URL must be gated`);
  assert.match(qml, /source\s*:\s*!radar\.tilesActive\s*\|\|\s*radar\.radarPath\s*===\s*""\s*\?\s*""\s*:\s*radar\.radarHost/, `${name}: RainViewer URL must be gated`);
  assert.match(qml, /ty\s*>=\s*0\s*&&\s*ty\s*<\s*count/, `${name}: invalid vertical tile rows must stay hidden`);
}
console.log("QR_WEATHER_LAZY_TILES_STATIC_PASS V1+V2");
