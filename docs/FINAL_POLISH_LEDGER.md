# Final polish evidence — 2026-10-16

Authority: the final master plus subsequent user requests. Later playtest feedback explicitly authorizes paper-text cleanup, audio balance, the Medissl splash with no Godot boot logo, sparse silent practical player thoughts, and a third-person ending rewrite. See `PLAYTEST_POLISH_2026-10-16.md` for those revisions. Two-floor IDs, four physical keys, puzzle answers and creator identity remain preserved.

| Area / severity | Observed defect and player impact | Implemented correction | Evidence |
|---|---|---|---|
| GPU / blocking | Zero-energy practical lights remained visible renderer lights with shadows | Hide unlit light nodes; preserve fixture meshes, moon and both flashlight shadows | Same-process `performance_fixtures.json`: classroom GPU 32.69 → 15.55 ms; corridor 25.16 → 15.08 ms. Native Intel Iris Xe. |
| Architecture / major | Dark unconstructed ceilings and weak junctions | Ivory panel ceilings/joints, skirting, cornices and fitted trim; distinct cleanable service floors | `placement_*_overview.png`, all 17 rooms; neutral inspection state |
| G01 / major | Teaching/storage zone missing | Pedestal desk, attendance folder, cubbies, duty chart and localized chair wear; ordinary belongings and board-facing desk assemblies | `master_G01_day.png`, `placement_G01_eye.png`, final night on/off pair |
| G02 / major | Incomplete clinic furniture/fixtures | Modeled beds, linen, care desk, sink, medicine cabinet, tray, height chart, matte pleated curtain on supported rail; curtain occludes sight but allows passage | `placement_G02_eye.png`, `recheck_infirmary_sink.png`, `recheck_curtain_rail.png` |
| U06 / major | Identical luminous folder blocks | Batched varied file/box atlas, indexed bays, drawer faces, flat storage and reading support; no powered task lamp at night | `placement_U06_eye.png`, final archive night pair |
| Remaining rooms / major | Generic tables and unsupported/empty work zones | 27 original Blender models and seven original small textures; room-specific workstations; natural grouped equipment and connected cables/drains | `master_affected_rooms.log`, `master_fittings_final.log`; no placement rejection/script error |
| Furniture / major | Desk/caster overlap falsely rejected five intended chair assemblies | Explicit workstation assembly relationships; unrelated opening/aisle exclusions remain enforced | Full progression initial placement check; G03/G04 revised captures |
| Records / major | Photo and notice mounted across glazing | Move to existing solid walls, preserving evidence IDs and wording | Live scene inspection and available-target checks |
| Rehearsal / major | Solid blocks impersonated shelves | Real open shelf backs/uprights/decks in same perimeter footprint, restrained fabric storage; clear central evidence view | Final `placement_U08_eye.png` |
| UI / major | Portrait reverse controls fell below 720p; unsupported SpinBox property broke code entry | Responsive inspection height; fixed number wheels and focused Escape; actual 1015 widget test | `master_ui.log`, 46 checks at actual 1280×720 and 1920×1080 |
| Player presentation / major | Paper duplicated in bottom transcript and pop-ups disclosed solutions/locations | Paper/photo alone with flip/zoom; remove transcription panel; minimal aimed actions, no nearby clue brackets; locked feedback says only Locked; no waypoint/tutorial/reward-route pop-ups | Final inspection captures; authored paper JSON/textures unchanged by this correction |
| Distant sighting / major | Face too faint; peripheral FOV started blink before player registered it | Fixed low courtyard-window bounce, scene-lit face; 250 ms central-look requirement, original 28 m stage and physical withdrawal | `master_hallway_review.log`, before/after crop and actual unaltered frames; hunt=false |
| Hair / performance | Fine groom strands expensive at distance | Cull only subpixel FineStrands beyond 8 m; main locks/scalp/crown remain, full groom close up | Near/far posed head captures; actual distant encounter; chase benchmark |
| Font / major | Shared Windows build depended on Japanese system fonts; imported CJK outlines failed TextMesh triangulation | Bundled OFL static subset; flat scene-lit fixed lettering on the existing plaques/boards | Font source/hash/OFL included; final runtime and exported font checks |
| Audio / major | Speech and perpetual dramatic bed conflict with final direction | No spoken VA; nonverbal 24 s tape with mandatory timed original transcript/journal, quiet roomtone/window air, finite suspense, filtered natural murmur; pant +3 dB; dry capture bus | `master_nonverbal_final.log`: 20 checks; source/hash measurements in nonverbal manifest. Listening unverified. |
| State / major | Whole flow required post-art verification | Normal/skip intro, early gates, keys, archive, tape, live escape, code, shelf, bag, capture/retry, stair navigation, four locks and ending | `master_full_progression.log`: 101 checks, zero failures. Automated fixture approaches with actual interactions/collision/AI; not a manual first-player playthrough. |

## Room use and circulation review

