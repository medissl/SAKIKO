"""Original speech edit and restrained non-vocal classroom foley. No synthesized voice tones."""
from pathlib import Path
import wave,json,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/audio'; SRC=OUT/'production'; RATE=22050
rng=np.random.default_rng(15101999)
def read(name):
    with wave.open(str(SRC/(name+'.wav')),'rb') as w:
        data=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
        if w.getnchannels()>1: data=data.reshape(-1,w.getnchannels()).mean(axis=1)
        if w.getframerate()!=RATE:
            data=np.interp(np.arange(int(len(data)*RATE/w.getframerate()))/RATE,np.arange(len(data))/w.getframerate(),data)
        return data

def write(name,x):
    peak=float(np.max(np.abs(x)))
    if peak>.90: x=x*(.90/peak)
    with wave.open(str(OUT/name),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes((x*32767).astype('<i2').tobytes())
    return {'file':name,'duration':len(x)/RATE,'peak':min(peak,.90)}

def filtered(x,low=150,high=6500):
    spectrum=np.fft.rfft(x)
    freq=np.fft.rfftfreq(len(x),1/RATE)
    spectrum*=np.clip((freq-low)/max(low,1),0,1)*np.clip((high-freq)/max(high*.4,1),0,1)
    return np.fft.irfft(spectrum,n=len(x))

def put(dst,src,at,gain=1):
    start=int(at*RATE);end=min(len(dst),start+len(src)); dst[start:end]+=src[:end-start]*gain

def room(x):
    out=np.pad(x,(0,int(.24*RATE)))
    for lag,gain in [(.047,.12),(.103,.065),(.181,.03)]: put(out,x,lag,gain)
    return out

def rustle(duration=.55):
    x=filtered(rng.normal(0,.18,int(duration*RATE)),450,9000)
    x*=np.sin(np.linspace(0,np.pi,len(x)))**2*(.35+.65*np.sin(np.linspace(0,5*np.pi,len(x)))**2)
    return x

manifest={'teacher_language':'English version as requested; Japanese localization is a future option.','voices':{'teacher':'Microsoft David (Windows OneCore)','student_a':'Microsoft Mark (Windows OneCore)','student_b':'Microsoft Zira (Windows OneCore)'},'tape_captions':[],'teacher_captions':[],'files':[]}
lesson=np.zeros(RATE*125)
texts=['All right. Open your textbooks to page forty-two.', "We're going to read the first passage together.", 'Look at the first paragraph. Underline anything that tells you how the writer feels.', "You don't need to finish yet. Take your time.", "We'll compare your answers in a moment."]
for i,start in enumerate([2,35,62,88,112]):
    audio=room(read(f'teacher_{i}'))
    put(lesson,audio,start,.65)
    manifest['teacher_captions'].append({'start':start,'end':min(125,start+len(audio)/RATE+2),'text':'Teacher: '+texts[i]})
manifest['files'].append(write('teacher_lesson.wav',lesson))
chatter=np.zeros(RATE*125)
for at,name in [(8,'chatter_a'),(43,'chatter_b'),(73,'chatter_a'),(104,'chatter_b')]: put(chatter,filtered(read(name),220,800),at,.16)
manifest['files'].append(write('classroom_chatter.wav',chatter))
foley=np.zeros(RATE*125)
for i,at in enumerate([5.5,13.2,22.7,31.2,44.1,51.7,67.2,78.8,92.3,109.5,119.2]):
    put(foley,rustle(.35+(i%3)*.17),at,.18)
    if i%3==0:
        thump=rng.normal(0,.08,int(.08*RATE))*np.exp(-np.linspace(0,7,int(.08*RATE)))
        put(foley,filtered(thump,30,700),at+.6,.30)
for at in [18,58,98]:
    pencil=filtered(rng.normal(0,.02,RATE*2),1800,6500)
    pencil*=np.sin(np.linspace(0,22*np.pi,len(pencil)))**8
    put(foley,pencil,at,.12)
manifest['files'].append(write('classroom_foley.wav',foley))
tape=np.zeros(int(RATE*28));cursor=.8
lines=[('student_a_0','Student A: F-12 is packed. Leave the equipment case in the AV room.',.8),('student_b_0',"Student B: What's the combination?",.75),('student_a_1','Student A: The festival date. Month, then day. Same as the program.',2.7),('student_b_1','Student B: Did someone stay behind?',.9),('student_a_2','Student A: I thought you checked.',1.5)]
for i,(name,text,pause) in enumerate(lines):
    audio=filtered(read(name),180,5800)
    put(tape,room(audio),cursor,.66)
    manifest['tape_captions'].append({'start':cursor,'end':cursor+len(audio)/RATE+.25,'text':text})
    cursor+=len(audio)/RATE
    if i==2:
        for offset in [.65,1.20]:
            knock=filtered(rng.normal(0,.12,int(.10*RATE)),80,700)*np.exp(-np.linspace(0,7,int(.10*RATE)))
            put(tape,knock,cursor+offset,.32)
        manifest['tape_captions'].append({'start':cursor+.55,'end':cursor+1.65,'text':'[Two faint knocks.]'})
    cursor+=pause
put(tape,rustle(.8),cursor-.5,.35)
tape=tape[:int(max(24.0,min(28,cursor+.8))*RATE)]
tape+=rng.normal(0,.0012,len(tape))
manifest['files'].append(write('festival_students.wav',tape))
manifest['sources']=[{'title':'Children Playing .mp3','author':'piermic','license':'CC0-1.0','page':'https://freesound.org/people/piermic/sounds/396118/','download':'https://cdn.freesound.org/previews/396/396118_3874114-hq.mp3','changes':'Public high-quality preview used, spatial playback and low-pass filtering in game.','sha256':hashlib.sha256((SRC/'children_playing_piermic.mp3').read_bytes()).hexdigest()},{'title':'Original teacher/student speech','source':'Installed Microsoft Windows OneCore SAPI voices; no engine files redistributed. Original generic script; not an imitation.','release_clearance':'Preserve the existing Microsoft synthesized-output clearance qualification in ASSET_SOURCES.md; development audio is not represented as cleared third-party voice-engine content.'},{'title':'Original paper/pencil/book/handling and knock foley','source':'Original deterministic noise envelopes and filtering in tools/produce_audio.py. Non-vocal effects only.'}]
(OUT/'production.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print(json.dumps(manifest['files']))
