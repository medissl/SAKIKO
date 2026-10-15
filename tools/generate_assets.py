"""Deterministic original SAKIKO textures and PCM sound library. Requires numpy/Pillow."""
from pathlib import Path
import wave, json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
rng = np.random.default_rng(6731)
tex = ROOT / 'assets/textures'
audio = ROOT / 'assets/audio'
tex.mkdir(parents=True, exist_ok=True)
audio.mkdir(parents=True, exist_ok=True)
for name, color in [('plaster',(102,112,105)), ('wood',(74,57,41)), ('floor',(75,81,73)), ('ceiling',(86,92,87))]:
    n=512
    noise=rng.normal(0,4,(n,n,1))
    arr=np.clip(np.array(color)[None,None,:]+noise,0,255).astype('uint8')
    im=Image.fromarray(arr); d=ImageDraw.Draw(im,'RGBA')
    if name=='floor':
        for x in range(0,n,128): d.line((x,0,x,n), fill=(12,20,19,170),width=3)
        for y in range(0,n,64): d.line((0,y,n,y), fill=(12,20,19,150),width=2)
    if name=='wood':
        for i in range(180):
            y=int(rng.integers(n)); d.line((0,y,n,y+int(rng.integers(-7,8))),fill=(12,5,2,int(rng.integers(10,55))))
    if name=='plaster':
        d.rectangle((0,300,512,512),fill=(22,47,39,100))
        for i in range(40):
            x,y=rng.integers(0,n,2); r=int(rng.integers(4,45)); d.ellipse((int(x),int(y),int(x+r),int(y+r*2)),fill=(15,22,14,12))
    for i in range(150):
        x,y=rng.integers(0,n,2); d.line((int(x),int(y),int(x+rng.integers(2,28)),int(y+1)),fill=(160,158,130,18))
    im.save(tex/f'{name}.png')

SR=22050
stats={}
def save(name, a, peak=.65):
    a=np.asarray(a,dtype=float); a-=a.mean()
    a*=peak/max(np.max(np.abs(a)),1e-7)
    fade=min(250,len(a)//10); a[:fade]*=np.linspace(0,1,fade); a[-fade:]*=np.linspace(1,0,fade)
    with wave.open(str(audio/f'{name}.wav'),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((a*32767).astype('<i2').tobytes())
    stats[name]={'seconds':round(len(a)/SR,2),'peak':round(float(abs(a).max()),3),'rms':round(float(np.sqrt(np.mean(a*a))),4)}
def base(seconds):
    t=np.arange(int(SR*seconds))/SR; n=rng.normal(0,1,len(t)); return t,n
def low(n,k=100): return np.convolve(n,np.ones(k)/k,'same')
t,n=base(8)
save('ambience',.3*low(n,250)+.025*np.sin(2*np.pi*47*t)+.015*np.sin(2*np.pi*71*t+np.sin(t*.8)),.28)
t,n=base(4)
save('hum',.15*np.sin(2*np.pi*100*t)*(1+.12*np.sin(2*np.pi*3*t))+.02*low(n,10),.18)
t,n=base(2.4)
save('creak',np.sin(2*np.pi*(110*t+12*np.sin(t*3)))*np.sin(np.pi*t/2.4)**3*.2+low(n,30)*.1,.4)
t,n=base(.28)
save('step',(.5*low(n,20)+.08*n)*np.exp(-t*24)+.1*np.sin(2*np.pi*75*t)*np.exp(-t*30),.45)
for name,freq,dur in [('hover',620,.07),('press',320,.13),('key',1100,.65),('unlock',450,1.1),('locked',90,.3)]:
    t,n=base(dur); save(name,(np.sin(2*np.pi*freq*t)+.35*np.sin(2*np.pi*freq*1.49*t))*.25*np.exp(-t*7)+low(n,12)*np.exp(-t*20)*.15,.4)
t,n=base(.9)
save('door',low(n,18)*np.sin(np.pi*t/.9)+np.sin(2*np.pi*(55*t+12*t*t))*.12*np.exp(-t*5),.48)
t,n=base(4)
save('breath',(low(n,9)*.6+np.sin(2*np.pi*73*t+3*np.sin(t*14))*.045)*(.3+.7*np.sin(np.pi*t/4)**2),.3)
t,n=base(1.5)
save('chase',(low(n,8)*.2+np.sin(2*np.pi*(65*t+30*t*t))*.1)*np.exp(-t*2),.55)
t,n=base(1.75)
phase=2*np.pi*(160*t-35*t*t+3*np.sin(t*22))
voice=np.tanh(3*(np.sin(phase)+.35*np.sin(phase*2.03)+.2*np.sin(phase*3.01)))
impact=np.sin(2*np.pi*(64*t-15*t*t))*np.exp(-t*10)
attack=(n*.35+low(n,4)) * np.exp(-t*38)
save('capture',attack+voice*.33*np.exp(-t*2.8)*(1+.2*np.sin(t*51))+impact*.8,.83)
(audio/'analysis.json').write_text(json.dumps(stats,indent=2))
print(json.dumps(stats,indent=2))
