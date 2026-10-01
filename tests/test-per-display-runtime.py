from pathlib import Path
import json, os, subprocess, re, struct, zlib, sys
base=Path(__file__).resolve().parent.parent
fixtures=base/'tests/fixtures'
A=fixtures/'folder A'; B=fixtures/'folder B'; C=fixtures/'folder C'
def png():
    chunk=lambda kind,data: struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\xff\x00\x00'))+chunk(b'IEND',b'')
for folder, files in [(A,['a.png','b.png','nested/excluded.png']),(B,['one.png','nested/two.png']),(C,['new.png','new2.png'])]:
    for f in files:
        p=folder/f;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(png())
def extract(source,name):
    at=source.index('    function '+name+'(');pos=source.index('{',at)+1;level=1
    while level:
        if source[pos]=='{':level+=1
        if source[pos]=='}':level-=1
        pos+=1
    return source[at:pos]
qml='''import QtQuick
import QtQuick.Window
import Quickshell
import PROFILE as WallpaperProfile
import WIDGET_MODULE as WallpaperWidgetModule
Scope {
    QtObject {
        id: stub
        property bool modWallpapers: true
        property bool modQuick: false
        property var activePopupScreen: Quickshell.screens[0]
        property bool wallpaperManagerVisible: false
        property string wallpaperManagerTab: "displays"
        property string wallpaperManagerDisplay: "DP-1"
        property var wallpaperOutputs: wallpaperManagerService.liveScreens
        property string wallpaperManagerFolder: ""
        property bool wallpaperRecursive: true
        property int wallpaperShuffleInterval: 0
        property bool wallpaperShuffleOnWake: false
        property bool wallpaperWakeAvailable: true
        property bool wallpaperSessionLocked: false
        property bool wallpaperScreensaverShowing: false
        property var wallpaperManagerSettings: SETTINGS
        property var wallpaperManagerServiceApi: wallpaperManagerService
        property string saved: ""
        property color paper: "#181616"
        property color muted: "#888888"
        property color sep: "#444444"
        property color fillIdle: "#222222"
        property color fillHover: "#333333"
        property color fillActive: "#555555"
        property color widgetIconColor: "white"
        property int tileRadius: 12
        property real wallpaperManagerAnchorX: 150
        property real wallpaperManagerAnchorY: 32
        property color pill: "#222222"
        property color pillBorder: "#555555"
        property int pillBorderW: 1
        property int pillRadius: 12
        property int pillH: 24
        property color seal: "orange"
        property color ink: "white"
        property string mono: "monospace"
        function hideTooltip() {}
        function showTooltip() {}
        function widgetContentColor(gid,fallback) { return fallback }
        function toggleWallpaperManager(screen, owner) {
            if (!wallpaperManagerVisible) {
                activePopupScreen = screen
                wallpaperManagerDisplay = wallpaperManagerSettings.perDisplayConfig ? String(screen.name) : "all"
            }
            wallpaperManagerVisible = !wallpaperManagerVisible
        }
        function wallpaperProfileFor(name) { return WallpaperProfile.configFor(wallpaperManagerSettings,name,"/home/test") }
        function saveWallpaperProfile() { saved=JSON.stringify(wallpaperManagerSettings) }
        THEME_FUNCTIONS
    }
    Window {
        visible: true; width: 300; height: 100
        WallpaperWidgetModule.WallpaperManagerQuickWidget {
            id: managerWidget
            root: stub
            screen: Quickshell.screens[0]
            width: 38; height: 28
        }
    }
    SERVICE_MODULE.WallpaperManagerService { id: wallpaperManagerService; theme: stub; allowWallpaperEffects: false }
    property var panelInstance: null
    property int stage: -1
    property int ticks: 0
    property string priorA: ""
    property string priorB: ""
    function find(item,name) {
        if(item.objectName===name) return item;
        if(item.contentItem) { let q=find(item.contentItem,name);if(q)return q; }
        if(item.children) for(let c of item.children) {let q=find(c,name);if(q)return q;}
        return null;
    }
    function require(ok,msg) { if(!ok) throw Error(msg) }
    Component.onCompleted: {
        let c=Qt.createComponent(PANEL_URL);
        require(c.status===Component.Ready,c.errorString());
        panelInstance=c.createObject(null,{root:stub});require(panelInstance!==null,c.errorString());
    }
    Timer {
        interval: 30; running: true; repeat: true
        onTriggered: {
            try {
                if(++ticks>350) throw Error("scan timeout stage="+stage);
                if(wallpaperManagerService.scanInFlight || wallpaperManagerService.scanJobs.length) return;
                let s=wallpaperManagerService;
                let input=find(panelInstance,"wallpaper-folder");
                if(stage===-1) {
                    require(s.countFor("DP-1")===2 && s.countFor("DP-2")===2,"widget integration started before scanner");
                    managerWidget.handleButton(Qt.LeftButton);
                    require(stub.wallpaperManagerVisible && panelInstance.visible,"widget did not open production panel over service");
                    stage=0;return;
                }
                if(stage===0) {
                    require(s.countFor("DP-1")===2,"A flat scanner count="+s.countFor("DP-1"));
                    require(s.countFor("DP-2")===2,"B recursive scanner count="+s.countFor("DP-2"));
                    require(s.pathFor("DP-1").startsWith(FOLDER_A+"/"),"A pool mixed");
                    require(s.pathFor("DP-2").startsWith(FOLDER_B+"/"),"B pool mixed");
                    priorB=s.pathFor("DP-2");
                    input.text=FOLDER_C; input.textEdited();input.accepted();
                    stage=1;return;
                }
                if(stage===1) {
                    require(s.pathFor("DP-1").startsWith(FOLDER_C+"/"),"A folder change not scanned");
                    require(s.pathFor("DP-2")===priorB,"A change modified B");
                    priorA=s.pathFor("DP-1");
                    find(panelInstance,"wallpaper-display-DP-2").activated();
                    stage=2;return;
                }
                if(stage===2) {
                    require(input.text===FOLDER_B,"SWITCHED_MONITOR_FOLDER_STALE: "+input.text);
                    find(panelInstance,"wallpaper-next").activated();
                    require(s.pathFor("DP-2")!==priorB && s.pathFor("DP-2").startsWith(FOLDER_B+"/"),"Next did not advance DP-2");
                    require(s.pathFor("DP-1")!==priorA && s.pathFor("DP-1").startsWith(FOLDER_C+"/"),"Next did not advance DP-1 too: before="+priorA+" after="+s.pathFor("DP-1")+" pool="+JSON.stringify(s.poolFor("DP-1")));
                    priorA=s.pathFor("DP-1"); // Clear must preserve the post-NextAll selection.
                    find(panelInstance,"wallpaper-clear").activated();
                    stage=3;return;
                }
                if(stage===3) {
                    require(s.countFor("DP-2")===0 && s.pathFor("DP-2")==="","B clear ineffective");
                    require(s.pathFor("DP-1")===priorA && s.countFor("DP-1")===2,"B clear modified A");
                    let restored=JSON.parse(stub.saved);
                    require(WallpaperProfile.configFor(restored,"DP-1","/home/test").folder===FOLDER_C,"persist A lost");
                    require(WallpaperProfile.configFor(restored,"DP-2","/home/test").folder==="","persist B lost");
                    input.text="/unsubmitted";input.textEdited();
                    find(panelInstance,"wallpaper-display-DP-1").activated();
                    input.editingFinished();
                    stage=4;return;
                }
                if(stage===4) {
                    require(stub.wallpaperProfileFor("DP-1").folder===FOLDER_C,"unsaved B draft wrote to A");
                    require(input.text===FOLDER_C,"A field did not restore");
                    console.log("PER_DISPLAY_QML_REAL_SCANNER_PASS");Qt.exit(0);
                }
            } catch(e) { console.warn("PER_DISPLAY_FAIL",e.message);Qt.exit(1); }
        }
    }
}'''
settings={'perDisplayConfig':True,'displayConfig':{'all':{'folder':''},'DP-1':{'folder':str(A),'recursive':False,'mode':'shuffle'},'DP-2':{'folder':str(B),'recursive':True,'mode':'single'}}}
variants=sys.argv[1:] or ['V1','V2']
for variant in variants:
    root=base/'versions/V1'/('variants/V2' if variant=='V2' else '')
    theme=(root/'Theme.qml').read_text()
    q='import "'+str((root/'modules').relative_to(base))+'" as Service\nimport "'+str((root/'modules').relative_to(base))+'" as WallpaperWidgetModule\n'+qml
    replacements={'PROFILE':json.dumps(str((root/'modules/WallpaperProfile.js').relative_to(base))),'WIDGET_MODULE':json.dumps(str((root/'modules').relative_to(base))),'SERVICE_MODULE':'Service','SETTINGS':'('+json.dumps(settings)+')',
      'PANEL_URL':json.dumps((base/'versions/V1/panels/WallpaperManagerQuickPanel.qml').as_uri()),
      'THEME_FUNCTIONS':'\n'.join(extract(theme,n) for n in ['setWallpaperProfile','setWallpaperPerDisplay','nextWallpaper']),
      'FOLDER_A':json.dumps(str(A)),'FOLDER_B':json.dumps(str(B)),'FOLDER_C':json.dumps(str(C))}
    for k,v in replacements.items(): q=q.replace(k,v)
    probe=base/f'per-display-probe-{variant}.qml';probe.write_text(q)
    env=os.environ.copy();env.pop('DISPLAY',None);env.update(QT_QPA_PLATFORM='wayland',QT_QUICK_BACKEND='software',NO_COLOR='1',XDG_RUNTIME_DIR='/run/user/1000',WAYLAND_DISPLAY='wayland-1')
    assert Path('/run/user/1000/wayland-1').is_socket()
    r=subprocess.run(['qs','-n','-p',str(probe)],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=15)
    log=re.sub(r'\x1b\[[0-9;]*[mK]','',r.stdout);(base/f'per-display-runtime-{variant}.log').write_text(log)
    print(variant,log,'RC',r.returncode)
    assert r.returncode==0 and 'PER_DISPLAY_QML_REAL_SCANNER_PASS' in log and 'PER_DISPLAY_FAIL' not in log
    assert not any(x in log for x in ['ReferenceError','TypeError','Unable to assign','Cannot assign'])
