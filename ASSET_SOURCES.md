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

- Developer splash portrait: the user's existing Medissl branding, supplied in `Medissl-Games-Intro-Kit.zip`; bundled locally as `assets/branding/medissl.png`. The splash uses the project's original Sakiko Thorn typeface. The kit's Fredoka font is not imported or redistributed.
- `locked_rattle.wav` sequences the existing admitted CC0 lock-turn and handle-catch recordings into a blocked-handle response. Source hashes and processing are in `assets/audio/locked_rattle_provenance.json`; source authors and URLs remain in `assets/audio/recorded_foley.json`.
- Legacy tonal hover/confirm/dial/capture feedback now uses recorded paper, latch, lock and damped door impact transients. Processing and hashes are in `assets/audio/grounded_feedback_provenance.json`; attribution follows `recorded_foley.json`. No oscillator, pitch glide or voice is added to these cues.

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


## 2026-10-16 correction assets

- Current teacher, player, student tape and classroom speech: original Japanese script, generated locally with [hexgrad Kokoro-82M v1.0](https://huggingface.co/hexgrad/Kokoro-82M), Apache-2.0 model; ONNX conversion/runtime [thewh1teagle/kokoro-onnx](https://github.com/thewh1teagle/kokoro-onnx). Stock jm_kumo / jf_alpha and a modest jm_kumo/am_michael style blend; no voice cloning. Exact spoken text, casting, duration and hashes: assets/audio/japanese_voice.json. English captions are translations. Legacy Microsoft speech files remain archived but are not the active dialogue. Preserve their existing clearance qualification.
- Kokoro jm_kumo training-data attribution: Koniwa, kumonoito (蜘蛛の糸), [source record](https://github.com/koniwa/koniwa/blob/master/source/tnc/tnc__kumonoito.txt), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). See the model VOICES.md. Generated original game dialogue does not quote that story or bundle its recording.
- Outdoor children ambience: piermic, [Children Playing .mp3](https://freesound.org/people/piermic/sounds/396118/), CC0-1.0; public HQ preview retained under assets/audio/production, hash/source in production.json.
- Original generated panoramas, broadleaf atlas, facade bay and student watercolor decoration: built-in OpenAI image_gen, usage/prompts and hashes in assets/environment/generated/manifest.json. Matched closed-eye texture edit: assets/textures/sakiko_eyes_closed.json. The blink samples only eye regions; original face texture remains active elsewhere.
- Original fitted Sakiko hair: Blender curves converted to embedded mesh, authored by tools/build_sakiko_hair.py. Receipt assets/characters/sakiko_hair.json; editable local groom under .asset-cache. Runtime uses one neutral black rough material. Fuller forehead/rear skull and inset teeth are original procedural mesh corrections.


## Input/audio/lighting correction recordings

Ten category-specific CC0 Freesound recordings replace 35 event clips, with source page, author, public HQ preview URL, editing details and hashes in `assets/audio/recorded_foley.json`. Authors: Noted451 (wood footsteps), ChloePieterse (tile), Anthousai (wood stairs), Rudmer_Rotteveel (sliding wood and shackle), bdunis4 (paper), FOSSarts (drawer), ani_music (padlock key), OwlStorm (bag zipper), SpliceSound (wooden chair on wood). Source bytes and captured CC0 pages remain in ignored `.asset-cache/foley`. Classroom paper handling uses the same recorded paper source. No unrelated packs or paid generation were used. Numeric levels do not establish perceived audio quality.

`assets/audio/runtime_manifest.json` lists current playback categories, source measurements and reference gains. `voice_quality.json` records the unresolved Japanese performance requirement: rejected player/teacher and synthetic classroom chatter are disabled, captions remain, Japanese tape/transcript retained. `japanese_auditions.json` records exactly three pure-Japanese stock-voice auditions; no new full speech library was rendered.


## Final master: active assets and superseded speech

The current master disables all spoken player/teacher/student/tape VA. Historical Microsoft/Kokoro files and provenance above are retained source material, not active performances. Their notices and clearance qualifications remain. The active tape is `festival_nonverbal.wav`; the original exact clue is supplied as timed transcript and journal text. `voice_quality.json` is the runtime authority.

The 27 GLBs in `assets/furniture/finish` are original geometry authored with Blender by `tools/build_school_finish_kit.py`, with embedded palette materials and no third-party geometry. Seven original small textures/atlases were authored by `tools/build_finish_textures.py`; receipts are `assets/furniture/finish/manifest.json` and `textures/manifest.json`. They are original project content under the project's original-material terms, not newly licensed CC0 packages. No reference-game screenshot became an asset.

`tools/build_nonverbal_audio.py` creates original filtered-noise roomtone/window air and short suspense, combines existing cleared recorded paper/transport with authored knocks for the nonverbal tape, and low-pass filters piermic's CC0 children recording for indistinct classroom murmur. Source receipts remain `recorded_foley.json` and `production.json`; outputs, peaks, durations and hashes are in `nonverbal_manifest.json`. Numeric checks do not establish perceived audio quality. Ending acknowledgments now include the active school ambience and recorded foley authors.


Final Windows package: Noto Sans JP is bundled from https://github.com/google/fonts/tree/main/ofl/notosansjp under SIL OFL 1.1. Full license and source/hash receipt: assets/fonts/NotoSansJP-OFL.txt and NotoSansJP-source.json. Scene Japanese lettering uses the renamed Sakiko School Sans derivative: static weight 400, 468 current-game glyphs, overlapping outlines unioned. Generator: tools/build_school_font.py. It removes the dependency on Japanese Windows fonts. Unused historical Microsoft/Kokoro speech recordings are excluded from the release export; source notices remain for provenance.

The Windows application icon is original lettering derived from the existing SakikoThorn S glyph, with the menu’s muted red left marker; no stock engine logo remains in the game icon. The static spare creature head formerly used as a storage prop has been replaced by a faceless torn cardboard mount and strips.
