from pathlib import Path
import os,subprocess
b=Path(__file__).resolve().parent.parent
for v,sub,gid in [('V1','versions/V1','G17'),('V2','versions/V1/variants/V2','G20')]:
 vr=b/sub;s=(vr/'BarSlot.qml').read_text()
 a=s.index('id: compQuick');z=s.index('id: compNetwork',a)
 assert 'WallpaperManagerQuickWidget' not in s[a:z],v+' STILL_IN_QUICK_TOOLS'
 a=s.index('id: compWallpapers');z=s.index('Component',a)
 assert 'WallpaperManagerQuickWidget' in s[a:z],v+' INDEPENDENT_SLOT_NOT_WIRED'
 assert '"'+gid+'": compWallpapers' in s
 q='''import QtQuick
import Quickshell
import "MODULES" as Modules
Scope {
 QtObject {
  id: stub
  property bool modWallpapers:true
  property bool modQuick:false
  property bool wallpaperManagerVisible:false
  property string mono:"monospace"
  property color ink:"white"
  property color seal:"orange"
  property color pill:"#222222"
  property color pillBorder:"#555555"
  property int pillBorderW:1
  property int pillRadius:12
  property int pillH:24
  property color widgetIconColor:"white"
  property var screen:null
  property string nextOutput:""
  property var openedOwner:null
  property var wallpaperManagerServiceApi: ({ nextAll: function() { stub.nextOutput="all" } })
  function widgetContentColor(gid,fallback) {return fallback}
  function hideTooltip() {}
  function showTooltip() {}
  function nextWallpaper(output) {nextOutput=output}
  function toggleWallpaperManager(screen,owner) {openedOwner=owner;wallpaperManagerVisible=!wallpaperManagerVisible}
 }
 Modules.WallpaperManagerQuickWidget {id: widget;root:stub;screen:({name:"DP-1"});width:implicitWidth;height:implicitHeight}
 Timer {interval:150;running:true;onTriggered:{
  if(widget.implicitWidth<30 || !widget.visible || stub.modQuick) {console.log("INDEPENDENT_SLOT_HIDDEN");Qt.exit(1);return}
  widget.handleButton(Qt.LeftButton);
  if(stub.openedOwner!==widget || !stub.wallpaperManagerVisible) {console.log("ANCHOR_OWNER_MISSING");Qt.exit(1);return}
  widget.handleButton(Qt.MiddleButton);
  if(stub.nextOutput!=="all") {console.log("MIDDLE_CLICK_NOT_NEXT_ALL");Qt.exit(1);return}
  console.log("INDEPENDENT_WIDGET_ACTIONS_PASS");Qt.exit(0)
 }}
}'''.replace('MODULES',os.path.relpath(vr/'modules',b))
 p=b/f'independent-widget-{v}.qml';p.write_text(q)
 env=os.environ.copy();env.pop('DISPLAY',None);env.update(XDG_RUNTIME_DIR='/run/user/1000',WAYLAND_DISPLAY='wayland-1')
 r=subprocess.run(['qs','-n','-p',str(p)],env=env,capture_output=True,text=True,timeout=10)
 log=r.stdout+r.stderr;(b/f'independent-widget-{v}.log').write_text(log);print(v,r.returncode,log)
 assert r.returncode==0 and 'INDEPENDENT_WIDGET_ACTIONS_PASS' in log
