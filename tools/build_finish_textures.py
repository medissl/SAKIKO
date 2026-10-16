"""Original small shared atlases and finishes; no reference-image derivatives."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,random,json,hashlib
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/furniture/finish/textures';OUT.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(19991015);font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',11)
def field(base,noise=2):
 a=np.ones((512,512,3))*np.array(base);a+=rng.normal(0,noise,(512,512,1));return Image.fromarray(np.uint8(np.clip(a,0,255)))
for name,base in [('clinic_vinyl',(159,167,151)),('service_tile',(142,151,145)),('ceiling_ivory',(184,182,168))]:
 im=field(base,1.4);d=ImageDraw.Draw(im)
 if name!='ceiling_ivory':
  for x in [0,256,511]:d.line((x,0,x,511),fill=tuple(c-10 for c in base),width=1);d.line((0,x,511,x),fill=tuple(c-10 for c in base),width=1)
 im.save(OUT/(name+'.png'))
palette=[(74,82,72),(104,75,63),(69,81,90),(134,127,103),(105,113,103),(78,67,69),(123,108,80),(85,96,87)]
for folder in [False,True]:
 im=Image.new('RGB',(512,512));d=ImageDraw.Draw(im)
 for i in range(64):
  x=(i%8)*64;y=(i//8)*64
  c=(151+i%4*5,146+i%3*4,128+i%5*2) if folder else palette[i%len(palette)]
  d.rectangle((x,y,x+63,y+63),fill=c);d.line((x+2,y,x+2,y+63),fill=tuple(max(0,v-16) for v in c),width=2)
  d.rectangle((x+13,y+27,x+51,y+47),fill=(177,172,151));d.text((x+17,y+30),str(1996+i%4) if folder else ['LIT','ART','SCI','REF'][i%4],font=font,fill=(63,67,58))
  if folder and i>=48:d.rounded_rectangle((x+24,y+51,x+41,y+57),radius=2,fill=(64,65,55))
  d.line((x+8,y+8,x+55,y+8),fill=tuple(min(255,v+10) for v in c));d.line((x+8,y+55,x+55,y+55),fill=tuple(max(0,v-12) for v in c))
 im.save(OUT/('file_atlas.png' if folder else 'book_atlas.png'))
im=Image.new('RGB',(512,512));d=ImageDraw.Draw(im)
for i in range(64):
 x=i%8*64;y=i//8*64
 d.rectangle((x,y,x+63,y+63),fill=(53+i%3*3,61+i%2*4,59+i%5))
 d.rectangle((x+8,y+22,x+56,y+43),fill=(167,163,142));d.text((x+13,y+26),['AV','F-12','TAPE','SPARE'][i%4],font=font,fill=(48,53,47))
 d.rectangle((x+6,y+4,x+58,y+7),fill=(72,77,72))
im.save(OUT/'case_atlas.png')
im=Image.new('RGBA',(256,256));d=ImageDraw.Draw(im);r=random.Random(27)
for i in range(42):
 x=r.randrange(30,226);y=r.randrange(30,226);d.line((x,y,x+r.randrange(-20,25),y+r.randrange(-7,8)),fill=(55,48,36,r.randrange(25,65)),width=r.choice([1,1,2]))
im.save(OUT/'chair_scuffs.png')
records=[{'file':p.name,'dimensions':list(Image.open(p).size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(OUT.glob('*.png'))]
(OUT/'manifest.json').write_text(json.dumps({'author':'Original authored PIL/numpy textures; build_finish_textures.py','source':'No downloaded or edited source images','files':records},indent=2))
print('FINISH TEXTURES',len(records))