| Rooms | Dominant arrangement / recent use | Review |
|---|---|---|
| G01, U01, U02 | Board-facing classrooms; teacher/cubby zone; localized committee preparation and normal class photo/personal desk detail | Clear side/rear aisles. U02 photo is now on solid wall. |
| G02 | Two-bed clinic with care/handwashing station and curtain | Reachable work area; curtain rail supported and passage retained. |
| G03 | Four adult workstations, files, phone/lamp, coats and separate kettle area | Chairs face working surfaces; service drawer and cabinet remain reachable. |
| G04 | Book rows, checkout/returns, reading place and trolley | Two entrances linked around shelf ends; books use row meshes rather than item bodies. |
| G05 | AV rack, sturdy handling benches, projector/case and cable reel | Real cable ends and reserved case controls. |
| G06 | Cleaning sink, mop rack/bucket, supply shelves and drain | Supplies grouped by use; central standing and door approach space retained. |
| G07 | Conversation tables, bench, water corner, club board/flyer and bag | Shortcut through both doors clear; restrained recent-use group. |
| G08 | Art workbenches/stools, mats/brushes, drying and washing, separate festival packing | Stools moved clear of tabletop footprint; both entrances connect. |
| G09 | Perimeter scenery boxes/frames/fabric and wheeled moving rack | Brake anchor and report sleeve preserved; travel exclusion intact. |
| U03, U04 | Science benches/demo/sinks/instruments and supporting prep cabinets/island/trolley | Microscopes and glassware supported; pipes connected; no added puzzle. |
| U05 | Recording desk/mixer/mic/headphones with shelves and limited felt treatment | Tape controls reachable; actual first escape still traverses doorway/corridor/stairs. |
| U06 | Indexed records, flat storage and reading support | Both entrances usable; archive gate and checkpoint retained. |
| U07 | Preparation panel, supported F-12 portrait, returned display frames | Open viewing space and rear sleeve retained; right solid panel removed to reveal stored frames. |
| U08 | Open perimeter shelves/fabric, bag/cardigan/portrait remnant and dust traces | Open center intentional; actual bag/key/letter remain reachable. |
| Common routes | Shoe-zone lobby, directory/lockers, supported corridor clock/speaker/extinguisher, green/blue stairs | Continuous rail joins; two small battery-backed landing lights; real ramps/landings and headroom unchanged. |

## Key-view questions

Answers apply to inspected frames, not an assertion of commercial visual quality.

| View | Function recognizable without sign? | Supported/scaled/oriented? | Activity zone? | Route/clue readable? | Night depth / useful light? | Movement / AI / cost? |
|---|---|---|---|---|---|---|
| G01 | Yes: board/rows/teacher zone | Yes | Teaching and personal desks | Papers readable by inspecting/zooming | Same-view off/on pair: dark rows, local flashlight reveal | Placement and walkthrough checks pass; benchmark below |
| G02 | Yes: beds/curtain/care station | Yes, rail fixed | Care and washing | Door/care aisle clear | Neutral shot assesses placement; nighttime flashlight remains shared game light | Curtain sight mask tested; body path preserved |
| U06 | Yes: indexed file bays | Yes | Reading / record storage | Drawer and documents physically reachable | Off/on pair separates silhouettes from legible nearby files | Full archive interaction/checkpoint flow passes |
| Corridor/stairs | Yes: circulation and rail/landmark language | Yes, rail return gaps fixed | Sparse supported fittings | Tread noses and doors retained | Same-view corridor pair and actual landing capture | Both player escape and Sakiko stair traversal pass |
| F-12/U08 | Yes: dismantled exhibition / stored scenery | Yes; actual stand/open racks | Three exhibit stations / restrained perimeter | Existing rear sleeve and bag accessible | No emissive reward spotlight; inspect documents to read | Full physical key chain passes |
| Sakiko sighting | A distant anomalous head in a school corridor | Main groom/skull retained | Existing authored reveal | Central look required; no prompt announces her | Actual 28 m stage is vague but visible; blink then occluded withdrawal | Pre-tape hunt stays disabled; later real pursuit/capture remains lethal |

## Measurement and limits

Native Godot 4.7.2, Intel Iris Xe, Mobile Vulkan, 1280×720, 4× MSAA. VSync disabled and uncapped only for the fixed benchmark. Four static camera sweeps plus actual walking autonomous pursuit. No production global merging/occlusion or renderer/resolution/AA downgrade. Baseline was recorded after representative-room foundations and before remaining room groups, rather than the original unoptimized game. See raw JSON for CPU-process (includes render synchronization), GPU, physics, draws and p95. Cold new lettering pipeline results are retained separately; shader/cache startup hitches must not be confused with steady-frame improvements.

Final same-route comparison and Windows package evidence are appended after the actual export checks. Stable 60 FPS on this integrated GPU and subjective headphone mix/scare effectiveness are not established by empty error logs. No commercial or hardware guarantee is made.

## Provenance and method

