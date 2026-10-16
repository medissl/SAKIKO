"""Replace legacy tonal UI / capture feedback using already admitted recordings."""
from pathlib import Path
import hashlib,json
import numpy as np
import soundfile as sf

root=Path(__file__).resolve().parents[1]
folder=root/"assets/audio"
rate=24000
records=[]

def read(name):
    path=folder/(name+".wav")
    audio,sr=sf.read(path,always_2d=True)
    audio=audio.mean(axis=1)
    audio=np.interp(np.arange(int(len(audio)*rate/sr))/rate,np.arange(len(audio))/sr,audio)
    return audio,hashlib.sha256(path.read_bytes()).hexdigest()

for name,source,duration,peak,lowpass in [("hover","paper_flip",.08,.16,4200),
        ("press","case_latch",.12,.25,3200),("code_tick","lock_turn",.055,.20,4000),
        ("capture","close",.34,.65,700)]:
    raw,digest=read(source)
    # Select the actual transient, rather than a silent start or synthetic oscillator.
    onset=max(0,int(np.argmax(abs(raw)))-int(rate*.012))
    audio=raw[onset:onset+int(duration*rate)]
    audio=np.pad(audio,(0,max(0,int(duration*rate)-len(audio))))
    freq=np.fft.rfftfreq(len(audio),1/rate)
    audio=np.fft.irfft(np.fft.rfft(audio)*np.exp(-(freq/lowpass)**4),n=len(audio))
    audio-=audio.mean()
    fade=min(int(.008*rate),len(audio)//5)
    audio[:fade]*=np.linspace(0,1,fade)
    audio[-fade:]*=np.linspace(1,0,fade)
    audio*=peak/max(.00001,np.max(abs(audio)))
    path=folder/(name+".wav")
    sf.write(path,audio,rate,subtype="PCM_16")
    records.append({"file":path.name,"source":source+".wav","source_sha256":digest,
        "duration":duration,"peak":peak,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
        "processing":"Recorded transient crop, DC removal, low-pass and endpoint fades; no oscillators, pitch glide or added voice."})
receipt={"license":"CC0-1.0; source attribution in recorded_foley.json","clips":records}
(folder/"grounded_feedback_provenance.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
print("Replaced",len(records),"legacy synthetic feedback cues")
