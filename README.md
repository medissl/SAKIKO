# SAKIKO / さきこ

A playable, self-contained first-person horror game for **Godot 4.7.2**. Explore a Japanese school after dark, find three brass keys, unlock the entrance, and leave before the floating head finds you.

## Play

Import `project.godot` in Godot 4.7.2, let asset import finish, then press **F6 on main.tscn or F5**. The Compatibility renderer supports integrated desktop graphics. No downloaded assets or Python installation are needed to play.

On this development machine, `launch.ps1` locates the installed Godot executable. A standalone Windows executable is not included; export templates must be installed through Godot to export one.

| Control | Action |
| --- | --- |
| Mouse | Look |
| WASD | Move |
| Shift | Sprint, with no stamina limit |
| E | Collect keys, slide doors, unlock/leave through the entrance |
| F | Flashlight |
| Escape | Pause / resume |

Each run chooses one key from validated desk positions in each third of the school. Look down at desks and approach from an unobstructed side. Once all three keys are collected, return to the shoe lockers, unlock the entrance with E, then press E again to escape.

Break sight by turning corners and using classrooms' second doors. Sakiko opens nearby doors herself. Running is faster than her pursuit speed; walking is slower. There is an 18-second initial detection grace period.

## Included

- Two connected corridors, six rooms, twelve pocket sliding doors, classrooms, infirmary, staff room, piano, shoe lockers, noticeboards, clocks and Japanese signs.
- Textured, foggy environment, cold window lighting, fluorescent flicker, dust, shadow-casting flashlight, restrained film overlay.
- Original sculpted 3D head with recessed eye geometry, shaped nose and cheeks, open grin, concave mouth, individual teeth, hinged lower jaw, and animated layered hair.
- A clearance-aware AStar3D graph, roam/detect/chase/investigate/search states, ray-tested sight and capture, door opening and stuck recovery.
- Live corridor menu, keyboard focus, options, credits, pause, death/retry and escape screens.
- Dedicated 1.65-second animated capture shot and synchronized layered audio.
- Thirteen original PCM WAV sounds, positional breathing, separate ambience and SFX buses. Options persist via Godot's `user://settings.cfg`.

The creator credit is intentionally **Your Name**; edit `show_credits()` in `scripts/game.gd`.

## Project structure

`scripts/game.gd` assembles the school, handles UI, interactions, AI and run state. `scripts/player.gd` handles movement and camera input; `scripts/creature.gd` constructs and animates the head. `assets/` contains real generated textures and sounds. `tools/generate_assets.py` reproduces those assets with NumPy and Pillow; it is a development tool only.

## Verification

Run with an installed Godot console binary:

```powershell
godot --path . -- --verify --quit-after-verify
godot --path . -- --render-audit
```

The first command exercises real scene and physics code, including movement, flashlight, settings persistence, interaction, escape, reset, door navigation, vision occlusion, AI transitions and capture. Assertions require a debug/editor build. The second saves actual rendered views to ignored `tests/artifacts/` and exits. Neither flag is enabled in normal play.

See `tests/VERIFICATION.md` for observed results and remaining limitations. Run duration, sustained pursuit balance, subjective audio quality and accessibility need human playtesting. This is a compact procedural indie game; it does not contain commissioned models or hand-painted environments.
