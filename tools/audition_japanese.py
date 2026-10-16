"""Only the three requested auditions; never rebuild the gameplay library."""
from produce_japanese_voice import generate,cast,engine,receipt,ROOT
import json
cast['player']=engine.get_voice_style('jm_kumo')
for name,text,role,speed in [
 ('ja_audition_confused','みんな、どこに行ったんだ？','player',1.04),
 ('ja_audition_realization','文化祭の展示……二階か。','player',1.02),
 ('ja_audition_teacher','教科書の四十二ページを開いてください。','teacher',.98)]:generate(name,text,role,speed)
receipt['cast']['player']='jm_kumo only; no English style blend'
receipt['purpose']='Three short candidate auditions only. Native pronunciation/acting and youthful register not approved. Gameplay player/teacher disabled pending acceptable delivery.'
(ROOT/'assets/audio/japanese_auditions.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
