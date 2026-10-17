"""Build natural-pitch feminine vocal edits from verified CC0 source; no voice synthesis.
Writes a hash-checked local source package before copying runtime edits into the game.
"""
from pathlib import Path
import hashlib,json,shutil
import numpy as np
import soundfile as sf
ROOT=Path(__file__).resolve().parents[1];CACHE=ROOT/'.asset-cache/flow-vocals';PKG=CACHE/'package';PKG.mkdir(exist_ok=True)
source=json.loads((CACHE/'source.json').read_text());raw=CACHE/'aderumoro-shrieks.mp3'
assert hashlib.sha256(raw.read_bytes()).hexdigest()==source['source_sha256']
x,sr=sf.read(str(raw),always_2d=True);x=x.mean(axis=1);RATE=24000
records=[]
for name,start,end in [('sakiko_capture_shriek.wav',.22,3.35),('sakiko_chase_shriek.wav',4.22,7.94)]:
 a=x[int(start*sr):int(end*sr)].copy();a-=a.mean()
 a=np.interp(np.arange(round(len(a)*RATE/sr))/RATE,np.arange(len(a))/sr,a)
 n=min(120,len(a)//10);a[:n]*=np.linspace(0,1,n);a[-480:]*=np.linspace(1,0,480)
 a*=.90/max(.0001,np.max(np.abs(a)))
 path=PKG/name;sf.write(str(path),a,RATE,subtype='PCM_16')
 records.append(dict(file=name,source_range=[start,end],sha256=hashlib.sha256(path.read_bytes()).hexdigest(),duration=len(a)/RATE,sample_rate=RATE,peak=float(np.max(np.abs(a))),rms_db=float(20*np.log10(np.sqrt(np.mean(a*a))+1e-10))))
receipt={'source':source,'license_url':'https://creativecommons.org/publicdomain/zero/1.0/','processing':'Natural-pitch isolated female shrieks, mono, DC removal, sample-rate conversion, short boundary fades, normalized peak 0.90. No pitch alteration, bitcrushing or male layer. Capture decay controlled in game after blackout.','clips':records,'physical_listening_verified':False}
(PKG/'provenance.json').write_text(json.dumps(receipt,indent=2))
(PKG/'SOURCE_LICENSE.txt').write_text(source['credit']+'\nSource: '+source['page']+'\nCC0 1.0 Universal public-domain dedication. Verified on source page.\nhttps://creativecommons.org/publicdomain/zero/1.0/\n')
roster={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in PKG.iterdir() if p.is_file() and p.name!='SHA256SUMS.json'}
(PKG/'SHA256SUMS.json').write_text(json.dumps(roster,indent=2))
for name,sha in roster.items(): assert hashlib.sha256((PKG/name).read_bytes()).hexdigest()==sha
for clip in records:
 a,sr=sf.read(str(PKG/clip['file'])); assert sr==RATE and len(a)>RATE and np.max(abs(a))<.91
 shutil.copy2(PKG/clip['file'],ROOT/'assets/audio'/clip['file'])
shutil.copy2(PKG/'provenance.json',ROOT/'assets/audio/flow_vocal_provenance.json')
shutil.copy2(PKG/'SOURCE_LICENSE.txt',ROOT/'assets/audio/flow_vocal_SOURCE_LICENSE.txt')
print(json.dumps(records,indent=2))
