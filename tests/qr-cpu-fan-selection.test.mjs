import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const qml = fs.readFileSync('versions/V1/modules/FanControl.qml', 'utf8');
const handler = qml.slice(qml.indexOf('    onActiveChanged: {') + '    onActiveChanged: '.length,
    qml.indexOf('    Component.onCompleted:'));

test('closing and reopening preserves the selected fan mode and live controller', () => {
    for (const mode of ['silent', 'standard', 'performance', 'full', 'manual']) {
        let starts = 0;
        const context = vm.createContext({active: false, currentMode: mode,
            pendingMode: '', backend: {stdinEnabled: true, running: true},
            start() { starts++; }});
        vm.runInContext(handler, context);
        assert.equal(context.backend.stdinEnabled, true);
        context.active = true;
        vm.runInContext(handler, context);
        assert.equal(starts, 1);
        assert.equal(context.backend.running, true);
        assert.equal(context.currentMode, mode);
        assert.equal(context.backend.stdinEnabled, true);
    }
});

test('closing without a selected mode stops discovery and cancels pending requests', () => {
    const context = vm.createContext({active: false, currentMode: '',
        pendingMode: 'silent', backend: {stdinEnabled: true}});
    vm.runInContext(handler, context);
    assert.equal(context.pendingMode, '');
    assert.equal(context.backend.stdinEnabled, false);
});
