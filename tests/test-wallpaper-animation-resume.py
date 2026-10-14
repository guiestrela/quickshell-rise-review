#!/usr/bin/env python3
"""Production renderer + real MP4/GIF decoders, synthetic lock signals only."""
import os,re,json,subprocess,tempfile
from pathlib import Path
R=Path(__file__).resolve().parents[1]
MEDIA=Path(os.environ['RISE_ANIMATION_TEST_MEDIA'])
with tempfile.TemporaryDirectory(prefix='resume-render-',dir=os.environ['TMPDIR']) as directory:
 t=Path(directory)
 for i,rel in enumerate(['versions/V1/modules/WallpaperManagerService.qml','versions/V1/variants/V2/modules/WallpaperManagerService.qml'],1):
  src=(R/rel).read_text();a=src.index('            PanelWindow {');b=src.index('\n            }\n        }\n    }',a)+14
  renderer=src[a:b].replace('PanelWindow {','Rectangle {',1)
  renderer=renderer.replace('                id: wallpaperWindow','                id: wallpaperWindow\n                required property var manager\n                property int frameCount:0\n                width:320; height:180',1)
  renderer=re.sub(r'^\s*(?:screen:|anchors \{ top: true; bottom: true; left: true; right: true \}|exclusionMode:|WlrLayershell\.).*\n','',renderer,flags=re.M)
  renderer=renderer.replace('                AnimatedImage {','                AnimatedImage {\n                    objectName: "qa-gif"',1)
  renderer=renderer.replace('                    id: videoOutput','                    id: videoOutput\n                    objectName: "qa-output"',1)
  renderer=renderer.replace('                MediaPlayer {','                Connections { target:videoOutput.videoSink; function onVideoFrameChanged(){wallpaperWindow.frameCount++} }\n                MediaPlayer {\n                    objectName: "qa-player"',1)
  (t/f'RenderV{i}.qml').write_text('import QtQuick\nimport QtMultimedia\n'+renderer)
 qml='''import QtQuick
import QtMultimedia
import QtTest
Item {
 width:320;height:180
 QtObject { id: theme;property bool wallpaperSessionLocked:false;property bool wallpaperScreensaverShowing:false }
 QtObject { id: manager
  property var theme:theme
  property string path:VIDEO_FILE
  property int bad:0
  function pathFor(name){return path}
  function fileUrl(path){return path}
  function scalingFor(name){return "actual"}
  function markBad(path){bad++}
 }
 Loader {id:load;width:320;height:180}
 TestCase {name:"WallpaperResume";when:windowShown
  function test_frames_resume(){
   for(var variant=1;variant<=2;variant++){
    theme.wallpaperSessionLocked=false;theme.wallpaperScreensaverShowing=false;manager.path=VIDEO_FILE;manager.bad=0
    load.setSource("RenderV"+variant+".qml",{manager:manager,modelData:{name:"TEST"}});tryCompare(load,"status",Loader.Ready)
    var renderer=load.item,player=findChild(renderer,"qa-player")
    verify(player!==null);tryVerify(function(){return renderer.frameCount>3},2500)
    var sameSource=player.source.toString()
    theme.wallpaperSessionLocked=true;wait(100)
    // Inject a halted decoder during a simulated lock, not a host lock.
    player.stop();tryCompare(player,"playbackState",MediaPlayer.StoppedState)
    var count=renderer.frameCount;theme.wallpaperSessionLocked=false
    tryVerify(function(){return player.playbackState===MediaPlayer.PlayingState&&renderer.frameCount>count+3},2200)
    compare(player.source.toString(),sameSource);compare(manager.bad,0)
    var pos=player.position;wait(150);verify(player.position!==pos)
    manager.path=GIF_FILE;var gif=findChild(renderer,"qa-gif");tryCompare(gif,"status",Image.Ready,1500)
    tryVerify(function(){return gif.currentFrame>0},1500)
    theme.wallpaperSessionLocked=true;wait(150);var old=gif.currentFrame;wait(180);compare(gif.currentFrame,old)
    theme.wallpaperSessionLocked=false;tryVerify(function(){return gif.currentFrame!==old},1500)
    var gifSource=gif.source.toString();theme.wallpaperScreensaverShowing=true;wait(150);old=gif.currentFrame;wait(150);compare(gif.currentFrame,old)
    theme.wallpaperScreensaverShowing=false;tryVerify(function(){return gif.currentFrame!==old},1500);compare(gif.source.toString(),gifSource)
    var beforeSwitch=renderer.frameCount;manager.path=VIDEO_FILE
    tryVerify(function(){return player.playbackState===MediaPlayer.PlayingState&&renderer.frameCount>beforeSwitch+3},2200);compare(manager.bad,0)
    console.log("ANIMATION_RESUME_PASS V"+variant)
   }
  }
 }
}
'''.replace('VIDEO_FILE',json.dumps((MEDIA/'moving.mp4').as_uri())).replace('GIF_FILE',json.dumps((MEDIA/'moving.gif').as_uri()))
 probe=t/'test.qml';probe.write_text(qml)
 env=os.environ.copy();env.pop('DISPLAY',None);env['QT_QPA_PLATFORM']='wayland'
 z=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-input',str(probe)],env=env,capture_output=True,text=True,timeout=15);out=z.stdout+z.stderr
 assert z.returncode==0 and out.count('ANIMATION_RESUME_PASS')==2,out
 assert not any(x in out for x in ['ReferenceError','TypeError','Cannot assign']),out
 print('PASS V1/V2: actual video frames and GIF currentFrame progress after synthetic lock/screensaver; same source, no markBad/selection change; no real lock or wallpaper mutation')
