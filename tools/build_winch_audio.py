"""Recorded CC0 lock/shackle contacts arranged as a low mechanical ratchet."""
from pathlib import Path
import json,hashlib
import numpy as np
import soundfile as sf
root=Path(__file__).resolve().parents[1];out=np.zeros(24000,dtype=np.float64);sources=[]
for name,times,level in [('lock_turn.wav',[0,.50],.75),('latch.wav',[.24,.76],.65)]:
 p=root/'assets/audio'/name;x,sr=sf.read(p,always_2d=True);x=x.mean(axis=1)
 x=np.interp(np.arange(round(len(x)*24000/sr))/24000,np.arange(len(x))/sr,x)
 for time in times:
  start=round(time*24000);n=min(len(x),len(out)-start);out[start:start+n]+=x[:n]*level
 sources.append({'file':name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
out[:120]*=np.linspace(0,1,120);out[-240:]*=np.linspace(1,0,240)
out*=.65/max(.001,np.max(np.abs(out)))
p=root/'assets/audio/winch_ratchet.wav';sf.write(p,out,24000,subtype='PCM_16')
receipt={'file':p.name,'sources':sources,'license':'CC0-1.0; original sources/creators in recorded_foley.json','processing':'Natural-pitch recorded lock and shackle contacts, four restrained ratchet pulses per second, mono 24 kHz PCM16, boundary fades, peak 0.65. No oscillator or bitcrushing.','sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'perceptual_audition_verified':False}
(root/'assets/audio/winch_ratchet_provenance.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print('Built recorded metal ratchet',receipt['sha256'])
