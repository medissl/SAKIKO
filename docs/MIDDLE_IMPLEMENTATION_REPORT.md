# Middle-section implementation and verification

Implemented 17 October 2026 in the existing Godot game. The story, one cassette, one exit key, dark distant watcher, first AV pursuit, capture, ending, and credits are retained. No new floor, clue sheet, speech model, or extra monster was introduced.

## Route and physical gates

After the first pursuit is escaped, the green west stairs lead to the upper north hand mechanism. The existing shutter at X16/Z10 is raised with roughly 12 seconds of held E input. Releasing, moving out of reach, opening UI, pausing, losing focus, or capture stops operation and audio. Movement and camera controls remain live. A small progress bar appears only while operating.

The effort never drains. A matching moving collider keeps the partial opening below standing clearance; completion retracts the panel and updates navigation once. The pedestal is floor-supported at approximately X14.3/Z10.8, leaving over 2.4 m of main corridor width clear.

Only after completed playback is closed with the player downstairs and the barriers clear, the north shutter jams, the south shortcut at X40.5/Z26 closes, and the new upper east-landing door at X48/Y4.2/Z19 bolts. The earlier east descent and all ground-floor escape routes remain available before this transition.

The crossing goes east along the north corridor, through optional two-door U02/U03 alternatives, then south along the east corridor to U08. U01 provides the west-side retreat loop. Actual player and creature clearance was checked; no furniture overhaul was needed. Two modest direction signs support the route. The chair/mirror key remains at X45.8/Y4.666/Z34.45.

The east landing bolt works from the upper corridor side; the south shortcut latch works from the rehearsal/east side. Both remain released on reload. Their hardware follows its proper support/door leaf.

## AI and sound

The same physical Sakiko approaches through the west/green-stair route. No visible teleport or duplicate world threat is used. The hand mechanism emits a fixed-position investigation stimulus on start and about every two seconds. Its initial range is 18 m on the same floor, reduced to 11.7 m under solid occlusion. It reports the station, not a moving hidden player.

Actual sight, last-seen search, local footsteps, real door-opening time, faster player sprint, lethal unobstructed contact, and scheduling recovery remain active. Recovery does not disable sight, hearing, or capture. Flashlight attraction remains explicitly disabled; the light is for illumination. A quiet local approach cue rearms on retry without repeating the watcher, tape, or first authored pursuit.

The ratchet uses existing permitted CC0 recorded lock/shackle contacts at natural pitch. Its source/edit hashes are in `assets/audio/winch_ratchet_provenance.json`. No synthesized beeps or new VA were added. Perceptual audio audition remains incomplete.

## State and saves

`story_flow.gd` remains authoritative. Stage 6 is the shutter task, stage 7 the crossing/rehearsal search, and stage 8 the final return. Persistent fields include `middle_section_active`, clamped `shutter_progress`, `shutter_open`, `east_landing_unbolted`, `south_shortcut_released`, and safe far-side arrival.

- CP5: middle entry at the existing safe staff anchor.
- MIDDLE_SHUTTER: completion at the safe west side, approximately (13,4.2,9.5).
- MIDDLE_FAR: safe arrival at (46,4.2,10), skipped during immediate pursuit/proximity danger.
- CP6: the existing key checkpoint, retaining all middle gate and shortcut states.

Release/death merges the greatest earned effort into the last safe checkpoint without saving every frame or replacing its safe position. Restoration stops crank/capture/queued audio, restores stamina/input, and uses a clear distant phase anchor. Version 4 saves migrate to version 5 with a recoverable backup: existing key owners retain final return, while escaped pre-key saves enter the middle at CP5. Settings and older files are preserved.

## Runtime evidence

The opening through watcher and AV passed a clean native release route. After the final retry/wayfinding adjustments, the final executable was rechecked from the organically earned safe AV checkpoint through genuine first-pursuit escape, shutter, both classroom routes, far-side checkpoint, both shortcut latches, key, exit, ending, and credits. Inventory rewards were obtained through ordinary interactions.

