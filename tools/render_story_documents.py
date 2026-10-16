"""Bake authored document text: Godot's SVG importer does not render SVG text."""
from pathlib import Path
import json
import re
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/story/documents/rendered"
OUT.mkdir(exist_ok=True)
entries = json.loads((ROOT / "assets/story/evidence.json").read_text(encoding="utf-8"))
font_path = Path("C:/Windows/Fonts/georgia.ttf")


def write_page(identifier, data, back):
    landscape = "photo" in data or identifier == "class_photo"
    width, height = ((960, 640) if identifier == "class_photo" else (800, 800)) if landscape else (680, 960)
    image = Image.new("RGB", (width, height), "#c4b99b")
    draw = ImageDraw.Draw(image)
    draw.polygon([(12, 15), (width - 14, 11), (width - 10, height - 18),
                  (10, height - 12)], fill="#d1c8af", outline="#a59b80")
    draw.line([(width // 2, 18), (width // 2 - 3, height - 21)], fill="#c6bda4", width=2)
    body = data.get("reverse", "") if back else data["body"]
    if not body:
        image.save(OUT / f"{identifier}{'_back' if back else ''}.png")
        return
    y = 48
    # Catalog names belong in the journal, never as headings on a personal note.
    if not back and identifier not in {"folded", "account", "letter", "destroy", "belongings"}:
        heading = ImageFont.truetype(str(font_path), 27)
        words = data["title"].split()
        line = ""
        for word in words + [None]:
            candidate = (line + " " + word).strip() if word else ""
            if word is None or draw.textlength(candidate, font=heading) > width - 88:
                draw.text((44, y), line, font=heading, fill="#34302a")
                y += 37
                line = word or ""
            else:
                line = candidate
        draw.line([(44, y + 4), (width - 44, y + 4)], fill="#92866f")
        y += 31
    font = ImageFont.truetype(str(font_path), 30 if landscape else 26)
    body = re.sub(r"\[/?u\]", "", body)
    for paragraph in body.split("\n"):
        if not paragraph:
            y += 18
            continue
        line = ""
        for word in paragraph.split() + [None]:
            candidate = (line + " " + word).strip() if word else ""
            if word is None or draw.textlength(candidate, font=font) > width - 88:
                draw.text((44, y), line, font=font, fill="#34302a")
                if identifier == "maintenance" and not back and "inside" in line:
                    start = 44 + draw.textlength(line.split("inside")[0], font=font)
                    end = start + draw.textlength("inside", font=font)
                    baseline = y + font.getbbox(line)[3] + 2
                    for offset in (0, 4):
                        draw.line([(start, baseline + offset), (end, baseline + offset)], fill="#34302a", width=1)
                y += 40 if landscape else 36
                line = word or ""
            else:
                line = candidate
    if y > height - 40:
        raise ValueError(f"Document text overflow: {identifier}, back={back}")
    image.save(OUT / f"{identifier}{'_back' if back else ''}.png")


for identifier, data in entries.items():
    for back in (False, True):
        write_page(identifier, data, back)
print(f"Rendered {len(entries) * 2} document surfaces.")
