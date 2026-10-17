"""Isolate a natural-pitch female breath; retain its CC0 source and hashes."""
from pathlib import Path
import hashlib,json,re
import numpy as np
import soundfile as sf
root=Path(__file__).resolve().parents[1];cache=root/'.asset-cache/flow-breath'
html=(cache/'license-source.html').read_text(encoding='utf-8')
assert 'creativecommons.org/publicdomain/zero' in html
raw=cache/'owlstorm-breath.mp3'
data,sr=sf.read(raw,always_2d=True);data=data.mean(axis=1)
start,end=.10,1.00
data=data[int(start*sr):int(end*sr)].copy();data-=data.mean()
data=np.interp(np.arange(21600)/24000,np.arange(len(data))/sr,data)
data[:240]*=np.linspace(0,1,240);data[-600:]*=np.linspace(1,0,600)
data*=.72/max(.001,np.max(np.abs(data)))
out=root/'assets/audio/sakiko_capture_breath.wav';sf.write(out,data,24000,subtype='PCM_16')
receipt={'title':'Female Breathing Heavily (2)','author':'OwlStorm / Ashe Kirk','page':'https://freesound.org/people/OwlStorm/sounds/151215/','download':re.findall(r'https://cdn\.freesound\.org/previews/[^\s"<>]+?hq\.mp3',html)[0],'license':'CC0-1.0','source_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'source_range':[start,end],'file':out.name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'sample_rate':24000,'duration':.9,'processing':'Mono, DC removal, boundary fades, resample, peak 0.72. Natural pitch. No synthesized or male layer.','physical_listening_verified':False}
(root/'assets/audio/flow_breath_provenance.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
(root/'assets/audio/flow_breath_SOURCE_LICENSE.txt').write_text('Female Breathing Heavily (2) by OwlStorm / Ashe Kirk\nhttps://freesound.org/people/OwlStorm/sounds/151215/\nCC0 1.0 Universal: https://creativecommons.org/publicdomain/zero/1.0/\nNatural-pitch breath edit. Attribution retained voluntarily.\n',encoding='utf-8')
print('Natural breath edit:',receipt['duration'],'s;',receipt['sha256'])
