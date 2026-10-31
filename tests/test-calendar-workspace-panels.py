#!/usr/bin/env python3
"""Calendar/workspace panel bindings with inert processes and fake compositor.

--native checks hidden PanelWindows only; it never reads account state or
executes calendar commands, even during Component.onCompleted.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
native = '--native' in sys.argv
with tempfile.TemporaryDirectory(prefix='rise-calendar-workspace-', dir='/tmp') as directory:
    temp = Path(directory)
    runtime = temp / 'runtime'
    runtime.mkdir(mode=0o700)
    for variant, path in [('V1','versions/V1'),('V2','versions/V1/variants/V2')]:
        folder = temp / variant
        panels, modules = folder / 'panels', folder / 'modules'
        panels.mkdir(parents=True)
        modules.mkdir()
        model = repo / 'versions/V1/integrations/google-calendar/CalendarModel.js'
        (folder / 'CalendarModel.js').write_bytes(model.read_bytes())
        texts = []
        for name in ['CalendarPopup','WorkspacePanel']:
            text = (repo / path / 'panels' / f'{name}.qml').read_text()
            texts.append(text)
            text = text.replace('import Quickshell.Hyprland','import "."')
            text = text.replace('Hyprland.workspaces','FixtureHyprland.workspaces').replace(
                'Hyprland.focusedWorkspace','FixtureHyprland.focusedWorkspace')
            text = re.sub(r'^import ".*CalendarModel.js" as CalendarModel$',
                          'import "../CalendarModel.js" as CalendarModel',text,flags=re.M)
            text = text.replace('Process {','InertProcess {').replace('StdioCollector {','InertCollector {')
            if not native:
                text = re.sub(r'^import Quickshell(?:\.[A-Za-z.]+)?\n','',text,flags=re.M)
                text = text.replace('PanelWindow {','Rectangle {\n    width: 800; height: 900\n    property var screen',1)
                text = re.sub(r'^    (?:anchors \{ top:|exclusionMode:|WlrLayershell\.).*\n','',text,flags=re.M)
            text = text.replace('id: card\n','id: card; objectName: "card"\n')
            text = text.replace('id: workspaceRow\n','id: workspaceRow; objectName: "workspace-" + modelData.id\n')
            for identity in ['calendarEventsProc','calendarActionProc','calendarMutateProc']:
                text = text.replace('id: '+identity+'\n','id: '+identity+'; objectName: "'+identity+'"\n')
            (panels / f'{name}.qml').write_text(text)
        for name in ['UiText','PillShadow','SidePanelPositioner']:
            (modules / f'{name}.qml').write_bytes((repo / path / 'modules' / f'{name}.qml').read_bytes())
        (modules / 'ConnectedPanelSurface.qml').write_text('''import QtQuick
Item { property var root; property bool ownerActive; property real targetX; property real reveal }
''')
        (panels / 'InertProcess.qml').write_text('''import QtQuick
QtObject { property var command: []; property bool running: false; property var stdout; property var stderr; signal exited(int exitCode) }
''')
        (panels / 'InertCollector.qml').write_text('''import QtQuick
QtObject { property string text: ""; signal streamFinished() }
''')
        (panels / 'qmldir').write_text('singleton FixtureHyprland 1.0 FixtureHyprland.qml\nCalendarPopup CalendarPopup.qml\nWorkspacePanel WorkspacePanel.qml\nInertProcess InertProcess.qml\nInertCollector InertCollector.qml\n')
        (panels / 'FixtureHyprland.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property var focusedWorkspace: ({id: 1})
    property var workspaces: [{id:1,toplevels:{values:[]}},{id:2,toplevels:{values:[]}},{id:-99,toplevels:{values:[]}}]
}
''')
        fields = set(re.findall(r'\b(?:calPopup|wsPanel)\.root\.(\w+)','\n'.join(texts)))
        colors = {'bg','fillActive','fillHover','fillIdle','ink','inkDeep','paper','pillBorder','seal','sep',
                  'sumi','sumiHi','panelBorder','color01'}
        strings = {'barPosition':'top','mono':'monospace','calendarMonthName':'Fixture Month'}
        theme = ['property int selectedWorkspace: 0','function gotoWorkspace(id) { selectedWorkspace = id }']
        for field in sorted(fields):
            if field == 'gotoWorkspace':
                continue
            if field == 'activePopupScreen':
                value = 'Quickshell.screens[0]' if native else '({width:800,height:900})'
                theme.append(f'property var {field}: {value}')
            elif field == 'calendarCells':
                theme.append('property var calendarCells: [{day:1,today:true},{day:2,today:false},{day:0,today:false}]')
            elif field in colors:
                theme.append(f'property color {field}: "#999999"')
            elif field in strings:
                theme.append(f'property string {field}: {json.dumps(strings[field])}')
            elif field.endswith('Visible'):
                theme.append(f'property bool {field}: false')
            else:
                value = 0 if field == 'calendarMonthOffset' else 1 if field == 'selectedDay' else 2026 if field == 'calendarYear' else 6
                theme.append(f'property int {field}: {value}')
        theme += ['property bool barVertical: false','property real verticalBarWidth: 40',
                  'property bool styleShadow: false','property color pillShadow: "black"',
                  'function verticalAnchorY(name) { return 200 }']
        if native:
            qml = '''import QtQuick
import Quickshell
import "VARIANT/panels"
Scope {
    QtObject { id: theme; THEME }
    CalendarPopup { id: calendar; root: theme }
    WorkspacePanel { id: workspace; root: theme }
    Timer { interval: 100; running: true; onTriggered: {
        if(calendar.visible || workspace.visible) { Qt.exit(1); return }
        console.log("CALENDAR_WORKSPACE_HIDDEN_PASS VARIANT"); Qt.exit(0)
    } }
}
'''
        else:
            qml = '''import QtQuick
import QtTest
import "VARIANT/panels"
Item {
    width: 800; height: 900
    QtObject { id: theme; THEME }
    CalendarPopup { id: calendar; root: theme }
    WorkspacePanel { id: workspace; root: theme }
    function mouse(item) {
        for(var child of item.children) if(typeof child.clicked === "function") return child
        return null
    }
    TestCase {
        name: "CalendarWorkspaceVARIANT"; when: windowShown
        function test_events_confirmation_and_navigation() {
            var reader = findChild(calendar,"calendarEventsProc")
            var event = {uid:"fixture-event",instance_id:"fixture-event__1",calendar:"fixture",
                title:"Fixture event",start:calendar.agendaDateKey,all_day:true}
            reader.stdout.text = JSON.stringify({ok:true,events:[event]})
            reader.stdout.streamFinished()
            compare(calendar.agendaEvents.length,1)
            compare(calendar.agendaEvents[0].title,"Fixture event")
            var action = findChild(calendar,"calendarActionProc")
            calendar.pushGoogleCalendar()
            verify(calendar.calendarPushArmed);compare(action.running,false)
            calendar.pushGoogleCalendar()
            compare(calendar.calendarPushArmed,false);compare(action.running,true)
            compare(action.command[1],"--confirm")
            var mutation = findChild(calendar,"calendarMutateProc")
            calendar.deleteEvent(event);compare(mutation.running,false)
            calendar.deleteEvent(event);compare(mutation.running,true)
            compare(mutation.command.slice(1),["delete","instance","fixture","fixture-event","fixture-event__1","--confirm"])
            theme.workspaceVisible = true
            tryCompare(workspace,"visible",true)
            var target = findChild(workspace,"workspace-2")
            mouseClick(mouse(target),5,5)
            compare(theme.selectedWorkspace,2);compare(theme.workspaceVisible,false)
            compare(findChild(workspace,"workspace--99").visible,false)
            for(var entry of [[calendar,"calendarVisible"],[workspace,"workspaceVisible"]]) {
                theme[entry[1]] = true
                tryCompare(entry[0],"visible",true)
                findChild(entry[0],"card").forceActiveFocus()
                keyClick(Qt.Key_Escape)
                compare(theme[entry[1]],false)
            }
        }
    }
}
'''
        qml = qml.replace('VARIANT',variant).replace('THEME','\n'.join(theme))
        probe = temp / f'{"native" if native else "tst"}_{variant}.qml'
        probe.write_text(qml)
        env = dict(os.environ,QT_QUICK_BACKEND='software',QT_QPA_PLATFORMTHEME='')
        if native:
            env['QT_QPA_PLATFORM'] = 'wayland'
            command = ['qs','-p',str(probe)]
        else:
            env.update(QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=str(runtime))
            command = ['/usr/lib/qt6/bin/qmltestrunner','-input',str(probe)]
        result = subprocess.run(command,env=env,capture_output=True,text=True,timeout=15)
        output = result.stdout + result.stderr
        print(output,end='')
        if result.returncode:
            raise SystemExit(result.returncode)
        if native:
            assert 'CALENDAR_WORKSPACE_HIDDEN_PASS' in output,output
        assert not any(error in output for error in (
            'ReferenceError','TypeError','Binding loop','Unable to assign',' ERROR')),output
