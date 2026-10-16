"""Original fitted curve groom, exported as ordinary geometry for Godot.
blender --background --python tools/build_sakiko_hair.py
No external add-ons, paid assets, or face/UV edits.
"""
import bpy, math, random, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/sakiko_hair.glb'
rng=random.Random(15101999)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color,roughness):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bsdf=m.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(*color,1)
    bsdf.inputs['Roughness'].default_value=roughness
    return m
mats=[material('BlackHair_'+str(i),c,.68+i*.035) for i,c in enumerate([(.008,.009,.011),(.013,.012,.012),(.019,.017,.017),(.006,.007,.009)])]
def xyz(p):return (p[0],-p[2],p[1])
def point(a,lat):return (1.16*math.sin(a)*math.sin(lat),.13+1.36*math.cos(lat),.08-1.08*math.cos(a)*math.sin(lat))
# Rounded scalp undercoat. Its lower edge stops above the loose strand ends.
verts=[];faces=[];cols=112;rows=30;start=.94
for j in range(rows+1):
    lat=.005+j/rows*2.00
    for i in range(cols+1):verts.append(xyz(point(start+(math.tau-2*start)*i/cols,lat)))
for j in range(rows):
    for i in range(cols):
        a=j*(cols+1)+i;faces.append((a,a+1,a+cols+2,a+cols+1))
mesh=bpy.data.meshes.new('RoundedScalp');mesh.from_pydata(verts,[],faces);mesh.update()
scalp=bpy.data.objects.new('ScalpUndercoat',mesh);bpy.context.collection.objects.link(scalp);scalp.data.materials.append(mats[0])
for p in scalp.data.polygons:p.use_smooth=True
# Complete frontal crown: the side groom must not leave a cut-away forehead cap.
verts=[];faces=[];cols=96;rows=16
for j in range(rows+1):
    for i in range(cols+1):verts.append(xyz(point(-start+2*start*i/cols,.001+j/rows*.72)))
for j in range(rows):
    for i in range(cols):
        a=j*(cols+1)+i;faces.append((a,a+1,a+cols+2,a+cols+1))
cap=bpy.data.meshes.new('FrontalCrown');cap.from_pydata(verts,[],faces);cap.update()
obj=bpy.data.objects.new('FrontalCrown',cap);bpy.context.collection.objects.link(obj);cap.materials.append(mats[0])
for p in cap.polygons:p.use_smooth=True

def strand_object(name,count,fine):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=1
    curve.bevel_depth=.0032 if fine else .009;curve.bevel_resolution=0;curve.resolution_u=2
    for m in mats:curve.materials.append(m)
    for i in range(count):
        a=start+(math.tau-2*start)*(i+rng.random()*.65)/count
        root_lat=rng.uniform(.08,.82)
        end_y=rng.uniform(-1.88,-1.20)
        phase=rng.uniform(0,math.tau);offset=rng.uniform(.008,.055)
        s=curve.splines.new('POLY');s.points.add(20)
        s.material_index=rng.choices(range(4),[6,3,1,3])[0]
        for j,p in enumerate(s.points):
            t=j/20
            if t<.50:
                lat=root_lat+(1.51-root_lat)*t/.50
                base=point(a+.025*math.sin(phase+t*4),lat)
                x,y,z=base
                x+=math.sin(a)*offset;z-=math.cos(a)*offset
            else:
                f=(t-.50)/.50;aa=a+.035*math.sin(phase+f*2.0)*f
                x=math.sin(aa)*(1.16-.10*f+offset)
                y=.212+(end_y-.212)*f
                z=.08-math.cos(aa)*(1.08-.09*f+offset)+f*f*.12
                # Loose slight bends, not perfectly parallel cylinder strips.
                x+=math.sin(phase+f*5)*.025*f*f
                z+=math.cos(phase+f*4)*.025*f*f
            p.co=(*xyz((x,y,z)),1)
            p.radius=(.7+.3*math.sin(t*math.pi))*(max(.025,(1-t)**.32))
    obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj)
    return obj
strand_object('MainLocks',680,False)
strand_object('FineStrands',1600,True)
# A few actual forehead strands continue the photographed fringe without hiding eyes.
curve=bpy.data.curves.new('ForeheadWisps','CURVE');curve.dimensions='3D';curve.bevel_depth=.003;curve.bevel_resolution=0
curve.materials.append(mats[0])
for i in range(90):
    x=rng.uniform(-.64,.64);end_y=rng.uniform(.61,.91)
    s=curve.splines.new('POLY');s.points.add(10)
    for j,p in enumerate(s.points):
        t=j/10;y=1.27+(end_y-1.27)*t
        xx=x*(.35+.65*t)+.014*math.sin(t*5+i)
        z=-.18-.58*math.sin(t*math.pi*.5)
        p.co=(*xyz((xx,y,z)),1);p.radius=max(.02,(1-t)**.45)
wisps=bpy.data.objects.new('ForeheadWisps',curve);bpy.context.collection.objects.link(wisps)
# Convert now: no Blender hair system or shader dependency ships with the game.
(ROOT/'.asset-cache').mkdir(exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'.asset-cache/sakiko_hair_groom.blend'))
for obj in list(bpy.context.scene.objects):
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    if obj.type=='CURVE':bpy.ops.object.convert(target='MESH')
    for p in obj.data.polygons:p.use_smooth=True
    obj.select_set(False)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects)
receipt={'asset':'assets/characters/sakiko_hair.glb','source':'Original Blender 5.0 curve groom authored by tools/build_sakiko_hair.py','mode':'offline Blender curves converted to solid geometry; no provider','strands':2370,'triangles':triangles,'sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'axes':'Godot +Y up; face looks -Z','checks':'Export succeeded. Runtime multi-angle checks are separate; see tests/artifacts/creature-final.log.'}
(ROOT/'assets/characters/sakiko_hair.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps(receipt))
