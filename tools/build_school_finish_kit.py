"""Original compact school finishing kit. Metres, Y-up engine specification.
Blender --background --python tools/build_school_finish_kit.py
No downloaded geometry, paid provider or copyrighted screenshot textures.
"""
import bpy, math, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/furniture/finish';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,c):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.86;p.inputs['Specular IOR Level'].default_value=.18
 return m
M={k:material('Kit'+k,c) for k,c in dict(Wood=(.24,.19,.14),Steel=(.30,.34,.32),Ivory=(.63,.65,.59),Linen=(.69,.70,.64),Fabric=(.20,.29,.28),Dark=(.045,.055,.052),Paper=(.67,.64,.54)).items()}
def xyz(p):return (p[0],-p[2],p[1])
def box(name,p,s,mat='Steel',bevel=.012):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.name=name;o.dimensions=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(M[mat])
 if bevel:
  mod=o.modifiers.new('Rounded manufactured edges','BEVEL');mod.width=min(bevel,min(s)*.35);mod.segments=2
  bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def rod(name,a,b,r,mat='Steel',vertices=12):
 av=Vector(xyz(a));bv=Vector(xyz(b));d=bv-av
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(av+bv)/2);o=bpy.context.object;o.name=name;o.rotation_quaternion=d.to_track_quat('Z','Y');o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y');o.data.materials.append(M[mat])
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return o
def tube(name,points,r,mat='Steel'):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=1;c.bevel_depth=r;c.bevel_resolution=1
 sp=c.splines.new('POLY');sp.points.add(len(points)-1)
 for v,p in zip(sp.points,points):v.co=(*xyz(p),1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);c.materials.append(M[mat]);return o
def handle(p,width=.13):
 tube('Pull handle',[(p[0]-width/2,p[1],p[2]),(p[0]-width/2,p[1],p[2]-.025),(p[0]+width/2,p[1],p[2]-.025),(p[0]+width/2,p[1],p[2])],.009)
def cabinet(w=1.4,d=.55,h=.84):
 box('Recessed toe plinth',(0,.045,0),(w-.08,.09,d-.06),'Dark')
 box('Painted cabinet carcass',(0,h/2,0),(w,h-.06,d),'Ivory')
 for side in [-1,1]:
  for row in range(3):
   y=.19+row*(h-.12)/3
   box('Inset drawer',(side*w*.25,y,-d/2-.012),(w/2-.025,(h-.12)/3-.018,.026),'Ivory',.006);handle((side*w*.25,y,-d/2-.03))
 box('Continuous worktop',(0,h+.015,0),(w+.035,.045,d+.04),'Wood')
def desk(w=1.4,d=.8):
 box('Rounded worktop',(0,.82,0),(w,.055,d),'Wood',.018)
 for z in [-d*.41,d*.41]:box('Steel frame',(0,.75,z),(w-.10,.11,.025))
 box('Pedestal',(w/2-.22,.38,.01),(.39,.72,d-.1),'Ivory')
 for y in [.17,.39,.61]:
  box('Drawer front',(w/2-.22,y,-d/2+.035),(.35,.20,.025),'Ivory',.006);handle((w/2-.22,y,-d/2+.015),.12)
 for z in [-d*.40,d*.40]:rod('Leg',(-w/2+.06,.025,z),(-w/2+.06,.79,z),.022)
def bed():
 box('Bed frame',(0,.53,0),(1.45,.10,2.1),'Steel',.035)
 box('Mattress piping',(0,.61,0),(1.43,.16,2.03),'Ivory',.045)
 box('Matte linen',(0,.70,0),(1.42,.13,2.01),'Linen',.055)
 box('Pillow',(0,.82,-.65),(.88,.17,.44),'Linen',.07)
 for x in [-.66,.66]:
  for z in [-.94,.94]:rod('Bed leg',(x,0,z),(x,.55,z),.026)
 for end in [-1,1]:
  tube('Continuous end rail',[(-.69,.52,end),( -.69,1.0,end),(.69,1.0,end),(.69,.52,end)],.023)
  for x in [-.36,0,.36]:rod('End slat',(x,.56,end),(x,.98,end),.012)
 box('Folded bed cover',(0,.80,.60),(1.13,.09,.60),'Fabric',.035)
 for z in [.4,.55,.70,.82]:box('Fabric folds',(0,.847,z),(1.03,.008,.012),'Fabric',.003)
