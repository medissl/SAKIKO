# Asset provenance

All third-party runtime files are included locally. No paid asset purchases were made. CC0 permits commercial reuse and redistribution. Package receipts list source URLs and hashes.

| Asset | Author and source | License / receipt |
| --- | --- | --- |
| Textured seated readers and standing teacher | [Innerscene, adapted from MakeHuman](https://www.innerscene.com/tools/library/3d-parts/seated-reading-3d-person-seated-a5ebe9b3), [standing reader](https://www.innerscene.com/tools/library/3d-parts/reading-a-book-3d-person-everyday-tasks-c6444d5b) | CC0; `assets/characters/realistic-people-lock.json` |
| Earlier rigged student/businessman models, retained as unused source assets | [Quaternius via Poly Pizza](https://poly.pizza/m/kZ3DmIoGip), [businessman](https://poly.pizza/m/JFrLIKqvCH) | CC0 on individual source pages; `assets/characters/asset-lock.json` |
| Phototextured school desk and chair | Ethan Place / Poly Haven: [desk](https://polyhaven.com/a/SchoolDesk_01), [chair](https://polyhaven.com/a/SchoolChair_01) | [CC0](https://polyhaven.com/license); `assets/furniture/asset-lock.json` |
| Plaster wall and worn wood floor PBR maps | Poly Haven: [wall](https://polyhaven.com/a/plastered_wall), [floor](https://polyhaven.com/a/wood_floor_worn) | CC0; `assets/surfaces/asset-lock.json` |
| Male pain vocal, used in `player_pain.wav` and `capture_v2.wav` | [HaelDB, Male Grunt/Yelling Sounds](https://opengameart.org/content/male-gruntyelling-sounds), entry `3grunt2.wav` | CC0 option selected from offered dual license; `assets/audio/capture-provenance.json` |
| Menu music `menu_theme.ogg` | [brandon75689, Tragic Ambient Main Menu](https://opengameart.org/content/tragic-ambient-main-menu), submitted by HaelDB | CC0 option selected; SHA256 `9dbe685e40d6cc8876ff08938b011424b802c2757ac4052e3eb93f8634208969` |

The source packages were staged in an ignored cache, checked for expected file formats, closed dependencies, and source checksums where provided, then copied into the project. SHA256 receipts record admitted files. The game-dev CLI was unavailable; these are local validation receipts, not CLI admission certificates.

## Original project assets

- The continuous face, shaped skull profile, concave mouth, dental arches and strand hair are actual 3D geometry built by `scripts/creature.gd`.
- `sakiko_face.png` is an original AI-generated surface texture, projected onto that geometry. It is not a flat ghost sprite. The user's supplied images guided its appearance and are not redistributed.
- `window_courtyard_atlas.png` is an original AI-generated matched day/night environment panorama. The window shader adds slight foliage motion, parallax and grime behind solid frames. It is an exterior illusion, not a playable outdoor map.
- Image generation used OpenAI's image generation tool. Prompts and output identifiers are in `docs/GENERATED_ART.md`.
- `SakikoThorn.ttf` is an original locally generated horror font from `tools/generate_font.py`. Godot system font fallbacks supply Japanese characters; system fonts are not bundled.
- Remaining procedural textures and synthesized WAVs come from `tools/generate_assets.py`. `tools/mix_capture_audio.py` combines the licensed male vocal with original synthesized layers. Running the original generator alone does not reproduce the separately generated face/panorama or licensed downloads.
- School layout, built-in props, shaders and gameplay code were created in this project.

Godot Engine is MIT licensed: https://godotengine.org/license/. Include the engine's required notices when exporting a distributable build. Original material owned by medissl is proprietary under LICENSE.txt, only to the extent protected by applicable law. Third-party components remain under their respective licenses; see THIRD_PARTY_NOTICES.md.

## Recorded vocal roles and new story assets

- Female ghost humming, laugh and scream: [AuraVoice / Nocturnal_Vanguard](https://opengameart.org/content/ghostly-humming), [laugh](https://opengameart.org/content/evil-cackle-laugh-2), [scream](https://opengameart.org/content/female-scream-1), CC0. Source URLs and SHA256s: `assets/audio/sakiko-voice-lock.json`.
- Male player breathing: [Nox_Sound, Male_Breath_Fast_Loop_Stereo.wav](https://freesound.org/people/Nox_Sound/sounds/554907/), CC0. The publicly available MP3 preview is bundled as `player_breath_male.mp3`; receipt: `assets/audio/player-voice-lock.json`. Male pain remains HaelDB's recording described above.
- `festival_recording.wav`: synthesized Microsoft Zira archival dialogue, filtered and mixed with original tape noise and knocking. It is not a performance by the player or Sakiko. Runtime captions and the journal provide the full clue.
- `quiet_knocks.wav` and `ending_morning.wav`: original synthesized effects. The morning bed is a quiet suggestion of air and birds, not a licensed field recording.
- Festival preparation, ordinary Sakiko, enlarged head and class photographs: original OpenAI-generated in-game evidence, documented in `docs/GENERATED_ART.md`. Notes use authored SVG paper textures with readable transcriptions. The supplied revised ending and exact evidence quotations are preserved in `assets/story/`.
- The current creature uses a continuous face annulus matched to a concave mouth and a closed rear skull, with curved dental arches carrying the original photographed enamel detail. It has a fixed open mouth for the camera dive. The previous detached jaw/lip construction is no longer used.

## Ownership and clearance qualifications

Copyright © 2026 medissl. All rights reserved, solely for original material owned by medissl and legally protected. This notice does not relicense third-party assets or claim ownership of general mechanics, themes, public-domain material or unverified material. AI-generated artwork is covered only to the extent rights exist under applicable law.

The Microsoft Zira synthesized festival_recording.wav has unresolved redistribution clearance. Preserve its provenance and obtain the applicable permission or replace it with cleared audio before release. System fonts are not automatically cleared for bundling. See THIRD_PARTY_NOTICES.md for details, prior-license preservation, the engine dependency-notice requirement and export verification status.
