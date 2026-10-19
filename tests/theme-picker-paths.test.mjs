import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import { spawn } from 'node:child_process';

for (const variant of ['versions/V1', 'versions/V1/variants/V2']) {
  for (const style of ['Panel', 'Hearthstone', 'Carousel']) {
    test(`${variant} ${style}: discovers stock, legacy and personal themes without duplicates`, async () => {
      const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'rise-theme-scan-'));
      try {
        const stock = path.join(tmp, 'stock themes');
        const personal = path.join(tmp, '.config/omarchy/themes');
        const legacy = path.join(tmp, '.local/share/omarchy/themes');
        const preview = dir => {
          fs.mkdirSync(dir, { recursive: true });
          fs.writeFileSync(path.join(dir, 'preview.png'), dir);
        };
        preview(path.join(stock, 'themes/stock-only'));
        preview(path.join(stock, 'themes/override'));
        preview(path.join(personal, 'override'));
        preview(path.join(legacy, 'legacy-only'));
        const cache = path.join(tmp, '.cache/quickshell-theme-picker');
        fs.mkdirSync(cache, { recursive: true });
        fs.symlinkSync('/missing/old-preview.png', path.join(cache, 'override.png'));
        const q = fs.readFileSync(`${variant}/panels/ImageCarousel${style}.qml`, 'utf8');
        const start = q.indexOf('    function buildScanCmd(');
        const end = q.indexOf('    Process { id: applyThemeProc', start);
        const context = vm.createContext({
          isThemeMode: true,
          root: { omarchyInstallRoot: stock },
          panel: { shq: s => "'" + s.replace(/'/g, "'\\''") + "'" }
        });
        vm.runInContext(q.slice(start, end), context);
        const command = Array.from(context.buildScanCmd('theme'));
        const output = await new Promise((resolve, reject) => {
          const child = spawn(command[0], command.slice(1), { env: { ...process.env, HOME: tmp } });
          let text = '', errors = '';
          child.stdout.on('data', data => text += data);
          child.stderr.on('data', data => errors += data);
          child.on('error', reject);
          child.on('close', code => code === 0 ? resolve(text) : reject(new Error(errors)));
        });
        const rows = output.trim().split('\n').map(row => row.split('\t'));
        for (const name of ['stock-only', 'override', 'legacy-only']) {
          const matches = rows.filter(row => path.basename(row[2]) === name);
          assert.equal(matches.length, 1, name);
        }
        assert.equal(rows.find(row => path.basename(row[2]) === 'override')[2], path.join(personal, 'override'));
        assert.equal(fs.realpathSync(path.join(cache, 'override.png')), path.join(personal, 'override/preview.png'));
        if (fs.existsSync('/usr/share/omarchy/themes/kanagawa/preview.png')) {
          assert.ok(rows.some(row => row[2] === '/usr/share/omarchy/themes/kanagawa'));
        }
      } finally {
        fs.rmSync(tmp, { recursive: true, force: true });
      }
    });
  }
}
