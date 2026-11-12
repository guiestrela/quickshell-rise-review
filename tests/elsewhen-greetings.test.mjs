import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const Greetings = require("../shared/integrations/elsewhen/Greetings.js");

test("greeting uses the zone language and local-hour band", () => {
  assert.deepEqual(Greetings.greeting("Europe/Paris", 9), {
    text: "Bonjour", roman: "", language: "French", key: "fr"
  });
  assert.equal(Greetings.greeting("Europe/Paris", 18).text, "Bonsoir");
  assert.equal(Greetings.greeting("Europe/Paris", 22).text, "Bonne nuit");
});

test("non-Latin local greetings include a pronunciation", () => {
  assert.deepEqual(Greetings.greeting("Asia/Tokyo", 17), {
    text: "こんにちは", roman: "konnichiwa", language: "Japanese", key: "ja"
  });
});
