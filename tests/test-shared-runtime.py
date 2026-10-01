from pathlib import Path
import subprocess,os,json,re
b=Path(__file__).resolve().parent.parent
scope={'__file__':str(b/'tests/test-per-display-runtime.py')}
exec((b/'tests/test-per-display-runtime.py').read_text().split('variants=sys.argv')[0],scope)
q=scope['qml'];q=q[:q.index('    Timer {')]+'''    Timer {
        interval: 40; running: true; repeat: true
        onTriggered: {
            try {
                if(++ticks>150) throw Error("scanner timeout");
                let s=wallpaperManagerService;
                if(s.scanInFlight||s.scanJobs.length)return;
                require(s.countFor("DP-1")===3 && s.countFor("DP-2")===3,"shared scanner fixture missing");
                let paths=s.poolFor("DP-1");
                s.currentByOutput={"DP-1":paths[0],"DP-2":paths[1]};
                s.queuesByOutput={"DP-1":[paths[2]],"DP-2":[paths[2]]};
                for(let i=0;i<20;i++){
                    s.nextAll();require(s.pathFor("DP-1")!==s.pathFor("DP-2"),"shared next duplicates despite 3 images");
                }
                console.log("SHARED_JOINT_ADVANCE_REAL_QML_SCANNER_PASS");Qt.exit(0);
            }catch(e){console.warn("SHARED_FAIL",e.message);Qt.exit(1);}
        }
    }
}'''
for v in ['V1','V2']:
    root=b/'versions/V1'/('variants/V2' if v=='V2' else '')
    settings={'perDisplayConfig':False,'displayConfig':{'all':{'folder':str(scope['A']),'recursive':True,'mode':'shuffle'}}}
    text='import "'+str((root/'modules').relative_to(b))+'" as Service\n'+q
    for k,val in {'PROFILE':json.dumps(str((root/'modules/WallpaperProfile.js').relative_to(b))),'WIDGET_MODULE':json.dumps(str((root/'modules').relative_to(b))),'SERVICE_MODULE':'Service','SETTINGS':'('+json.dumps(settings)+')','PANEL_URL':json.dumps((b/'versions/V1/panels/WallpaperManagerQuickPanel.qml').as_uri()),'THEME_FUNCTIONS':'\n'.join(scope['extract']((root/'Theme.qml').read_text(),n) for n in ['setWallpaperProfile','setWallpaperPerDisplay','nextWallpaper'])}.items():text=text.replace(k,val)
    probe=b/f'shared-probe-{v}.qml';probe.write_text(text)
    env=os.environ.copy();env.pop('DISPLAY',None);env.update(QT_QPA_PLATFORM='wayland',QT_QUICK_BACKEND='software',NO_COLOR='1',XDG_RUNTIME_DIR='/run/user/1000',WAYLAND_DISPLAY='wayland-1')
    r=subprocess.run(['qs','-n','-p',str(probe)],capture_output=True,text=True,env=env,timeout=10)
    log=re.sub(r'\x1b\[[0-9;]*[mK]','',r.stdout+r.stderr);(b/f'shared-runtime-{v}.log').write_text(log);print(v,log,'RC',r.returncode)
    assert r.returncode==0 and 'SHARED_JOINT_ADVANCE_REAL_QML_SCANNER_PASS' in log and 'SHARED_FAIL' not in log
    assert not any(e in log for e in ['ReferenceError','TypeError','Cannot assign'])