def sink():
 bowl=box('Pressed stainless basin',(0,.75,0),(.92,.25,.62),'Steel',0)
 cut=box('Basin cavity tool',(0,.84,0),(.76,.32,.46),'Steel',0)
 bpy.context.view_layer.objects.active=bowl;mod=bowl.modifiers.new('Recessed basin','BOOLEAN');mod.object=cut;mod.operation='DIFFERENCE';bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
 mod=bowl.modifiers.new('Rolled rim','BEVEL');mod.width=.018;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 box('Rear splashback',(0,1.01,.32),(.94,.28,.025),'Ivory')
 for x in [-.39,.39]:
  for z in [-.23,.23]:rod('Sink support',(x,0,z),(x,.67,z),.021)
 tube('Connected waste trap',[(0,.64,0),(0,.35,0),(0,.27,.12),(0,.35,.25),(0,.35,.49)],.023)
 tube('Swan neck faucet',[(.20,.87,.24),(.20,1.16,.24),(.20,1.20,.18),(.20,1.20,-.02),(.20,1.14,-.02)],.018)
 rod('Faucet mounting plate',(.20,.86,.24),(.20,.89,.24),.039)
 rod('Tap lever',(.12,1.0,.24),(.28,1.0,.24),.012)
 rod('Drain',(0,.638,0),(0,.644,0),.025,'Dark')
def medicine():
 box('Wall cabinet',(0,.33,0),(.85,.65,.25),'Ivory')
 for x in [-.21,.21]:
  box('Inset frosted panel',(x,.34,-.133),(.38,.50,.02),'Fabric');handle((x+(.13 if x<0 else -.13),.30,-.15),.055)
def cubby():
 box('Rear panel',(0,.56,.20),(1.4,1.12,.025),'Wood')
 for x in [-.70,-.235,.235,.70]:box('Upright',(x,.56,0),(.025,1.12,.42),'Wood')
 for y in [.025,.38,.75,1.12]:box('Shelf',(0,y,0),(1.42,.025,.42),'Wood')
def files():
 box('Archive box',(0,.14,0),(.36,.28,.32),'Paper')
 box('Lift off lid',(0,.285,0),(.38,.035,.34),'Paper')
 box('Label holder',(0,.17,-.166),(.19,.055,.008),'Ivory',.002)
 box('Pull slot',(0,.09,-.171),(.085,.017,.008),'Dark',.003)
def office_chair():
 rod('Pedestal',(0,.06,0),(0,.45,0),.025,'Dark')
 for i in range(5):
  a=i*math.tau/5;end=(math.cos(a)*.30,.07,math.sin(a)*.30)
  rod('Star base',(0,.10,0),end,.018,'Dark');box('Caster',(end[0],.035,end[2]),(.065,.06,.055),'Dark',.02)
 box('Padded seat',(0,.47,0),(.49,.10,.45),'Fabric',.04)
 box('Shaped backrest',(0,.78,.19),(.48,.51,.08),'Fabric',.045)
 for x in [-.26,.26]:
  tube('Arm support',[(x,.43,.10),(x,.65,.10),(x,.65,-.12)],.015,'Dark');box('Arm pad',(x,.66,-.01),(.065,.04,.30),'Dark')
def workbench():
 box('Phenolic laboratory top',(0,.83,0),(1.3,.06,1.3),'Dark',.018)
 for x in [-.55,.55]:
  for z in [-.55,.55]:box('Box steel leg',(x,.40,z),(.05,.8,.05))
 for z in [-.55,.55]:box('Deep steel apron',(0,.73,z),(1.13,.16,.04),'Ivory')
 box('Instrument drawer',(0,.68,-.58),(.65,.15,.08),'Ivory');handle((0,.68,-.63),.20)
 tube('Foot rest',[(-.55,.18,-.55),(-.55,.18,.55),(.55,.18,.55),(.55,.18,-.55)],.018)
