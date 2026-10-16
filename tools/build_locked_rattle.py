"""A short, dry blocked-handle rattle from the project's admitted CC0 lock foley."""
from pathlib import Path
import hashlib
import json
import numpy as np
import soundfile as sf

root = Path(__file__).resolve().parents[1]
folder = root / "assets/audio"
rate = 24000
result = np.zeros(int(rate * .68))
sources = []
for name, at, gain in [("lock_turn.wav", 0, .95), ("latch.wav", .12, .8),
                        ("lock_turn.wav", .27, .7), ("latch.wav", .39, .55)]:
    path = folder / name
    audio, source_rate = sf.read(path, always_2d=True)
    audio = audio.mean(axis=1)
    audio = np.interp(np.arange(int(len(audio)*rate/source_rate))/rate,
                      np.arange(len(audio))/source_rate, audio)
    audio -= audio.mean()
    start = int(at*rate)
    end = min(len(result), start+len(audio))
    result[start:end] += audio[:end-start]*gain
    if name not in [item["file"] for item in sources]:
        sources.append({"file": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
result *= .60/max(.001, np.abs(result).max())
result[:240] *= np.linspace(0, 1, 240)
result[-960:] *= np.linspace(1, 0, 960)
target = folder / "locked_rattle.wav"
sf.write(target, result, rate, subtype="PCM_16")
receipt = {"file": "res://assets/audio/locked_rattle.wav", "sources": sources,
           "license": "CC0-1.0; source authors and original URLs in recorded_foley.json",
           "processing": "Two recorded lock turns and two restrained handle catches; mono, no pitch shift, endpoint fades, 0.60 peak.",
           "duration": len(result)/rate, "sha256": hashlib.sha256(target.read_bytes()).hexdigest()}
(folder/"locked_rattle_provenance.json").write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
print("Built", target.name)
