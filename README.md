# SAKIKO / さきこ

A playable first-person Japanese school horror game for Godot 4.7.2. A present-day male student falls asleep in class and wakes after dark. Follow the festival evidence, uncover Sakiko's history, collect four entrance keys and escape.

## Play

Import `project.godot` in Godot 4.7.2, allow assets to import, then press F5. `launch.ps1` locates the installed Godot executable on this development machine. Runtime assets are bundled. The Mobile renderer uses Vulkan and supports the real flashlight projector, shadows and 4x MSAA. This replaces Compatibility, which ignored the old projector. A standalone executable is not included; install Godot export templates to export one. Include story JSON/text files in any custom export filter.

| Control | Action |
| --- | --- |
| Mouse / WASD | Look / move |
| Shift | Sprint while stamina lasts |
| E | Doors, items, evidence and physical puzzles |
| F | Flashlight |
| J | Evidence journal |
| Escape | Pause / return from inspection |
| E, Space or Escape during intro | Skip to night |
| Click, E, Enter or Space during ending | Reveal current screen, then separately advance |
| Hold Space / Shift during credits | Accelerate |
| Escape or Skip credits button | Return to menu |

Four distinct puzzles connect the desk, festival display, AV recording and concealed scenery storeroom. Nearby photographs, sketches and labels provide the clues. Recording captions and a stored transcript keep its shelf clue solvable with audio muted. Important evidence is retained in J, including photograph reverses. See `docs/LAYOUT_AND_PUZZLES.md` for the route and coordinates.

Collected entrance keys create in-memory checkpoints. RETURN TO CHECKPOINT preserves keys, evidence and puzzle progress, restores stamina and places Sakiko far away. RESTART RUN clears the run, evidence and ending state. Checkpoints do not survive closing the game.

## Presentation

- Twelve primary rooms, twenty-four sliding doors, connected corridor loops and a concealed scenery store.
- Phototextured desks/chairs and worn surfaces, textured classroom figures, selected exterior windows with frost/blinds, distant courtyard projection and restrained foliage movement.
- A continuous 3D face and mouth, closed rear skull, curved textured dental arches and dense hair covering the back and temples. The original face texture remains. The old independently cut jaw/lip meshes were removed to fix close-up cracks and stretched edges.
- A female recorded attack scream synchronized with the lunge, male pain grunt during the mouth dive, red YOU DIED screen and checkpoint recovery. Player exhaustion uses recorded male breathing. Sakiko's humming/laughter/screaming are recorded female vocals.
- Original horror typography for menus, HUD, prompts, puzzles and journal navigation. Document/ending prose uses readable serif text. The bell tagline remains. No em dashes are used in runtime prose.
- The exact revised student/festival story, split at paragraph boundaries across three screens without chapter titles. Soft ordered word reveals, adjustable speed/instant display, manual progression, final silence, scrolling credits and menu return.

Original development categories credit medissl. Separate acknowledgments preserve real asset creators and license notices; see `ASSET_SOURCES.md` and `GODOT_ENGINE_LICENSE.txt`. Narrative consistency is recorded in `docs/NARRATIVE_CONTINUITY.md`. Chilla's Art reference research and its application are in `docs/ATMOSPHERE.md`.

## Development checks

```powershell
godot --path . -- --verify --quit-after-verify
godot --path . -- --render-audit
godot --path . -- --presentation-audit
```

The integration suite runs real scene/physics and UI code. Render audits save actual views to ignored `tests/artifacts/`, including the head from four directions, jumpscare, evidence, ending at 960x540 / 1280x720 / 1920x1080, credits and menu return. See `tests/VERIFICATION.md` for the latest result and limitations. Subjective fear, sustained balance, full headphone listening and hardware coverage still need human playtesting.