def mixer():
 box('Analog mixer case',(0,.10,0),(.82,.20,.43),'Dark',.018)
 box('Control face',(0,.207,0),(.78,.016,.39),'Steel',.008)
 for col in range(6):
  x=-.31+col*.124
  for z in [-.13,-.05]:rod('Rotary knob',(x,.22,z),(x,.25,z),.018,'Dark')
  box('Fader slot',(x,.221,.09),(.008,.005,.13),'Dark',.001);box('Fader cap',(x,.23,.07+(col%3)*.02),(.045,.018,.02),'Ivory',.004)
def lamp():
 box('Weighted task lamp base',(0,.018,0),(.21,.036,.16),'Dark',.035)
 tube('Task lamp arm',[(0,.04,0),(0,.28,.035),(0,.48,-.10)],.012,'Steel')
 box('Shade',(0,.47,-.17),(.25,.075,.18),'Fabric',.025)
def phone():
 box('Office telephone',(0,.04,0),(.24,.08,.21),'Ivory',.025)
 box('Handset bridge',(0,.11,.04),(.27,.055,.065),'Dark',.025)
 for x in [-.11,.11]:box('Receiver',(x,.10,.025),(.055,.065,.08),'Dark',.018)
 for x in [-.04,0,.04]:
  for z in [-.065,-.03,.005]:box('Key',(x,.085,z),(.023,.01,.018),'Dark',.003)
def bedside():
 box('Bedside cabinet',(0,.35,0),(.54,.65,.48),'Ivory')
 box('Raised tray rim',(0,.70,0),(.57,.035,.51),'Steel')
 box('Drawer',(0,.52,-.25),(.48,.18,.025),'Ivory');handle((0,.52,-.27))
 box('Recessed lower shelf',(0,.22,-.245),(.43,.30,.015),'Fabric')
def bench():
 box('Bench seat',(0,.45,0),(1.8,.08,.52),'Wood',.025)
 for x in [-.72,.72]:
  tube('Bench frame',[(x,0,-.21),(x,.42,-.21),(x,.42,.21),(x,0,.21)],.025)
 for y in [.65,.84]:box('Back slat',(0,y,.23),(1.8,.14,.045),'Wood')
 for x in [-.72,.72]:rod('Back support',(x,.43,.23),(x,.93,.23),.019)
def stool():
 rod('Rounded stool seat',(0,.43,0),(0,.48,0),.18,'Wood',24)
 for i in range(3):
  a=i*math.tau/3;rod('Splayed stool leg',(math.cos(a)*.21,0,math.sin(a)*.21),(math.cos(a)*.11,.43,math.sin(a)*.11),.018)
 points=[(math.cos(i*math.tau/16)*.16,.18,math.sin(i*math.tau/16)*.16) for i in range(17)];tube('Foot ring',points,.009)
def headphones():
 points=[(math.cos(i*math.pi/16)*.15,.07+math.sin(i*math.pi/16)*.18,0) for i in range(17)]
 tube('Headphone band',points,.017,'Dark')
 for x in [-.15,.15]:box('Ear cup',(x,.06,0),(.055,.13,.10),'Fabric',.025)
def microscope():
 box('Microscope foot',(0,.025,0),(.18,.05,.24),'Ivory',.02)
 tube('Microscope arm',[(0,.05,.08),(0,.20,.10),(0,.30,.04)],.032,'Ivory')
 box('Specimen stage',(0,.17,-.025),(.16,.025,.13),'Dark')
 rod('Optical tube',(0,.29,-.025),(0,.40,.01),.027,'Dark')
 rod('Objective',(0,.20,-.035),(0,.29,-.035),.019)
 rod('Focus dial',(-.07,.24,.05),(.07,.24,.05),.025,'Dark')
