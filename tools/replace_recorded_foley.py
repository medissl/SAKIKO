"""Fetch only selected CC0 material recordings, then extract bounded event clips.
Sources/HQ-preview bytes are retained in .asset-cache; hashes accompany runtime edits.
Run --fetch first (network), then without arguments (offline).
"""
from pathlib import Path
import json,re,urllib.request,hashlib,sys
ROOT=Path(__file__).resolve().parents[1];CACHE=ROOT/'.asset-cache/foley';CACHE.mkdir(parents=True,exist_ok=True)
SOURCES={
 'wood':('Noted451',582202), 'tile':('ChloePieterse',764530),
 'stair':('Anthousai',398784), 'slide':('Rudmer_Rotteveel',364104),
 'paper':('bdunis4',271459), 'drawer':('FOSSarts',740449),
 'lock':('ani_music',632480), 'shackle':('Rudmer_Rotteveel',536414),
 'bag':('OwlStorm',212180),
 'chair':('SpliceSound',188204),
}
if '--fetch' in sys.argv:
 from concurrent.futures import ThreadPoolExecutor
 def fetch(item):
    name,(author,id)=item;url=f'https://freesound.org/people/{author}/sounds/{id}/'
    if (CACHE/'sources.json').exists():
        for old in json.loads((CACHE/'sources.json').read_text()):
            if old['id']==name and old['page']==url and (CACHE/(name+'.mp3')).exists():return old
    request=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
    html=urllib.request.urlopen(request,timeout=40).read().decode()
    assert 'creativecommons.org/publicdomain/zero' in html, 'CC0 not verified: '+name
    (CACHE/(name+'.html')).write_text(html,encoding='utf-8')
    urls=re.findall(r'https://cdn\.freesound\.org/previews/[^\s"<>]+?hq\.mp3',html)
    assert urls, 'No public HQ preview: '+name
    data=urllib.request.urlopen(urls[0],timeout=40).read();(CACHE/(name+'.mp3')).write_bytes(data)
    return dict(id=name,author=author,page=url,download=urls[0],license='CC0-1.0',sha256=hashlib.sha256(data).hexdigest())
 with ThreadPoolExecutor(max_workers=4) as pool: records=list(pool.map(fetch,SOURCES.items()))
 (CACHE/'sources.json').write_text(json.dumps(records,indent=2));print('Downloaded',len(records),'verified CC0 category recordings.');sys.exit()

import numpy as np
import soundfile as sf
R=24000;OUT=ROOT/'assets/audio';records=[]
def load(name):
 a,r=sf.read(str(CACHE/(name+'.mp3')),always_2d=True);a=a.mean(axis=1)
 a=np.interp(np.arange(int(len(a)*R/r))/R,np.arange(len(a))/r,a)
 return a-np.mean(a)
def bursts(a,duration,count=3):
 # Separate transients, not adjacent windows from one impact.
 hop=120;energy=np.array([np.sqrt(np.mean(a[i:i+hop]**2)) for i in range(0,len(a)-hop,hop)])
 order=np.argsort(energy)[::-1];chosen=[]
 for k in order:
    t=k*hop/R
    if (count>1 and (t<.04 or t>len(a)/R-.12)) or any(abs(t-old)<max(.32,duration) for old in chosen):continue
    chosen.append(t)
    if len(chosen)>=count:break
 assert len(chosen)>=count
 return [a[max(0,int((t-.045)*R)):max(0,int((t-.045)*R))+int(duration*R)] for t in sorted(chosen)]
def write(name,a,source,peak=.50):
 a=a.copy();n=min(240,len(a)//5);a[:n]*=np.linspace(0,1,n);a[-n:]*=np.linspace(1,0,n)
 a*=peak/max(.001,float(np.max(np.abs(a))))
 p=OUT/(name+'.wav');sf.write(str(p),a,R,subtype='PCM_16')
 records.append(dict(id=name,file='res://assets/audio/'+name+'.wav',source_id=source,processing='Mono, DC removal, isolated recorded event, endpoint fades, bounded peak; no pitch shift/reverb.',duration=len(a)/R,peak=peak,rms=float(np.sqrt(np.mean(a*a))),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
for surface in ['wood','tile','stair']:
 samples=bursts(load(surface),.28 if surface=='tile' else .34)
 for gait in ['walk','run']:
    for i,a in enumerate(samples):write(f'foot_{surface}_{gait}_{i}',a,surface,.48 if gait=='walk' else .64)
for source,outputs,duration in [
 ('slide',['door_track','shelf_track'],.65),('drawer',['drawer_slide','cabinet_hinge'],.65),
 ('paper',['paper_flip','paper_lift','photo_handle'],.30),('bag',['bag_fabric'],.70),
 ('lock',['lock_turn','key','locked','unlock'],.22),('shackle',['shackle_release','case_latch','latch'],.18),
 ('slide',['close'],.15),('chair',['creak'],.85)]:
 a=load(source);cuts=bursts(a,duration,1)
 for output in outputs:write(output,cuts[0],source,.40 if output in ['photo_handle','paper_lift'] else .53)
foley=np.zeros(R*125)
papers=bursts(load('paper'),.45,3)
for i,at in enumerate([5.5,13.2,22.7,31.2,44.1,51.7,67.2,78.8,92.3,109.5,119.2]):
 a=papers[i%3].copy();a*=.10/max(.001,np.max(np.abs(a)));start=int(at*R);foley[start:start+len(a)]+=a
sf.write(str(OUT/'classroom_foley.wav'),foley,R,subtype='PCM_16')
manifest={'sources':json.loads((CACHE/'sources.json').read_text()),'clips':records,'review':'Recorded category sources replace noise-only placeholders. Numerical checks are not a listening/performance review.'}
(OUT/'recorded_foley.json').write_text(json.dumps(manifest,indent=2));print('Replaced',len(records),'event clips.')
