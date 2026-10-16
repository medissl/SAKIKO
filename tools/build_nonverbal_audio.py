"""Deterministic nonverbal beds, preserving the published tape transcript clock.
No speech, voice model, or discarded source assets. Recorded foley sources retain
the CC0 attribution in recorded_foley.json; noise layers are original synthesis.
"""
from pathlib import Path
import json, hashlib
import numpy as np
import soundfile as sf
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/audio'; R=24000
rng=np.random.default_rng(1015472); records=[]
def noise(seconds, low, high):
    n=int(seconds*R); f=np.fft.rfftfreq(n,1/R)
    curve=(1-np.exp(-(f/max(low,1))**4))*np.exp(-(f/high)**4)
    a=np.fft.irfft(np.fft.rfft(rng.normal(size=n))*curve,n=n)
    return a/max(.001,np.max(np.abs(a)))
def save(name,a):
    n=min(int(R*.08),len(a)//10)
    a[:n]*=np.linspace(0,1,n);a[-n:]*=np.linspace(1,0,n)
    path=OUT/(name+'.wav');sf.write(path,a,R,subtype='PCM_16')
    records.append(dict(file=path.name,duration=len(a)/R,peak=float(np.max(np.abs(a))),rms=float(np.sqrt(np.mean(a*a))),sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
save('building_roomtone',noise(37,55,520)*.12)
wind=noise(31,90,1700);t=np.arange(len(wind))/R
save('window_air',wind*(.09+.04*np.sin(t*.27)+.02*np.sin(t*.71)))
t=np.arange(R*6)/R
save('suspense_texture',(np.sin(2*np.pi*47*t)*.055+noise(6,65,180)*.06)*np.sin(np.pi*t/6)**2)
# Reuse the licensed natural school activity, filtering out verbal detail.
crowd,sr=sf.read(str(OUT/'production/children_playing_piermic.mp3'),always_2d=True)
crowd=crowd.mean(axis=1);crowd=np.interp(np.arange(int(len(crowd)*R/sr))/R,np.arange(len(crowd))/sr,crowd)
freq=np.fft.rfftfreq(len(crowd),1/R)
crowd=np.fft.irfft(np.fft.rfft(crowd)*np.exp(-(freq/330)**6),n=len(crowd))
crowd*=.16/max(.001,np.max(np.abs(crowd)))
save('classroom_murmur',crowd)
# Transport + hiss + recorded paper movement; authored knocks at existing cue.
data=json.loads((OUT/'production.json').read_text(encoding='utf-8'))
length=24.0;a=noise(length,220,6500)*.012
def insert(file,at,gain):
    clip,sr=sf.read(str(OUT/file),always_2d=True);clip=clip.mean(axis=1)
    clip=np.interp(np.arange(int(len(clip)*R/sr))/R,np.arange(len(clip))/sr,clip)*gain
    start=int(at*R);end=min(len(a),start+len(clip));a[start:end]+=clip[:end-start]
insert('case_latch.wav',.05,.12)
for at in [3.1,10.3,18.1]:insert('paper_flip.wav',at,.065)
knock=next(c for c in data['tape_captions'] if 'Two faint knocks' in c['text'])
insert('quiet_knocks.wav',knock['start'],.6)
# Last transcript ends at 22.28; preserve silence before transport completion.
a[int(22.35*R):]=0
save('festival_nonverbal',a)
(OUT/'nonverbal_manifest.json').write_text(json.dumps({'method':'Original filtered noise beds; existing recorded CC0 paper/transport; existing authored knocks. No intelligible voice. Physical listening unverified.','clips':records},indent=2),encoding='utf-8')
print('Built',len(records),'nonverbal clips')
