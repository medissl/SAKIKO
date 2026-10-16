"""Local Japanese dialogue. Model/cache stay outside shipped assets; no network at runtime.

Run with PYTHONPATH=.local-user/voice-deps using the bundled Python.
Kokoro-82M v1.0 (hexgrad), ONNX conversion thewh1teagle; Misaki Japanese G2P.
"""
from pathlib import Path
import json, hashlib, re, wave
import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro
from misaki.ja import JAG2P

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/audio/production'; CACHE=ROOT/'.local-user/voice-models'
engine=Kokoro(str(CACHE/'kokoro-v1.0.onnx'),str(CACHE/'voices-v1.0.bin'))
g2p=JAG2P()
RATE=24000
player=engine.get_voice_style('jm_kumo')*.80+engine.get_voice_style('am_michael')*.20
teacher=engine.get_voice_style('jm_kumo')
cast={'player':player,'teacher':teacher,'student_a':player,'student_b':engine.get_voice_style('jf_alpha')}

PLAYER={
 'P01':'あれ……みんな、どこに行ったんだ？',
 'P02':'錠前が四つ……鍵を探さないと。',
 'P03':'上は閉まってる。職員室に鍵があるかな。',
 'P04':'これ、二階の鍵だ。',
 'P05':'元の写真じゃ、笑ってない。',
 'P06':'文化祭の展示……二階か。',
 'P07':'この笑顔、あとから描き足したんだ。',
 'P08':'テープだ。どこかで再生できないかな。',
 'P09':'月、それから日。文化祭のプログラムに載ってた。',
 'P10':'練習室……二階の古い部屋か。',
 'P11':'ここに、置き去りにしたのか……。',
 'P12':'玄関に戻ろう。',
 'H01':'職員室を調べてみよう。',
 'H02':'この番号、資料室の何かと合うはず。',
 'H03':'二階に放送室があったな。',
 'H04':'玄関は下だ。下駄箱のところ。',
}
LESSON=[
 ('今日は、登場人物の気持ちを、行動から読み取る話をします。うれしい、と書いてあれば簡単ですよね。でも、作者がそう書かずに、人物の動きだけを見せることもあります。そこを少し、見ていきましょう。',
  "Today we're looking at how actions reveal a character's feelings. It's easy when the writer says someone is happy. But sometimes the writer only shows us what they do. Let's look at how that works."),
 ('たとえば、待ち合わせの場面です。ある人が、時計を見て、また道の向こうを見る。しばらくして、もう一度、時計を見る。これだけでも、何かが伝わってきますね。ただ立っている人とは、少し違う。',
  "Imagine someone waiting to meet a friend. They check the clock, look down the street, then check the clock again. Even that tells us something. It feels different from someone simply standing there."),
 ('さて、その人は怒っているんでしょうか。それとも、楽しみで落ち着かないんでしょうか。時計を見た、という一文だけでは、まだ決められません。前と後の文章も読むと、同じ動作の意味が変わることがあります。',
  "Are they annoyed, or too excited to keep still? Checking the clock doesn't give us enough to decide. The sentences before and after it can change what the same action means."),
 ('友達が来たときに、手を振って走り出すなら、会えるのを楽しみにしていたのかもしれません。反対に、顔をそむけてしまったら、どうでしょう。動作を一つずつつなげて考えると、人物の気持ちが見えてきます。',
  "If they wave and run over when their friend arrives, perhaps they were looking forward to the meeting. What if they turn away instead? Connecting the actions helps us understand the person."),
 ('大事なのは、答えを一つに決めることより、どの言葉からそう考えたのか、説明できることです。隣の人と意見が違っても、それで構いません。文章の中に根拠を探す。その読み方を、覚えておいてください。',
  "What matters is explaining which words led you to your reading. It's fine to disagree with the person beside you. Look for evidence in the passage. That's the habit I want you to remember."),
]
TAPE=[
 ('student_a_0','エフ十二は梱包した。機材ケースは視聴覚室に置いておいて。','Student A: F-12 is packed. Leave the equipment case in the AV room.'),
 ('student_b_0','暗証番号は？',"Student B: What's the combination?"),
 ('student_a_1','文化祭の日付。月、それから日。プログラムと同じ。','Student A: The festival date. Month, then day. Same as the program.'),
 ('student_b_1','誰か、まだ残ってなかった？','Student B: Did someone stay behind?'),
 ('student_a_2','確認したんじゃなかったの？','Student A: I thought you checked.'),
]
receipt={'language':'ja-JP','model':'hexgrad/Kokoro-82M v1.0','model_page':'https://huggingface.co/hexgrad/Kokoro-82M','runtime':'kokoro-onnx 0.6.1 / Misaki Japanese','mode':'local CPU; stock voices; no cloning','model_sha256':hashlib.sha256((CACHE/'kokoro-v1.0.onnx').read_bytes()).hexdigest(),'cast':{'teacher':'jm_kumo','player':'80% jm_kumo / 20% am_michael','student_a':'same student male style','student_b':'jf_alpha'},'clips':[]}

