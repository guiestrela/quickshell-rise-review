import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../shared/panels/NotificationPanel.qml', import.meta.url), 'utf8');
function panel() {
    const p = {recent: [], dismissed: {}, sessionToken: '', generation: 0, seq: 0,
        root: {_notifOmarchyShellBackend: true}, commands: [],
        saveCache() {}, runNotificationAction(argv) { this.commands.push(argv); }};
    const context = vm.createContext({notifPanel: p});
    for (const name of ['merge', 'dismissOne', 'dismissAll']) {
        const start = source.indexOf(`    function ${name}(`);
        const end = source.indexOf('\n    }', start) + 6;
        p[name] = vm.runInContext('(' + source.slice(start, end) + ')', context);
    }
    return p;
}
const row = (sourceKey, id, timestamp) => ({sourceKey, id, timestamp, backend:'omarchy', summary:'Same title', app_name:'Fixture'});

test('native keys separate reused IDs and survive restart without duplicating history', () => {
    const p = panel();
    p.merge('omarchy-store-v1', [row('n1', 7, 1000)], [row('n2', 7, 2000)], true);
    assert.equal(p.recent.length, 2);
    assert.equal(p.recent[0].sourceKey, 'n2');
    p.dismissOne(p.recent[0]);
    assert.equal(p.commands.length, 0, 'never dismiss unrelated native popups by title');
    p.merge('restarted', [], [row('n1', 7, 1000), row('n2', 7, 2000)], true);
    assert.equal(p.recent.length, 2);
    assert.equal(p.dismissed['omarchy:n2'], true);
    assert.ok(p.recent.every(e => !e.active));
});

test('native retention is authoritative and clear stays cleared across new snapshots', () => {
    const p = panel();
    p.merge('omarchy-store-v1', [row('n1', 1, 1000)], [], true);
    p.dismissAll();
    assert.equal(p.commands.length, 1);
    assert.equal(p.commands[0].join(' '), 'omarchy-shell notifications dismissAll');
    p.merge('omarchy-store-v1', [], [row('n1', 1, 1000)], true);
    assert.equal(p.recent.filter(e => !p.dismissed[e.key]).length, 0);
    p.merge('omarchy-store-v1', [], [], true);
    assert.equal(p.recent.length, 0);
    p.merge('omarchy-store-v1', [row('n2', 1, 3000)], [], true);
    assert.equal(p.recent.filter(e => !p.dismissed[e.key]).length, 1);
});