The timed route took **87.582 seconds of wall time** from middle entry to key acquisition, with ordinary walking, both classroom alternatives, and both optional shortcut interactions. This is an automated route measurement, not fresh-player hesitation/comprehension time. No waiting or movement slowdown was added to reach the brief's 5–10 minute estimate.

Focused native checks passed: early bypass exclusion; reach/hold/release/movement/focus/pause handling; partial effort after death and disk reload; fixed noise coordinates and floor separation; collision/contact exclusion through the shutter; permanent completion; physical creature traversal through U01/U02/U03; one-sided shortcut access; save migration; clear retry placement; no stale first pursuit or duplicate key.

**Genuine evasion:** visual pursuit began, the player closed U02's entry behind them, used its other exit, continued through the unbolted east landing, and broke sight into the ground-floor AV route. The enemy searched its stored upper-floor sighting and withdrew; damage was never disabled. [Runtime log](C:/Users/media/.codex/visualizations/2026/10/15/01a1407f-e3a4-7711-9cda-b27cabc8015a/SAKIKO-flow-preview/middle_crossing_check-final.log), [escape image](C:/Users/media/.codex/visualizations/2026/10/15/01a1407f-e3a4-7711-9cda-b27cabc8015a/SAKIKO-flow-preview/artifacts/flow_middle_genuine_escape.png).

**Genuine capture:** standing in the noisy station approach and openly in the crossing both allowed real contact capture. The open-corridor case reached capture after about 3.5 game seconds and completed the normal retry screen. [Capture image](C:/Users/media/.codex/visualizations/2026/10/15/01a1407f-e3a4-7711-9cda-b27cabc8015a/SAKIKO-flow-preview/artifacts/flow_middle_genuine_capture.png), [station/death-progress checks](C:/Users/media/.codex/visualizations/2026/10/15/01a1407f-e3a4-7711-9cda-b27cabc8015a/SAKIKO-flow-preview/middle_check-final.log).

The final run and focused tests reported zero failures and empty error logs. Pass counts: {"middle-route-measured": 29, "middle_check-final": 22, "middle_crossing_check-final": 19, "middle_visual_check-final": 1}.

## Bounded rendering check

Intel Iris Xe, Vulkan Mobile, 1280×720, 120 samples per phase. In one process at the same station camera/light, middle hardware was shown, hidden, then shown again. Median frame time was 19.910 / 19.567 / 19.919 ms; p95 was 23.403 / 21.587 / 21.643 ms. The stable repeat adds approximately **0.35 ms** and 80 draw calls. [Raw measurement](C:/Users/media/.codex/visualizations/2026/10/15/01a1407f-e3a4-7711-9cda-b27cabc8015a/SAKIKO-flow-preview/artifacts/middle-render-cost.json).

This isolates hardware render cost, not whole-game FPS or AI cost. A separate serial comparison with an older public build included earlier unrelated changes and variable load, so it is not treated as an isolated middle-section baseline. No broad performance rewrite was performed.

## Files and remaining verification

Main runtime changes: `scripts/story_flow.gd`, `scripts/school_encounters.gd`, `scripts/game.gd`, and `scripts/interaction_hints.gd`. The hardware is built into the existing school at runtime; no replacement map/scene was created. Added ratchet audio/provenance and `tools/build_winch_audio.py`. Relevant `tests/flow_*` helpers were extended and `tests/middle_*` checks added. README, asset notices, and the neutral fresh-play sheet were updated.

No named runtime check remains failing. Listening quality, subjective fear, and first-player understanding still require human playtesting. `docs/FRESH_PLAYTEST.md` provides neutral observations/questions. Technical success is not a guarantee of scariness.

Tested executable SHA-256: `06aff43fddf7454b8b1939acf15ee67d7075463968fda40ff1ed28ab47a251a3`. The shareable ZIP is generated from this same executable with legal notices and package hash/CRC checks. The tested Windows package is published on GitHub as v2026.10.17.
