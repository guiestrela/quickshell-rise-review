#!/usr/bin/env python3
"""Open only the fixed known app for a matching selected notification.

Same-user notification state is a reference, not authenticated sender identity.
Historical app launch does not recover the original message.
"""
import argparse
import configparser
import json
import os
from pathlib import Path
import stat
import subprocess
import sys


APP_COMMANDS={'Thunderbird': ['/usr/bin/thunderbird']}
GIO='/usr/bin/gio'

class Unavailable(ValueError):
    pass

def read_owned(path,system=False):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    with os.fdopen(fd,'rb') as file:
        info=os.fstat(file.fileno())
        owners={0,os.getuid()} if system else {os.getuid()}
        if info.st_uid not in owners or info.st_mode&0o022 or not stat.S_ISREG(info.st_mode):
            raise Unavailable('The notification reference cannot be read safely.')
        raw=file.read(524289)
        if len(raw)>524288:
            raise Unavailable('The notification reference is too large.')
        return raw

def read_json(path):
    return json.loads(read_owned(path))

def desktop_dirs():
    home=Path.home()
    return [home/'.local/share/applications', home/'.local/share/flatpak/exports/share/applications',
            Path('/usr/local/share/applications'), Path('/usr/share/applications'),
            Path('/var/lib/flatpak/exports/share/applications')]

class DesktopParser(configparser.ConfigParser):
    def optionxform(self,optionstr):return optionstr

def desktop_metadata(path):
    if path.lstat().st_uid not in {0,os.getuid()}:
        raise Unavailable('The installed launcher has an unknown owner.')
    parser=DesktopParser(interpolation=None,strict=True)
    parser.read_string(read_owned(path.resolve(strict=True),system=True).decode('utf-8'))
    row=parser['Desktop Entry']
    if (row.get('Type')!='Application' or row.get('Hidden','').lower()=='true'
            or row.get('NoDisplay','').lower()=='true'
            or not (row.get('Exec') or row.get('DBusActivatable','').lower()=='true')):
        raise Unavailable('The registered application is not available.')
    return row

def desktop_command(app):
    matches=[];seen=set()
    for folder in desktop_dirs():
        for path in sorted(folder.glob('*.desktop')):
            if path.name in seen:continue  # XDG user override, including Hidden.
            seen.add(path.name)
            try:row=desktop_metadata(path)
            except (OSError,ValueError,KeyError,configparser.Error):continue
            aliases=[path.stem,row.get('StartupWMClass','')]
            aliases.extend(value for key,value in row.items() if key=='Name' or key.startswith('Name['))
            if any(app.casefold()==alias.casefold() for alias in aliases if alias):matches.append(path)
    if len(matches)!=1:
        raise Unavailable('The installed app cannot be identified uniquely for this notification.')
    return [GIO,'launch',str(matches[0])]

def plan_open(entry,state_dir,cache):
    if (not isinstance(entry,dict) or entry.get('backend')!='omarchy'
            or not isinstance(entry.get('appName'),str) or not 0<len(entry['appName'])<=256 or 'execArgv' in entry
            or type(entry.get('id')) is not int or not 0<entry['id']<2147483648
            or not isinstance(entry.get('timestamp'),(int,float)) or isinstance(entry['timestamp'],bool)
            or not 0<entry['timestamp']<1e15 or entry['timestamp']!=int(entry['timestamp'])
            or not isinstance(entry.get('summary'),str) or not isinstance(entry.get('body'),str)
            or len(entry['body'])>8192):
        raise Unavailable('This app has no approved fixed launcher.')
    filename=str(int(entry['timestamp']))+'-'+str(entry['id'])+'.json'
    native=[]
    for d in (Path(state_dir),Path(state_dir)/'history'):
        p=d/filename
        if p.exists() or p.is_symlink():native.append(read_json(p))
    if len(native)>1:raise Unavailable('The selected notification is ambiguous.')
    if native:
        row=native[0]
        if (not isinstance(row,dict) or (row.get('originalId') or row.get('id'))!=entry['id']
                or row.get('timestamp')!=entry['timestamp'] or row.get('app')!=entry['appName']
                or row.get('summary')!=entry['summary'] or row.get('body')!=entry['body']
                or row.get('execArgv')):
            raise Unavailable('The selected native notification has changed.')
    else:
        # The host trims its ten-entry history before Rise's own retained cache.
        # Missing native state permits only this explicitly approved fixed-app effect;
        # it never recreates a native callback or authorizes a sender command.
        saved=read_json(cache)
        if not isinstance(saved,dict) or not isinstance(saved.get('recent'),list) or len(saved['recent'])>50:
            raise Unavailable('The retained notification cache is invalid.')
        matches=[r for r in saved['recent'] if isinstance(r,dict)
                 and r.get('id')==entry['id'] and r.get('timestamp')==entry['timestamp']]
        if len(matches)!=1:raise Unavailable('The selected retained notification is unavailable or ambiguous.')
        row=matches[0]
        if any(row.get(k)!=entry[k] for k in ('backend','appName','summary','body')) or row.get('execArgv'):
            raise Unavailable('The selected retained notification has changed.')
    if entry['appName'] in APP_COMMANDS:return list(APP_COMMANDS[entry['appName']])
    return desktop_command(entry['appName'])

def launch(argv):
    if argv not in APP_COMMANDS.values():
        if len(argv)!=3 or argv[:2]!=[GIO,'launch']:
            raise Unavailable('Unknown app command is not allowed.')
        path=Path(argv[2])
        if path.parent not in desktop_dirs() or path.suffix!='.desktop':
            raise Unavailable('The app launcher is not registered.')
        desktop_metadata(path)  # Revalidate before GIO reads the installed launcher.
    info=Path(argv[0]).resolve(strict=True).stat()
    if info.st_uid!=0 or info.st_mode&0o022 or not stat.S_ISREG(info.st_mode) or not os.access(argv[0],os.X_OK):
        raise Unavailable('The installed app is not trusted.')
    env={k:v for k,v in os.environ.items() if k not in ('BASH_ENV','ENV','LD_PRELOAD','LD_LIBRARY_PATH') and not k.startswith('BASH_FUNC_')}
    env['PATH']='/usr/bin';env.pop('CHROME_WRAPPER',None)
    child=subprocess.Popen(argv,env=env,start_new_session=True,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:code=child.wait(timeout=0.75)
    except subprocess.TimeoutExpired:return  # App launch != visual proof.
    if code!=0:raise Unavailable('The selected app failed to open.')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--entry',required=True);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    try:
        if len(args.entry)>16384:raise Unavailable('The notification request is too large.')
        home=Path.home();state=Path(os.environ.get('XDG_STATE_HOME',str(home/'.local/state')))/'omarchy/notifications'
        cache=Path(os.environ.get('XDG_CACHE_HOME',str(home/'.cache')))/'qs-rise-notifications.json'
        argv=plan_open(json.loads(args.entry),state,cache)
        if not args.check:launch(argv)
        print(json.dumps({'ok':True,'checkedOnly':args.check,'action':'app-open'}));return 0
    except (ValueError,OSError,KeyError,configparser.Error,subprocess.SubprocessError) as error:
        print(json.dumps({'ok':False,'message':str(error)}));return 1

if __name__=='__main__':sys.exit(main())
