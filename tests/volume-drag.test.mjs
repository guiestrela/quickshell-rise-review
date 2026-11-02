import { readQmlSource } from './qml-source.mjs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

for (const variant of ['variants/V1', 'variants/V2']) {
  test(`${variant}: drag serializes commands and applies final position`, () => {
    const source = readQmlSource(`shared/panels/VolumePanel.qml`, 'utf8');
    const code = source.slice(source.indexOf('    function flushOutputVolume()'),
                              source.indexOf('    function setDefaultSink(dev)'));
    const commands = [];
    function runner() {
      let running = false;
      return {
        command: [],
        get running() { return running; },
        set running(value) {
          assert.equal(value, true, 'drag must never cancel a running command');
          assert.equal(running, false, 'commands must not overlap');
          running = value;
          commands.push(Array.from(this.command));
        },
        finish() { running = false; },
      };
    }
    const state = { pendingOutputVolume: -1, pendingMicVolume: -1, micVolume: 0,
                    outputVolumeRunner: runner(), micVolumeRunner: runner() };
    vm.createContext(state);
    vm.runInContext(code, state);
    for (const [setter, flush, process, target] of [
      ['setOutputVolume', 'flushOutputVolume', 'outputVolumeRunner', '@DEFAULT_AUDIO_SINK@'],
      ['setMicVolume', 'flushMicVolume', 'micVolumeRunner', '@DEFAULT_AUDIO_SOURCE@'],
    ]) {
      commands.length = 0;
      state[setter](0.2);
      for (const level of [0.3, 0.4, 0.7, 1.5]) state[setter](level);
      assert.equal(commands.length, 1);
      state[process].finish();
      state[flush]();
      assert.equal(commands.length, 2);
      assert.deepEqual(commands[1], ['timeout', '4', 'wpctl', 'set-volume', target, '1.000']);
      state[process].finish();
      state[flush]();
      assert.equal(commands.length, 2, 'queue drains completely');
      const handler = source.match(new RegExp(`id: ${process}[\\s\\S]*?onExited: function\\(code\\) \\{([\\s\\S]*?)\\n        \\}`))[1];
      const errors = [];
      state.volPanel = { notifyAudioError: (action, status) => errors.push(status), [flush]: state[flush] };
      state[setter](0.1);
      state[setter](0.6);
      state[process].finish();
      state.code = 124;
      vm.runInContext(handler, state);
      assert.deepEqual(errors, [124], 'real failures remain reported');
      assert.equal(commands.at(-1).at(-1), '0.600', 'latest value survives failure');
      state[process].finish();
    }
  });
}