Original kit/atlas manifests carry hashes and source generators. `master_asset_validation.json` checks 39 geometry/texture/audio outputs against receipts, GLB headers/embedded dependencies/triangle budgets and texture dimensions. The CJK derivative has a separate OFL/source/hash receipt. Native Godot/Blender were used because the game-dev CLI was unavailable; these are not sealed game-dev telemetry bundles or canonical package certificates.

Research: [official Closing Shift](https://store.steampowered.com/app/1843090/Chillas_Art_The_Closing_Shift/), [Night Security](https://store.steampowered.com/app/2367230/Chillas_Art_Night_Security/), [Convenience Store](https://store.steampowered.com/app/1228520/Chillas_Art_The_Convenience_Store/), [Frictional horror lessons](https://frictionalgames.com/2019-10-9-years-9-lessons-on-horror/). Credible ordinary activity and restrained escalation informed this pass; no reference screenshot became an asset.


## Final Windows checks and performance

The isolated Windows EXE passed the complete 101-check main progression (`master_export_full.log`). Native Vulkan captures then verified actual exported menu/options, document inspection, scenery, capture and retry (`master_export_visual.log`). The final pack's 36 legal/provenance files match source SHA256s. Development prompts/test scripts and retired speech are absent from the pack. The source UI run passes 46 checks at actual 720p and 1080p, including wrong/correct number wheels, focused Escape, submenu focus, bus mute and Off/2x/4x anti-aliasing application. The 20-check nonverbal scenario covers tape completion, real pursuit, physical escape and retry. The last source change only distinguishes aimed utility keys so nearby keys do not share an outline; the final native EXE smoke check includes that change.

The spare miniature creature used as a rehearsal prop was removed after direct user review. It is now a faceless torn cardboard mount with strips. Two solid white boxes were replaced by actual stacked cartons supporting the existing document. `export_storage_review.png` and `master_U08_final_neutral.png` show the actual exported scene; no decorative CharacterBody3D creature remains in the world scenery. The actual enemy and capture model remain.

Same fixed route and raster settings, milliseconds (median / p95). Baseline is the earlier editor-binary runner, final columns are the consumer release executable. These are separate runs, not sealed paired telemetry; the user's Godot editor remained open and was left untouched. Treat differences as indicative, not a controlled causal attribution to every art group.

| Stage | Before remaining art, 4x | Exported game, 4x | Exported game, 2x |
|---|---:|---:|---:|
| classroom | 17.71 / 18.93 | 21.04 / 23.27 | 17.10 / 20.70 |
| corridor | 18.59 / 21.88 | 20.83 / 32.37 | 16.77 / 34.21 |
| stairs | 12.33 / 13.49 | 14.27 / 17.14 | 17.30 / 35.62 |
| archive | 11.20 / 16.85 | 10.49 / 11.79 | 12.20 / 15.75 |
| chase | 20.64 / 29.35 | 14.62 / 18.48 | 16.56 / 24.99 |

At 4x, median throughput ranges about 48–95 FPS in this sample. This does **not** meet locked 60 FPS across all stages. The new anti-aliasing option keeps the original 4x default and offers explicit 2x/Off choices; the 2x run improves the classroom/corridor median but has variable tails and worse results in other stages, so it is not advertised as a stable-60 preset. Resolution, renderer, flashlight shadows, scene identities and lethal AI remain intact.

The earlier same-process unlit-light comparison is the strongest causal GPU evidence: hiding inactive practicals approximately halved classroom/corridor GPU time. Subsequent source runs include large timing variance and cold new shader pipelines; raw JSON/logs are retained instead of reporting only favorable samples. Final export physics medians are roughly 0.5–1.1 ms. Asset work is staged before the first capture; no complete external-hardware/first-install shader-stutter certification is claimed.

Remaining limitations for publication: an actual headphone/speaker listening pass, a fresh-player pacing/scare review, and wider hardware testing. Native timings establish playability on the sampled machine, not a hardware guarantee. The Windows binary is unsigned. No unresolved progression or interface failure remained in the covered final checks; this is a shareable playable build, not a claim of commercial or release readiness.

Executable: `builds/windows/SAKIKO.exe` (embedded data; editor not required). Readable legal notices, exact Windows template notices, font OFL and attribution receipts accompany it. Official template archive SHA256 was checked against the Godot release listing; receipt is in the ignored export-template cache. Final archive integrity and content hashes are recorded in `tests/artifacts/release_package_validation.json` and the adjacent SHA256 file.

Final archive validation passed: 38 files, 118.5 MiB. Archive SHA256: `1daa28761517d5b993f2cca14a9e55d7d2bce41e58b9c0b85a51645a7054d92e`. The packaged EXE matches the isolated executable tested in `playtest_export_full.log` (101 progression checks), `playtest_export_polish.log` (native mix, papers, stand-up and ending), `playtest_export_caption.log` (silent practical captions) and `playtest_export_studio.log` (splash/input/default Godot-logo removal). Full legal/provenance pack validation matched 35 source files. Earlier tape-caption coverage remains in `master_export_tape.log`.
