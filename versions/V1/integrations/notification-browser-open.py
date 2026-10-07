#!/usr/bin/env python3
"""Open the selected alert's approved HTTPS href, not a guessed article URL.

Same-user notification state is a reference, not authenticated sender identity.
The authorized effect is a fixed Chromium new tab to the selected HTTPS href.
"""
import argparse
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
from urllib.parse import urlsplit

BROWSER='/usr/bin/chromium'

class Unavailable(ValueError):
    pass

class Links(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.hrefs=[]
    def handle_starttag(self,tag,attrs):
        if tag.lower()=='a':
            found=[v for k,v in attrs if k.lower()=='href']
            if len(found)!=1 or found[0] is None:
                raise Unavailable('The notification link is ambiguous.')
            self.hrefs.append(found[0])

def read_json(path):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    with os.fdopen(fd,'rb') as file:
        info=os.fstat(file.fileno())
        if info.st_uid!=os.getuid() or info.st_mode&0o022 or not stat.S_ISREG(info.st_mode):
            raise Unavailable('The notification reference cannot be read safely.')
        raw=file.read(524289)
        if len(raw)>524288:
            raise Unavailable('The notification reference is too large.')
        return json.loads(raw)

def plan_open(entry,state_dir,cache):
    if (not isinstance(entry,dict) or entry.get('backend')!='omarchy'
            or entry.get('appName')!='Chromium' or 'execArgv' in entry
            or type(entry.get('id')) is not int or not 0<entry['id']<2147483648
            or not isinstance(entry.get('timestamp'),(int,float)) or isinstance(entry['timestamp'],bool)
            or not 0<entry['timestamp']<1e15 or entry['timestamp']!=int(entry['timestamp'])
            or not isinstance(entry.get('summary'),str) or not isinstance(entry.get('body'),str)
            or len(entry['body'])>8192):
        raise Unavailable('This browser notification is unsupported.')
    filename=str(int(entry['timestamp']))+'-'+str(entry['id'])+'.json'
    native=[]
    for d in (Path(state_dir),Path(state_dir)/'history'):
        p=d/filename
        if p.exists() or p.is_symlink():native.append(read_json(p))
    if len(native)>1:raise Unavailable('The selected notification is ambiguous.')
    if native:
        row=native[0]
        if (not isinstance(row,dict) or (row.get('originalId') or row.get('id'))!=entry['id']
                or row.get('timestamp')!=entry['timestamp'] or row.get('app')!='Chromium'
                or row.get('summary')!=entry['summary'] or row.get('body')!=entry['body']
                or row.get('execArgv')):
            raise Unavailable('The selected native notification has changed.')
    else:
        # The host trims its ten-entry history before Rise's own retained cache.
        # Missing native state permits only this explicitly approved URL effect;
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
    parser=Links();parser.feed(entry['body']);parser.close()
    links=set(parser.hrefs)
    if len(links)!=1:raise Unavailable('There is no unique saved link for this alert; its original article cannot be recovered.')
    url=next(iter(links))
    if not isinstance(url,str) or len(url)>4096 or any(ord(c)<=32 or ord(c)==127 for c in url) or '\\' in url:
        raise Unavailable('The notification link is invalid.')
    parts=urlsplit(url)
    if (parts.scheme!='https' or not parts.hostname or parts.username is not None
            or parts.password is not None or parts.port not in (None,443)):
        raise Unavailable('Only valid HTTPS notification links without credentials on port 443 can open.')
    return [BROWSER,'--new-tab',url]

def launch(argv):
    if len(argv)!=3 or argv[:2]!=[BROWSER,'--new-tab']:
        raise Unavailable('Unknown browser command is not allowed.')
    info=Path(BROWSER).resolve(strict=True).stat()
    if info.st_uid!=0 or info.st_mode&0o022 or not stat.S_ISREG(info.st_mode) or not os.access(BROWSER,os.X_OK):
        raise Unavailable('The installed browser is not trusted.')
    env={k:v for k,v in os.environ.items() if k not in ('BASH_ENV','ENV','LD_PRELOAD','LD_LIBRARY_PATH') and not k.startswith('BASH_FUNC_')}
    env['PATH']='/usr/bin';env.pop('CHROME_WRAPPER',None)
    child=subprocess.Popen(argv,env=env,start_new_session=True,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    try:code=child.wait(timeout=0.75)
    except subprocess.TimeoutExpired:return  # Browser launch != visual proof.
    if code!=0:raise Unavailable('The browser failed to open the selected link.')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--entry',required=True);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    try:
        if len(args.entry)>16384:raise Unavailable('The notification request is too large.')
        home=Path.home();state=Path(os.environ.get('XDG_STATE_HOME',str(home/'.local/state')))/'omarchy/notifications'
        cache=Path(os.environ.get('XDG_CACHE_HOME',str(home/'.cache')))/'qs-rise-notifications.json'
        argv=plan_open(json.loads(args.entry),state,cache)
        if not args.check:launch(argv)
        print(json.dumps({'ok':True,'checkedOnly':args.check,'action':'browser-new-tab'}));return 0
    except (ValueError,OSError,subprocess.SubprocessError) as error:
        print(json.dumps({'ok':False,'message':str(error)}));return 1

if __name__=='__main__':sys.exit(main())
