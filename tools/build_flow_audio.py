"""Offline material-contact edits from previously verified CC0 wood impact recordings.
No oscillator, bit crusher, pitch shift or speech model. Native sample-rate conversion.
"""
from pathlib import Path
import numpy as np
import soundfile as sf
import hashlib,json
root=Path(__file__).resolve().parents[1]; out=root/'assets/audio'; rate=24000
records=[]
def read(name):
 a,sr=sf.read(str(out/name),always_2d=True); a=a.mean(axis=1)
 return np.interp(np.arange(round(len(a)*rate/sr))/rate,np.arange(len(a))/sr,a)
def contact(name,cutoff):
 a=read(name); k=int(np.argmax(np.abs(a))); a=a[max(0,k-100):min(len(a),k+int(.24*rate))].copy()
 f=np.fft.rfftfreq(len(a),1/rate)
 a=np.fft.irfft(np.fft.rfft(a)*np.exp(-(f/cutoff)**4),n=len(a))
 a-=np.mean(a); a*=np.exp(-np.arange(len(a))/rate*9)
 a[:60]*=np.linspace(0,1,60);a[-240:]*=np.linspace(1,0,240)
 return a/max(.0001,np.max(np.abs(a)))
def save(name,a):
 sf.write(str(out/name),a,rate,subtype='PCM_16')
 records.append(dict(file=name,duration=len(a)/rate,peak=float(np.max(np.abs(a))),rms=float(np.sqrt(np.mean(a*a))),sha256=hashlib.sha256((out/name).read_bytes()).hexdigest()))
def knocks(name,events,cutoff):
 a=np.zeros(int(2.0*rate))
 for i,(at,gain) in enumerate(events):
  c=contact('foot_wood_walk_'+str(i%3)+'.wav',cutoff)
  j=int(at*rate);a[j:j+len(c)]+=c*gain
 save(name,a)
knocks('quiet_knocks.wav',[(.1,.30),(.68,.23)],1300)
knocks('staff_knocks.wav',[(.07,.55),(.55,.40),(1.23,.47)],2100)
rng=np.random.default_rng(15101999)
a=rng.normal(0,1,24*rate);f=np.fft.rfftfreq(len(a),1/rate)
a=np.fft.irfft(np.fft.rfft(a)*np.exp(-(f/5500)**4)*(1-np.exp(-(f/190)**4)),n=len(a));a*=.009/max(.0001,np.max(np.abs(a)))
for name,at,gain in [('case_latch.wav',.06,.20),('paper_flip.wav',10.0,.09),('quiet_knocks.wav',17.7,.75),('case_latch.wav',23.3,.20)]:
 c=read(name);j=int(at*rate);n=min(len(c),len(a)-j);a[j:j+n]+=c[:n]*gain
a[:240]*=np.linspace(0,1,240);a[-1200:]*=np.linspace(1,0,1200)
save('festival_nonverbal.wav',a)
(out/'flow_audio_provenance.json').write_text(json.dumps({'source':'recorded_foley.json: Noted451 CC0 wood impacts; existing recorded transport/paper','processing':'Isolated real material contact transients, DC removal, low pass, damping envelope, varied recorded events and spacing. No tonal synthesis, bitcrushing or pitch shift. Tape and staff sequences differ.','sample_rate':rate,'physical_listening_verified':False,'clips':records},indent=2))
print(json.dumps(records,indent=2))
