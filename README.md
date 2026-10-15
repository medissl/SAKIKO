# SAKIKO / さきこ

SAKIKO is a proprietary game by medissl. Copyright © 2026 medissl. All rights reserved. Original material owned by medissl is governed by the [SAKIKO Proprietary Game License](LICENSE.txt), only to the extent protected by applicable law. Third-party and unverified material are excluded; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [asset credits](ASSET_SOURCES.md). This project is not offered under a project-wide MIT or open-source license.

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

## License and distribution

Lawful recipients of authorized builds may install and play for personal, non-commercial entertainment and make necessary personal backups. Redistribution of the game or source, resale, bundles, mirrors, reuploads, sublicensing, modified-build distribution, rebranding, and reuse of original protected material in another distributed product require separate written permission from medissl, except where a third-party license or applicable law permits the use. Similar mechanics and themes in independently created games are not restricted. Mandatory legal exceptions and earlier valid license grants remain intact. See LICENSE.txt for the full terms, warranty disclaimer, and legally qualified liability limits.

Keep LICENSE.txt, THIRD_PARTY_NOTICES.md, ASSET_SOURCES.md, GODOT_ENGINE_LICENSE.txt, and every required component notice with each distributed build. The Windows export preset includes legal documents and provenance records in the pack. Also place readable copies beside the executable in the release archive. Godot templates contain additional libraries: include the exact template version's copyright and license notices before release. See THIRD_PARTY_NOTICES.md for the release checks and unresolved clearance items. A configured filter is not proof of a verified exported archive.