def generate(name,text,role,speed):
    output=SRC/(name+'.wav')
    # Retakes are explicit: deleting an individual generated clip re-renders only it.
    if not output.exists() or not name.startswith('ja_'):
        parts=[]
        for sentence in re.findall(r'[^。！？]+[。！？]?|[。！？]',text):
            phonemes,_=g2p(sentence)
            if not phonemes.strip(): continue
            audio,sr=engine.create(phonemes,voice=cast[role],speed=speed,is_phonemes=True)
            assert sr==RATE
            parts.extend([audio,np.zeros(int(RATE*(.33 if role=='teacher' else .17)))])
        audio=np.concatenate(parts).astype(np.float32)
        # Remove DC, leave dynamics intact; only bound accidental overs.
        audio-=np.mean(audio)
        peak=max(.001,float(np.max(np.abs(audio))))
        if peak>.88: audio*=.88/peak
        sf.write(str(output),audio,RATE,subtype='PCM_16')
    audio,sr=sf.read(str(output))
    receipt['clips'].append({'file':str(output.relative_to(ROOT)).replace('\\','/'),'spoken_text':text,'role':role,'speed':speed,'duration':len(audio)/sr,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'review':'Generated and measured; native-speaker acting/pronunciation review pending.'})
    print(name,round(len(audio)/sr,2),flush=True)
    return audio

if __name__=='__main__':
    lines=json.loads((ROOT/'assets/audio/player_lines.json').read_text(encoding='utf-8'))
    for name,text in PLAYER.items():
        generate('ja_'+name,text,'player',.99 if name not in ['P11','P05'] else .94)
        lines[name].update(file='res://assets/audio/production/ja_'+name+'.wav',spoken_text=text,language='ja-JP',source='Local Kokoro-82M v1.0 stock voice blend; see japanese_voice.json',delivery_review='Japanese retake; native-speaker performance review pending.')
    lesson=np.zeros(RATE*125);captions=[]
    for i,((text,english),start) in enumerate(zip(LESSON,[2,26,50,74,98])):
        audio=generate('ja_teacher_'+str(i),text,'teacher',1.02)
        assert len(audio)/RATE<24.0, 'Teacher paragraph exceeds its slot; retake shorter, do not speed up playback.'
        at=int(start*RATE);lesson[at:at+len(audio)]+=audio*.65
        captions.append({'start':start,'end':start+len(audio)/RATE,'text':'Teacher: '+english,'spoken_text':text})
    sf.write(str(ROOT/'assets/audio/teacher_lesson.wav'),lesson,RATE,subtype='PCM_16')
    tape=np.zeros(RATE*30);cursor=.8;tape_captions=[]
    rng=np.random.default_rng(15101999)
    for i,(name,text,english) in enumerate(TAPE):
        audio=generate('ja_'+name,text,'student_b' if name.startswith('student_b') else 'student_a',1.0)
        # Narrow-band cassette, not a vocal performance effect.
        freq=np.fft.rfftfreq(len(audio),1/RATE)
        audio=np.fft.irfft(np.fft.rfft(audio)*np.minimum(1,freq/180)*np.clip((6000-freq)/1800,0,1),n=len(audio))
        at=int(cursor*RATE);tape[at:at+len(audio)]+=audio*.65
        tape_captions.append({'start':cursor,'end':cursor+len(audio)/RATE+.2,'text':english,'spoken_text':text})
        cursor+=len(audio)/RATE
        if i==2:
            for offset in [.65,1.2]:
                count=int(.10*RATE);knock=rng.normal(0,.035,count)*np.exp(-np.linspace(0,7,count));at=int((cursor+offset)*RATE);tape[at:at+count]+=knock
            tape_captions.append({'start':cursor+.55,'end':cursor+1.65,'text':'[Two faint knocks.]'})
        cursor+=2.7 if i==2 else .7
    duration=max(24,cursor+.8);assert duration<30
    tape=tape[:int(duration*RATE)]+rng.normal(0,.0012,int(duration*RATE))
    sf.write(str(ROOT/'assets/audio/festival_students.wav'),tape,RATE,subtype='PCM_16')
    chatter=np.zeros(RATE*125)
    for name,text,role in [('a','ここ、どう思う？','student_a'),('b','うん、そうかも。','student_b')]:
        generate('ja_chatter_'+name,text,role,1.03)
    for at,name in [(8,'a'),(43,'b'),(73,'a'),(104,'b')]:
        audio,_=sf.read(str(SRC/('ja_chatter_'+name+'.wav')));start=int(at*RATE);chatter[start:start+len(audio)]+=audio*.09
    sf.write(str(ROOT/'assets/audio/classroom_chatter.wav'),chatter,RATE,subtype='PCM_16')
    production=json.loads((ROOT/'assets/audio/production.json').read_text())
    production.update(teacher_language='Japanese; English translated captions.',teacher_captions=captions,tape_captions=tape_captions,voices=receipt['cast'])
    production['files']=[dict(x,duration=duration if x['file']=='festival_students.wav' else x['duration']) for x in production['files']]
    (ROOT/'assets/audio/production.json').write_text(json.dumps(production,indent=2,ensure_ascii=False),encoding='utf-8')
    (ROOT/'assets/audio/player_lines.json').write_text(json.dumps(lines,indent=2,ensure_ascii=False),encoding='utf-8')
    (ROOT/'assets/audio/japanese_voice.json').write_text(json.dumps(receipt,indent=2,ensure_ascii=False),encoding='utf-8')
