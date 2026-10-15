from pathlib import Path
import struct, math, random
P=Path(__file__).resolve().parents[1]/'assets/fonts'
P.mkdir(parents=True,exist_ok=True)
def pack(fmt,*x):return struct.pack('>'+fmt,*x)
# Original hand-cut narrow lettering, drawn as angular strokes with needle terminals.
paths={
'A':[[(50,0),(260,790),(475,0)],[(135,290),(395,310)]],
'B':[[(70,0),(70,780),(320,770),(460,630),(330,430),(70,410)],[(160,425),(390,400),(470,190),(320,10),(70,0)]],
'C':[[(470,690),(340,800),(130,740),(55,510),(65,180),(210,-10),(450,85)]],
'D':[[(65,0),(65,780),(300,760),(460,560),(470,230),(310,15),(65,0)]],
'E':[[(460,790),(70,760),(70,0),(470,25)],[(70,400),(390,410)]],
'F':[[(65,0),(65,780),(470,790)],[(70,415),(390,430)]],
'G':[[(460,690),(330,790),(120,730),(55,460),(75,160),(250,-10),(465,90),(460,380),(300,370)]],
'H':[[(70,0),(70,800)],[(465,0),(465,790)],[(70,390),(465,415)]],
'I':[[(140,790),(395,800)],[(270,790),(255,-10)],[(115,0),(400,10)]],
'J':[[(125,790),(470,790)],[(400,780),(400,140),(270,-5),(80,80),(55,220)]],
'K':[[(70,0),(70,800)],[(470,790),(75,330),(465,-10)]],
'L':[[(70,790),(70,0),(470,20)]],
'M':[[(55,0),(80,790),(265,350),(460,800),(485,0)]],
'N':[[(60,0),(65,790),(465,0),(460,800)]],
'O':[[(265,810),(105,720),(55,450),(100,120),(265,-10),(440,110),(485,420),(425,725),(265,810)]],
'P':[[(65,0),(65,790),(330,780),(470,620),(400,425),(65,400)]],
'Q':[[(265,810),(105,720),(55,450),(100,120),(265,-10),(440,110),(485,420),(425,725),(265,810)],[(300,170),(490,-95)]],
'R':[[(65,0),(65,790),(330,780),(470,620),(400,425),(65,400)],[(270,415),(490,-10)]],
'S':[[(465,720),(330,800),(115,710),(70,520),(390,320),(450,145),(285,-5),(65,80)]],
'T':[[(30,780),(510,800)],[(270,790),(250,-5)]],
'U':[[(65,790),(65,150),(230,-5),(435,100),(465,800)]],
'V':[[(55,800),(250,-15),(480,800)]],
'W':[[(40,800),(110,-5),(270,420),(420,0),(500,810)]],
'X':[[(55,800),(480,0)],[(475,800),(50,0)]],
'Y':[[(45,800),(265,400),(485,800)],[(265,400),(250,-5)]],
'Z':[[(50,790),(480,800),(60,0),(490,10)]]}
paths.update({
'0':paths['O'],'1':[[(160,610),(280,790),(280,0)],[(160,0),(400,0)]],
'2':[[(65,620),(165,785),(380,770),(465,590),(65,0),(480,0)]],
'3':[[(65,740),(375,790),(465,600),(270,420),(445,270),(405,70),(130,0),(55,100)]],
'4':[[(370,0),(370,790),(65,250),(500,260)]],
'5':[[(465,790),(80,790),(75,430),(340,445),(460,270),(395,65),(100,0),(55,80)]],
'6':[[(445,745),(290,800),(85,580),(65,165),(200,0),(395,55),(470,260),(355,425),(75,410)]],
'7':[[(55,790),(480,790),(180,0)]],
'8':[[(260,800),(90,680),(135,465),(410,325),(450,130),(270,-5),(75,130),(120,325),(400,465),(455,680),(260,800)]],
'9':[[(455,380),(110,395),(55,590),(170,775),(370,780),(465,600),(430,200),(260,0),(85,65)]],
'-':[[(100,360),(430,370)]],'.':[[(255,10),(265,40)]],',':[[(265,50),(235,-80)]],
':':[[(260,200),(265,220)],[(260,550),(265,570)]],'/':[[(65,0),(465,790)]],
'!':[[(265,190),(285,810)],[(260,0),(265,35)]],
'?':[[(65,620),(170,790),(375,760),(460,585),(270,365),(260,230)],[(260,0),(265,30)]],
'\u2019':[[(260,800),(230,690)]],"' ".strip():[[(260,800),(230,690)]],
'(':[[(350,810),(200,620),(150,350),(200,80),(350,-60)]],')':[[(170,810),(320,620),(370,350),(320,80),(170,-60)]],
'[':[[(380,800),(160,800),(160,0),(380,0)]],']':[[(160,800),(380,800),(380,0),(160,0)]],
'|':[[(265,-30),(265,810)]],'+':[[(80,400),(450,400)],[(265,180),(265,620)]],
'=':[[(80,300),(450,300)],[(80,510),(450,510)]],
})
def stroke(a,b,width,seed):
    rnd=random.Random(seed); dx=b[0]-a[0];dy=b[1]-a[1];length=math.hypot(dx,dy);nx=-dy/length;ny=dx/length
    result=[]
    for side in [1,-1]:
        sequence=range(8) if side==1 else range(7,-1,-1)
        for i in sequence:
            t=i/7; w=width*(.22 if i in [0,7] else rnd.uniform(.65,1.15))
            result.append((round(a[0]+dx*t+nx*w*side),round(a[1]+dy*t+ny*w*side)))
    return result
