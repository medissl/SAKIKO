# Asset provenance

- School geometry, furniture, original creature meshes, shaders and procedural material setup: created in this project.
- `assets/textures/*.png`: generated locally by `tools/generate_assets.py` using seeded noise, line work and stains.
- `assets/audio/*.wav`: original synthesized mono 22,050 Hz 16-bit PCM. The same script creates layered filtered noise, modulation, pitch envelopes and soft distortion. `analysis.json` records peak/RMS measurements. Signals have short endpoint fades and are normalized below digital clipping.
- The two supplied reference images are visual references only. They are neither bundled nor pasted onto the creature. Their copyright ownership was not established, so no redistribution license is claimed for them.
- Typography uses system fonts through Godot SystemFont (`Yu Gothic`, `MS Gothic`, `Georgia`, `Times New Roman`, fallback `Arial`). Font files are not redistributed. Japanese glyph appearance depends on installed font support. Windows development rendering confirmed the Japanese characters display.
- Godot Engine: MIT license, https://godotengine.org/license/. Include Godot's required license information when distributing exported builds, as described on that page.

No stock audio, third-party creature model, face photo texture or externally downloaded game artwork is included. No project-wide redistribution license has been selected by the repository owner.
