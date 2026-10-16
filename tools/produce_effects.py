from pathlib import Path
import wave,json
import numpy as np
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/audio'; R=22050
rng=np.random.default_rng(162026)
def read(name):
    with wave.open(str(OUT/(name+'.wav')),'rb') as w:
        raw=w.readframes(w.getnframes()); n=w.getsampwidth(); rate=w.getframerate(); ch=w.getnchannels()
        a=(np.frombuffer(raw,dtype='<i2')/32768) if n==2 else (np.frombuffer(raw,dtype=np.uint8)/128-1)
        if ch>1:a=a.reshape(-1,ch).mean(axis=1)
        return np.interp(np.arange(int(len(a)*R/rate))/R,np.arange(len(a))/rate,a)
def band(a,lo,hi):
    f=np.fft.rfftfreq(len(a),1/R); x=np.fft.rfft(a)
    return np.fft.irfft(x*np.clip((f-lo)/max(1,lo),0,1)*np.clip((hi-f)/max(1,hi*.3),0,1),n=len(a))
def write(name,a):
    peak=max(.001,float(np.max(np.abs(a))));a=a*.60/max(peak,.60)
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(R);w.writeframes((a*32767).astype('<i2').tobytes())
    return {'id':name,'file':'res://assets/audio/'+name+'.wav','source':'Original non-vocal procedural foley; footsteps adapted from existing original step/run_step masters.','duration':len(a)/R}
records=[]
for surface in ['wood','tile','stair']:
    for gait,base in [('walk','step'),('run','run_step')]:
        original=read(base)
        for i in range(3):
            speed=[.98,1.,1.025][i]
            a=np.interp(np.arange(0,len(original),speed),np.arange(len(original)),original)
            if surface=='tile':a=band(a,90,8500)
            if surface=='stair':a=band(a,40,4500)
            records.append(write(f'foot_{surface}_{gait}_{i}',a*(.92+i*.04)))
for name,duration,lo,hi in [('door_track',.65,180,2800),('drawer_slide',.65,90,2000),('cabinet_hinge',.7,180,1800),('bag_fabric',.7,1000,10000),('paper_flip',.45,500,9000),('paper_lift',.25,700,8500),('photo_handle',.12,650,4000),('case_latch',.55,160,4000),('code_tick',.06,600,6000),('shelf_track',1.2,80,2000),('lock_turn',.22,400,6500),('shackle_release',.20,750,7500)]:
    n=int(R*duration);t=np.arange(n)/R
    a=band(rng.normal(0,.10,n),lo,hi)
    if name in ['door_track','drawer_slide','shelf_track']:
        envelope=np.sin(np.linspace(0,np.pi,n))**.6
        a*=envelope*(.65+.35*np.sin(t*50)**2)
        a[-min(n,1000):]+=rng.normal(0,.06,min(n,1000))*np.exp(-np.linspace(0,7,min(n,1000)))
    else:a*=np.exp(-t/(duration*.25))
    records.append(write(name,a))
(OUT/'effects_manifest.json').write_text(json.dumps(records,indent=2))
print('Produced',len(records),'small event/surface clips')
