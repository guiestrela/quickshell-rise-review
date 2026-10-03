#!/usr/bin/env python3
"""Updater removal and last-good-state regressions; never apply updates."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GENERATIONS = [ROOT / 'versions/V1', ROOT / 'versions/V1/variants/V2']


class UpdatePanelTests(unittest.TestCase):
    def test_shell_updater_is_removed_from_runtime_and_installation(self):
        for generation in GENERATIONS:
            with self.subTest(generation=generation):
                for relative in ['Theme.qml', 'BarSlot.qml', 'modules/ArchUpdaterWidget.qml', 'panels/ArchUpdaterPanel.qml']:
                    content = (generation / relative).read_text()
                    self.assertNotRegex(content, r'ShellUpdateTab|shellUpdate|shellProgress|archBadgeShell|preferShell|shellFallback')
                panel = (generation / 'panels/ArchUpdaterPanel.qml').read_text()
                models = re.findall(r'model:\s*\[(.*?)\]', panel, re.S)
                tab_models = [re.findall(r'id:\s*"([^"]+)"', model) for model in models if 'id: "packages"' in model]
                self.assertEqual(tab_models, [['packages', 'themes'], ['packages', 'themes']])
                self.assertFalse((generation / 'panels/ShellUpdateTab.qml').exists())
                theme = (generation / 'Theme.qml').read_text()
                self.assertIn('+ "0 "', theme, 'Keep the retired positional preference slot reserved')
        installer = (ROOT / 'install.sh').read_text()
        self.assertNotRegex(installer, r'install_shell_updater|qs-shell-(check|apply|update-check)')
        for relative in ['scripts/qs-shell-check-update.sh', 'scripts/qs-shell-apply-update.sh', 'systemd/qs-shell-update-check.service', 'systemd/qs-shell-update-check.timer']:
            self.assertFalse((ROOT / relative).exists(), relative)
        post_update = (ROOT / 'scripts/qs-shell-post-update.sh').read_text()
        self.assertNotRegex(post_update, r'qs-shell-(check|apply|update-check)')


    def test_packages_keep_last_good_data_and_report_failed_checks(self):
        for generation in GENERATIONS:
            with self.subTest(generation=generation), tempfile.TemporaryDirectory(prefix='rise-update-test-') as temporary:
                work = Path(temporary)
                home = work / 'home'
                binary = home / '.local/bin/qs-arch-update-check.sh'
                binary.parent.mkdir(parents=True)
                binary.write_text(HELPER)
                binary.chmod(0o700)
                probe = work / 'probe.qml'
                probe.write_text(PROBE.replace('@MODULES@', (generation / 'modules').as_uri()))
                env = dict(os.environ, HOME=str(home))
                env.pop('DISPLAY', None)
                result = subprocess.run(['qs', '-p', str(probe)], env=env, capture_output=True, text=True, timeout=15)
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0, output)
                self.assertIn('UPDATE_PANEL_RUNTIME_PASS', output)
                self.assertIsNone(re.search(r'ReferenceError|TypeError|Failed to load configuration|Cannot assign to non-existent', output), output)


HELPER = '''#!/bin/bash
mode=$(cat "$HOME/mode")
case "$mode" in
  failure) printf 'S|wrong-data|1|9\\n'; exit 9 ;;
  malformed) printf 'not a checked scan\\n'; exit 0 ;;
  ok) printf 'M|new-scan|2|fixture-hash|1\\nS|fixture-new|1|2\\n' ;;
  empty) printf 'M|empty-scan|3|fixture-hash|0\\n' ;;
  seed) printf 'M|prior-scan|4|fixture-hash|1\\nS|fixture-system|1|2\\nA|fixture-aur|1|2\\n' ;;
  hang) exec sleep 5 ;;
esac
'''

PROBE = r'''import QtQuick
import Quickshell
import Quickshell.Io
import "@MODULES@" as Actual
Item {
    id: stub
    property bool _widgetsLoaded: true
    property bool modStatus: false
    property bool archVisible: false
    property int archRefreshTick: 0
    property var archUpdates: []
    property string archScanId: ""
    property string archScanHash: ""
    property int archScanCheckedEpoch: 0
    property int archScanSystemCount: 0
    property bool archRefreshing: false
    property string archScanError: ""
    property bool archBadgePackages: true
    property bool archBadgeThemes: true
    property int themeUpdLocalEdits: 0
    property var themeUpdList: [{state: "clean", behind: 3}]
    // Stale legacy values must not influence the new updater.
    property int shellUpdateBehind: 20
    property bool archBadgeShell: true
    property bool shellUpdateProgressVisible: true
    property color ink: "white"
    property color seal: "green"
    property color paper: "black"
    property color sumi: "grey"
    property string mono: "monospace"
    property var tooltipOwner: null
    property string tooltipText: ""
    function showTooltip(text, x, topY, bottomY, owner) { tooltipOwner = owner; tooltipText = text }
    function hideTooltip(owner) {
        if (tooltipOwner === owner) { tooltipOwner = null; tooltipText = "" }
    }
    function widgetContentColor(name, active) { return "white" }
    function widgetHasFill(name) { return false }
    function widgetAssignedColor(name) { return "green" }
    Actual.ArchUpdaterWidget { id: widget; root: stub }
    property int phase: 0
    function fail(message) { console.log("UPDATE_PANEL_RUNTIME_FAIL",message); Qt.exit(1) }
    function require(value, message) { if (!value) { fail(message); return false } return true }
    function startMode(mode) {
        modeWriter.command = ["bash", "-c", "printf '%s' \"$1\" > \"$HOME/mode\"", "fixture", mode]
        modeWriter.running = true
    }
    Process {
        id: modeWriter
        onExited: (code) => {
            if (code !== 0) { stub.fail("fixture mode writer failed"); return }
            widget.doRefresh()
            inspect.start()
        }
    }
    Component.onCompleted: Qt.callLater(function() {
        widget.parseOutput("M|prior-scan|1|fixture-hash|1\nS|fixture-system|1|2\nA|fixture-aur|1|2\n")
        Qt.callLater(function() {
            if (!stub.require(widget.badgeCount === 3, "Legacy Shell must not add a badge")) return
            var area = widget.childAt(widget.width / 2, widget.height / 2)
            if (!stub.require(area !== null, "Cannot locate production widget MouseArea")) return
            area.entered()
            tooltipCheck.start()
        })
    })
    Timer {
        id: tooltipCheck
        interval: 400; repeat: false
        onTriggered: {
            if (!stub.require(stub.tooltipOwner === widget && stub.tooltipText === widget.tooltipText,
                              "MouseArea entered did not show the production tooltip")) return
            var area = widget.childAt(widget.width / 2, widget.height / 2)
            area.exited()
            Qt.callLater(function() {
                if (!stub.require(stub.tooltipOwner === null && stub.tooltipText === "",
                                  "MouseArea exited did not hide the production tooltip")) return
                stub.archBadgePackages = false
                Qt.callLater(function() {
                    if (!stub.require(widget.badgeCount === 1, "Themes badge must remain")) return
                    stub.archBadgeThemes = false
                    Qt.callLater(function() {
                        if (!stub.require(widget.badgeCount === 0, "Both toggles disabled")) return
                        stub.archBadgePackages = true; stub.archBadgeThemes = true
                        stub.startMode("failure")
                    })
                })
            })
        }
    }
    Timer {
        id: inspect
        interval: 30; repeat: true
        onTriggered: {
            if (widget.refreshing) return
            stop()
            if (stub.phase === 0 || stub.phase === 1) {
                if (!stub.require(stub.archUpdates.length === 2, "Failed/malformed check discarded prior package data")) return
                if (!stub.require(stub.archScanId === "prior-scan", "Failed check replaced prior provenance")) return
                if (!stub.require(stub.archScanError.length > 0, "Failed check has no visible error")) return
                if (!stub.require(widget.tooltipText.indexOf(stub.archScanError) >= 0, "Tooltip hides check error")) return
            } else if (stub.phase === 2) {
                if (!stub.require(stub.archUpdates.length === 1 && stub.archScanId === "new-scan", "Successful refresh not published")) return
                if (!stub.require(stub.archScanError === "", "Successful refresh must clear old error")) return
            } else if (stub.phase === 3) {
                if (!stub.require(stub.archUpdates.length === 0 && stub.archScanId === "empty-scan", "Valid empty scan is not accepted")) return
                if (!stub.require(stub.archScanError === "", "Valid empty scan incorrectly failed")) return
            } else if (stub.phase === 4) {
                if (!stub.require(stub.archUpdates.length === 2 && stub.archScanId === "prior-scan",
                                  "Non-empty last-good scan setup failed")) return
                var watchdog = null
                for (var i=0; i<widget.resources.length; i++) {
                    if (widget.resources[i].objectName === "package-refresh-watchdog") watchdog=widget.resources[i]
                }
                if (!stub.require(watchdog !== null, "Watchdog fixture cannot locate production timer")) return
                watchdog.interval = 150
            } else if (stub.phase === 5) {
                if (!stub.require(widget.checkTimedOut === true, "Expected watchdog timeout did not fire")) return
                if (!stub.require(stub.archScanError.indexOf("timed out") >= 0, "Watchdog timeout error was not reported")) return
                if (!stub.require(stub.archUpdates.length === 2 && stub.archScanId === "prior-scan"
                                  && stub.archScanSystemCount === 1,
                                  "Timeout lost non-empty last-good package data or provenance")) return
                if (!stub.require(!widget.refreshing, "Timed-out check did not release the refresh state")) return
                stub.phase++
                stub.startMode("ok")
                return
            } else if (stub.phase === 6) {
                if (!stub.require(stub.archScanId === "new-scan" && stub.archScanError === "", "Refresh after timed-out process was reaped did not succeed")) return
                console.log("UPDATE_PANEL_RUNTIME_PASS"); Qt.exit(0); return
            }
            console.log("UPDATE_PANEL_PHASE_PASS",stub.phase)
            stub.phase++
            stub.startMode(["failure", "malformed", "ok", "empty", "seed", "hang"][stub.phase])
        }
    }
    Timer { interval: 8000; running: true; onTriggered: stub.fail("Probe deadline exceeded") }
}
'''

if __name__ == '__main__':
    unittest.main(verbosity=2)
