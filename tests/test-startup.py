from pathlib import Path
import os,json,subprocess,re
b=Path(__file__).resolve().parent.parent
home=b/'startup-home'; (home/'.cache/quickshell-rise').mkdir(parents=True,exist_ok=True)
fixture_scope={'__file__':str(b/'tests/test-per-display-runtime.py')}
exec((b/'tests/test-per-display-runtime.py').read_text().split('variants=sys.argv')[0],fixture_scope)
settings={'folder':'','perDisplayConfig':True,'displayConfig':{'all':{'folder':''},'DP-1':{'folder':str(fixture_scope['A']),'recursive':False,'mode':'shuffle','scaling':'actual'},'DP-2':{'folder':str(fixture_scope['B']),'recursive':True,'mode':'shuffle','scaling':'zoom'}}}
(home/'.cache/quickshell-rise/wallpaper-manager.json').write_text(json.dumps(settings))
for v,sub in [('V1','versions/V1'),('V2','versions/V1/variants/V2')]:
 vr=b/sub
 src=(vr/'Theme.qml').read_text()
 start=src.index('    // Optional wallpaper-manager folder.')
 end=src.index('    function setCurrentThemeName(',start)
 block=src[start:end].replace('id: wallpaperManagerService; theme: theme','id: wallpaperManagerService; theme: theme; allowWallpaperEffects: false')
 q='import QtQuick\nimport Quickshell\nimport Quickshell.Io\nimport "'+os.path.relpath(vr/'modules',b)+'"\nimport "'+os.path.relpath(vr/'modules/WallpaperProfile.js',b)+'" as WallpaperProfile\nItem {\n id: theme\n property var variantHost: null\n property string currentBackgroundsPath: ""\n function popupOpened(name) {}\n'+block+'''
 property int ticks:0
 Timer {interval:100;running:true;repeat:true
 onTriggered: {
  if (theme.wallpaperManagerServiceApi.scanInFlight) return;
  let s=theme.wallpaperManagerServiceApi;
  if(s.countFor("DP-1")>0 && s.pathFor("DP-1")!=="" && s.countFor("DP-2")>0 && s.pathFor("DP-2")!=="") {
   console.log("STARTUP_REAL_FILEVIEW_SCANNER_PASS",s.countFor("DP-1"),s.countFor("DP-2"));Qt.exit(0);return
  }
  if(++theme.ticks>35) {console.log("STARTUP_PROFILE_NOT_SCANNED",s.countFor("DP-1"),s.countFor("DP-2"));Qt.exit(1)}
 }
 }
}'''
 p=b/f'startup-{v}.qml';p.write_text(q)
 env=os.environ.copy();env.pop('DISPLAY',None);env.update(HOME=str(home),XDG_RUNTIME_DIR='/run/user/1000',WAYLAND_DISPLAY='wayland-1',QT_QPA_PLATFORM='wayland');env.pop('RISE_WALLPAPER_DIR',None)
 r=subprocess.run(['qs','-n','-p',str(p)],env=env,capture_output=True,text=True,timeout=12)
 log=r.stdout+r.stderr;(b/f'startup-{v}.log').write_text(log)
 print(v,'rc',r.returncode,log)
 assert r.returncode==0 and 'STARTUP_REAL_FILEVIEW_SCANNER_PASS' in log