chars=['.notdef','space']+list(paths)
glyphs=[]
for idx,char in enumerate(chars):
    contours=[]
    if char not in ['.notdef','space']:
        for j,path in enumerate(paths[char]):
            for k,(a,b) in enumerate(zip(path,path[1:])):contours.append(stroke(a,b,34,idx*100+j*10+k))
        # Long thin spurs extend the cut-paper strokes.
        for j,path in enumerate(paths[char][:1]):
            a=path[0];contours.append([(a[0]-10,a[1]+20),(a[0]+7,a[1]+70),(a[0]+16,a[1]-48)])
    if not contours:glyphs.append(b'');continue
    pts=[q for c in contours for q in c];xs=[q[0] for q in pts];ys=[q[1] for q in pts]
    data=pack('hhhhh',len(contours),min(xs),min(ys),max(xs),max(ys));n=0
    for c in contours:n+=len(c);data+=pack('H',n-1)
    data+=pack('H',0)+bytes([1]*len(pts))
    last=0
    for x in xs:data+=pack('h',x-last);last=x
    last=0
    for y in ys:data+=pack('h',y-last);last=y
    glyphs.append(data+b'\0'*((-len(data))%4))
off=[0]
for g in glyphs:off.append(off[-1]+len(g))
count=len(chars);tables={}
tables['glyf']=b''.join(glyphs);tables['loca']=b''.join(pack('I',x) for x in off)
tables['head']=pack('IIIIHHQQhhhhHHhhh',0x10000,0x10000,0,0x5F0F3CF5,3,1000,0,0,-50,-120,550,880,0,8,2,1,0)
tables['hhea']=pack('IhhhHhhhhhhhhhhhH',0x10000,900,-150,0,570,-50,-50,550,1,0,0,0,0,0,0,0,count)
tables['hmtx']=b''.join(pack('Hh',260 if c=='space' else 570,0) for c in chars)
tables['maxp']=pack('IH'+'H'*13,0x10000,count,2048,128,0,0,1,0,0,0,0,0,0,0,0)
# Version 0 OS/2 table; unrestricted embedding for this original typeface.
tables['OS/2']=pack('HhHHH'+'h'*11,0,570,500,5,0,650,600,0,75,650,600,0,350,50,250,0)+bytes(10)+pack('IIII',1,0,0,0)+b'SAKI'+pack('HHHhhhHH',64,32,122,900,-150,0,900,150)
tables['post']=pack('IihhIIIII',0x30000,0,-75,30,0,0,0,0,0)
entries=[]
for cp in sorted(set([32]+[ord(c) for c in paths]+list(range(97,123)))):
    ch=chr(cp).upper(); gid=1 if cp==32 else chars.index(ch);entries.append((cp,gid))
entries.append((65535,0));seg=len(entries);power=2**int(math.log2(seg));fmt=pack('HHHHHHH',4,16+seg*8,0,seg*2,power*2,int(math.log2(power)),seg*2-power*2)
fmt+=b''.join(pack('H',c) for c,g in entries)+pack('H',0)+b''.join(pack('H',c) for c,g in entries)+b''.join(pack('H',(g-c)%65536) for c,g in entries)+bytes(seg*2)
tables['cmap']=pack('HHHHI',0,1,3,1,12)+fmt
names={1:'Sakiko Thorn',2:'Regular',3:'Medi SAKIKO Thorn 1.0',4:'Sakiko Thorn',5:'Version 1.0',6:'SakikoThorn'}
strings=b''; records=b''
for nid,value in names.items():
    v=value.encode('utf-16-be');records+=pack('HHHHHH',3,1,0x409,nid,len(v),len(strings));strings+=v
tables['name']=pack('HHH',0,len(names),6+12*len(names))+records+strings
def checksum(data):
    data+=bytes((-len(data))%4);return sum(struct.unpack('>'+str(len(data)//4)+'I',data))&0xffffffff
n=len(tables);power=2**int(math.log2(n));header=pack('IHHHH',0x10000,n,power*16,int(math.log2(power)),n*16-power*16)
directory=b'';body=b'';offset=12+n*16;head_offset=0
for tag,data in sorted(tables.items()):
    directory+=tag.encode()+pack('III',checksum(data),offset,len(data))
    if tag=='head':head_offset=offset
    pad=bytes((-len(data))%4);body+=data+pad;offset+=len(data)+len(pad)
font=bytearray(header+directory+body);font[head_offset+8:head_offset+12]=pack('I',(0xB1B0AFBA-checksum(font))&0xffffffff)
(P/'SakikoThorn.ttf').write_bytes(font)
print('Original typeface:',len(font),'bytes')
