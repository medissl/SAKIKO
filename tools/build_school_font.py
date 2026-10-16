"""Build a small static OFL font with non-overlapping outlines for Godot TextMesh."""
from pathlib import Path
import hashlib, json
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset
from fontTools.ttLib.removeOverlaps import removeOverlaps

ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'.asset-cache/export-templates/NotoSansJP-original.ttf'
font=instantiateVariableFont(TTFont(source),{'wght':400},inplace=True)
chars=set(range(32,127))
for base,pattern in [('scripts','*.gd'),('assets/story','*.json'),('assets/audio','*.json')]:
    for p in (ROOT/base).rglob(pattern): chars.update(map(ord,p.read_text('utf8')))
options=subset.Options();options.name_IDs=['*'];options.name_legacy=True;options.name_languages=['*']
subsetter=subset.Subsetter(options=options);subsetter.populate(unicodes=chars);subsetter.subset(font)
removeOverlaps(font)
names={1:'Sakiko School Sans',2:'Regular',3:'SakikoSchoolSans-Regular-1',4:'Sakiko School Sans Regular',6:'SakikoSchoolSans-Regular',16:'Sakiko School Sans',17:'Regular'}
for record in font['name'].names:
    if record.nameID in names: record.string=names[record.nameID].encode(record.getEncoding())
out=ROOT/'assets/fonts/SakikoSchoolSans.ttf';font.save(out)
receipt={'source':'https://github.com/google/fonts/tree/main/ofl/notosansjp','license':'SIL OFL 1.1; original copyright and license preserved in NotoSansJP-OFL.txt','modification':'Static weight 400, current game character subset, overlapping contours unioned for TextMesh; renamed Sakiko School Sans','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'file':out.name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'glyphs':len(font.getGlyphOrder())}
(out.parent/'NotoSansJP-source.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('SCHOOL FONT BUILT',len(font.getGlyphOrder()),'glyphs,',out.stat().st_size,'bytes')
