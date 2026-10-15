"""Build the capture mix using a licensed recorded male grunt and original effects."""
from pathlib import Path
import wave,io,zipfile,json,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[1]; SR=22050
source=ROOT/'.asset-cache/male-vocals.zip'
z=zipfile.ZipFile(source)
def read(data):
 with wave.open(io.BytesIO(data)) as w:
  rate=w.getframerate();channels=w.getnchannels();a=np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(float)/32768
  if channels>1:a=a.reshape(-1,channels).mean(axis=1)
  return np.interp(np.arange(int(len(a)*SR/rate))/SR,np.arange(len(a))/rate,a)
def write(name,a,peak):
 a=a-a.mean();a*=peak/max(abs(a).max(),1e-8)
 fade=min(130,len(a)//10);a[:fade]*=np.linspace(0,1,fade);a[-fade:]*=np.linspace(1,0,fade)
 with wave.open(str(ROOT/'assets/audio'/name),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((a*32767).astype('<i2').tobytes())
 return {'peak':float(abs(a).max()),'rms':float(np.sqrt((a*a).mean())),'seconds':len(a)/SR}
grunts=read(z.read('yelling sounds/3grunt2.wav'))
report={'player_pain.wav':write('player_pain.wav',grunts,.5)}
base=read((ROOT/'assets/audio/capture.wav').read_bytes());scream=read((ROOT/'assets/audio/scream.wav').read_bytes())
t=np.arange(int(SR*1.85))/SR; mix=np.zeros_like(t)
mix[:len(base)]+=base*.75
mix[:len(scream)]+=scream*.4
start=int(.66*SR);mix[start:start+len(grunts)]+=grunts*.68
rng=np.random.default_rng(187)
# Short rough inhalation and a resonant, low throat impact accompany the mouth pull.
noise=rng.normal(0,1,len(t));filtered=np.convolve(noise,np.ones(18)/18,'same')
mix+=filtered*.16*np.exp(-((t-.88)/.20)**2)
mix+=np.sin(2*np.pi*(53*t-9*t*t))*.16*np.exp(-t*7)
for delay,gain in [(.035,.16),(.071,.09)]:
 n=int(delay*SR);mix[n:]+=mix[:-n].copy()*gain
mix=np.tanh(mix*1.7)
report['capture_v2.wav']=write('capture_v2.wav',mix,.80)
manifest={'author':'HaelDB','source':'https://opengameart.org/content/male-gruntyelling-sounds','license':'CC0-1.0 (selected from offered CC0 / OGA-BY alternatives)','archive_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_file':'yelling sounds/3grunt2.wav','source_sha256':hashlib.sha256(z.read('yelling sounds/3grunt2.wav')).hexdigest(),'processing':'Stereo to mono, resampled 22.05 kHz, gain-normalized and endpoint fades. Mixed at 0.66s with original capture layers.','outputs':report}
(ROOT/'assets/audio/capture-provenance.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps(report,indent=2))
