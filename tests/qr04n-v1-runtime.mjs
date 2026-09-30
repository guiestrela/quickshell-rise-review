import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const project = resolve(fileURLToPath(new URL("..", import.meta.url)));
const scratch = mkdtempSync(join(process.env.TMPDIR || tmpdir(), "qr04n-v1-"));
const argvLog = join(scratch, "argv.bin");
try {
  const chmod = spawnSync("chmod", ["0755", resolve(project, "tests/fixtures/nordvpn-cli-recording-stub.sh")], { encoding: "utf8" });
  assert.equal(chmod.status, 0, chmod.stderr);
  const run = spawnSync("qs", ["--path", resolve(project, "tests/qml/qr04n-v1-wiring.qml"), "--verbose"], {
    encoding: "utf8", timeout: 24000,
    env: { ...process.env, QR04N_ARGV_LOG: argvLog, DISPLAY: undefined }
  });
  const output = `${run.stdout ?? ""}${run.stderr ?? ""}`;
  assert.equal(run.error, undefined, `Quickshell runner error: ${run.error}`);
  assert.equal(run.status, 0, `Quickshell rc ${run.status}; output:\n${output}`);
  assert.match(output, /QR04N_V1_WIRING_QML_PASS real widget\/panel\/controller/, `missing runtime marker:\n${output}`);
  const lines = readFileSync(argvLog).toString("utf8").split("\n").filter(Boolean);
  const argv = lines.map(line => line.split("\0").filter(Boolean));
  const actionArgv = argv.filter(args => ["connect", "disconnect", "pause", "set"].includes(args[0]));
  assert.deepEqual(actionArgv, [
    ["connect"], ["disconnect"], ["connect", "Canada"], ["pause", "15m"],
    ["set", "firewall", "off"], ["set", "killswitch", "on"],
    ["set", "autoconnect", "off"], ["set", "technology", "OpenVPN"]
  ], `recorded argv: ${JSON.stringify(argv)}`);
  assert.equal(argv[0]?.[0], "status", "first CLI call must be the single shared status query");
  assert.equal(argv[1]?.[0], "settings", "initial cycle must query settings exactly once after status");
  assert.ok(argv.filter(args => args[0] === "status").length >= 1);
  assert.equal(argv.filter(args => args[0] === "settings").length >= 1, true);
  console.log("QR04N_V1_RUNTIME_PASS");
  console.log(`QR04N_V1_ARGV_PASS ${JSON.stringify(actionArgv)}`);

  const unavailableLog = join(scratch, "unavailable-argv.bin");
  const unavailable = spawnSync("qs", ["--path", resolve(project, "tests/qml/qr04n-v1-wiring.qml"), "--verbose"], {
    encoding: "utf8", timeout: 8000,
    env: { ...process.env, QR04N_ARGV_LOG: unavailableLog, QR04N_STATUS_MODE: "unavailable", DISPLAY: undefined }
  });
  const unavailableOutput = `${unavailable.stdout ?? ""}${unavailable.stderr ?? ""}`;
  assert.equal(unavailable.error, undefined, `unavailable harness runner error: ${unavailable.error}`);
  assert.equal(unavailable.status, 0, `unavailable harness rc ${unavailable.status}; output:\n${unavailableOutput}`);
  assert.match(unavailableOutput, /QR04N_V1_UNAVAILABLE_QML_PASS/, `missing unavailable marker:\n${unavailableOutput}`);
  const unavailableArgv = readFileSync(unavailableLog).toString("utf8").split("\n").filter(Boolean).map(line => line.split("\0").filter(Boolean));
  assert.deepEqual(unavailableArgv.slice(0, 2), [["status"], ["settings"]]);
  assert.equal(unavailableArgv.some(args => ["connect", "disconnect", "pause", "set"].includes(args[0])), false, "unavailable case emitted a mutating CLI call");
  console.log("QR04N_V1_UNAVAILABLE_PASS");
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