def dispenser():
 box('Water cooler cabinet',(0,.47,0),(.35,.94,.35),'Ivory',.025)
 box('Tap recess',(0,.63,-.183),(.27,.30,.016),'Dark')
 for x in [-.07,.07]:rod('Water tap',(x,.69,-.18),(x,.69,-.22),.013)
 box('Drip tray',(0,.46,-.205),(.28,.025,.13),'Steel')
 rod('Bottle shoulder',(0,.96,0),(0,1.25,0),.12,'Fabric',20)
 rod('Bottle base',(0,1.25,0),(0,1.29,0),.10,'Fabric',20)
def cardigan():
 box('Folded cardigan',(0,.025,0),(.32,.05,.26),'Fabric',.018)
 for side in [-1,1]:box('Folded sleeve',(side*.11,.06,.01),(.09,.035,.24),'Fabric',.014)
 tube('Collar seam',[(-.055,.058,-.125),(0,.058,-.075),(.055,.058,-.125)],.004,'Ivory')
 for z in [-.02,.04,.1]:box('Button',(0,.054,z),(.009,.004,.009),'Dark',.002)
def projector():
 box('Projector housing',(0,.09,0),(.42,.15,.31),'Ivory',.025)
 for x in [-.15,.15]:
  for z in [-.10,.10]:box('Rubber foot',(x,.013,z),(.045,.025,.045),'Dark',.009)
 rod('Lens bezel',(.095,.10,-.16),(.095,.10,-.20),.052,'Dark',24)
 rod('Lens cap',(.095,.10,-.201),(.095,.10,-.205),.043,'Steel',24)
 for i in range(7):box('Air vent',(-.12+i*.025,.169,.035),(.012,.005,.17),'Dark',.002)
 rod('Focus wheel',(.095,.16,-.11),(.095,.18,-.11),.026,'Dark',16)
def export(name,builder):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);builder()
 for o in list(bpy.context.scene.objects):
  if o.type=='CURVE':
   bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
 # Join per material to keep draw calls bounded while preserving bevel silhouettes.
 for mat in M.values():
  nodes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.active_material==mat]
  if nodes:
   bpy.ops.object.select_all(action='DESELECT')
   for o in nodes:o.select_set(True)
   bpy.context.view_layer.objects.active=nodes[0];bpy.ops.object.join();nodes[0].name=mat.name
 bpy.ops.object.select_all(action='SELECT');path=OUT/(name+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_apply=True)
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];triangles=0
 for o in objects:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
 assert triangles<12000,(name,triangles)
 return dict(name=name,file=str(path.relative_to(ROOT)),triangles=triangles,materials=len(objects),sha256=hashlib.sha256(path.read_bytes()).hexdigest())
records=[]
for name,builder in [('teacher_desk',lambda:desk(1.25,.65)),('staff_desk',lambda:desk(1.8,.85)),('broadcast_desk',lambda:desk(2.4,1.0)),('av_bench',lambda:desk(2,.85)),('nurse_station',desk),('clinic_bed',bed),('sink_station',sink),('medicine_cabinet',medicine),('class_cubby',cubby),('archive_box',files),('office_chair',office_chair),('laboratory_bench',workbench),('broadcast_mixer',mixer),('task_lamp',lamp),('office_phone',phone),('flat_files',lambda:cabinet(1.4,.60,.74)),('demo_bench',lambda:cabinet(3,.8,.82)),('art_workbench',lambda:desk(2.2,1.2)),('prep_island',lambda:desk(2.4,.8)),('bedside_stand',bedside),('common_bench',bench),('art_stool',stool),('headphones',headphones),('microscope',microscope),('water_dispenser',dispenser),('folded_cardigan',cardigan),('av_projector',projector)]:records.append(export(name,builder))
(OUT/'manifest.json').write_text(json.dumps({'author':'Original project geometry authored in build_school_finish_kit.py','license':'Original project content; no third-party source geometry','coordinates':'Godot metres, Y up, floor-contact origin; fronts -Z','policy':'Under 12k triangles per complete asset, joined by shared palette material, no embedded lights/physics/animation','source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'assets':records},indent=2))
print('FINISH KIT EXPORTED',len(records))
