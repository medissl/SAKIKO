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
# Expanded original sound palette: soft inharmonic music, chime and human-like textures.
t,n=base(28)
track=low(n,300)*.06
for f in [55,82.41,110.7,164.81]:
    track+=np.sin(2*np.pi*f*t+.08*np.sin(t*.7))*.018*(.65+.35*np.sin(t*.22+f)**2)
for when,f in [(2,440),(7,523.25),(12,415.3),(19,659.25),(23,392)]:
    q=np.maximum(t-when,0); env=np.exp(-q*1.25)*(t>=when)
    track+=(np.sin(2*np.pi*f*q)+.3*np.sin(2*np.pi*f*2.006*q))*.07*env
save('menu_music',track,.35)
t,n=base(4.8); ch=np.zeros_like(t)
for i,f in enumerate([659.25,523.25,587.33,392,392,587.33,659.25,523.25]):
    q=np.maximum(t-i*.48,0); env=np.exp(-q*4)*(t>=i*.48)
    ch+=(np.sin(2*np.pi*f*q)+.3*np.sin(2*np.pi*f*2.01*q)+.1*np.sin(2*np.pi*f*3.98*q))*env*.13
save('chime',ch,.48)
t,n=base(6)
save('classroom',low(n,70)*(.4+.12*np.sin(t*3))+.02*np.sin(2*np.pi*170*t+np.sin(t*12)),.25)
t,n=base(.28)
save('run_step',(low(n,11)*.5+n*.09)*np.exp(-t*19)+np.sin(2*np.pi*(65*t-40*t*t))*.18*np.exp(-t*23),.5)
t,n=base(2.6)
env=(.3+.7*np.maximum(0,np.sin(t*2*np.pi/1.3)))
save('pant',low(n,7)*env*.5+np.sin(2*np.pi*125*t+np.sin(t*28))*.015*env,.3)
t,n=base(2.5)
env=np.zeros_like(t)
for when in [.12,.48,.82,1.4,1.73]:
    env+=np.exp(-((t-when)/.105)**2)
f0=260+45*np.sin(t*5)+25*np.sin(t*21)
phase=2*np.pi*np.cumsum(f0)/SR
voice=sum(np.sin(phase*k)/k for k in range(1,7))
save('giggle',(voice*.11+low(n,9)*.14)*env,.35)
t,n=base(1.5)
phase=2*np.pi*(360*t-60*t*t+1.2*np.sin(t*38))
save('scream',(np.tanh(np.sin(phase)*2+.5*np.sin(phase*2.01))*.25+low(n,4)*.19)*np.sin(np.pi*t/1.5)**.6,.58)
t,n=base(.16)
save('latch',(low(n,6)*.3+np.sin(2*np.pi*210*t)*.13)*np.exp(-t*33),.38)
t,n=base(.5)
save('close',(low(n,15)*.6+np.sin(2*np.pi*75*t)*.12)*np.exp(-t*17),.45)
# A textured flashlight cookie with feathered edge and no hard circular boundary.
y,x=np.mgrid[-1:1:256j,-1:1:256j]; r=np.sqrt(x*x+y*y)
beam=np.exp(-r*r*3.4)*np.clip((1-r)*5,0,1)
beam*=.94+.04*np.sin(x*33+y*11)+.02*rng.random(r.shape)
Image.fromarray(np.uint8(np.clip(beam,0,1)*255)).save(tex/'beam.png')
# Worn window panes, grime and irregular runoff, designed as one consistent palette.
a=np.clip(rng.normal(60,4,(512,512)),0,255).astype('uint8')
im=Image.fromarray(np.stack([a*.43,a*.70,a],axis=-1).astype('uint8'))
d=ImageDraw.Draw(im,'RGBA')
for i in range(85):
    x=int(rng.integers(512)); y=int(rng.integers(512)); d.line((x,y,x+int(rng.integers(-5,6)),min(512,y+int(rng.integers(15,170)))),fill=(8,17,14,50),width=int(rng.integers(1,5)))
im.save(tex/'window.png')
(audio/'analysis.json').write_text(json.dumps(stats,indent=2))
print(json.dumps(stats,indent=2))
