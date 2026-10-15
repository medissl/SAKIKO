# Verification record

Tested 15 October 2026 with Godot **4.7.2.stable.official.ed1daf0bf**, Windows, Compatibility/OpenGL 3.3, Intel Iris Xe graphics, 1280 × 720.

## Engine integration suite

The rendered `--verify --quit-after-verify` run completed all assertions and exited without runtime errors or shutdown resource warnings:

- All candidate key positions have a path from the entrance in the retained clearance-aware navigation component (1,453 points).
- WASD action input moves the physical player; flashlight action toggles the actual light.
- Settings survive save/reload, and the SFX bus receives the expected decibel value.
- Collecting all three spawned keys through the actual interaction/line-of-sight function updates the count.
- Entrance unlocking and the subsequent escape interaction reach victory.
- Starting again clears keys and restores locked doors and entrance state.
- Doors' collision shapes disable when opened; pause/resume updates game state.
- Detection works down a clear corridor, respects field of view and fails across the central wall.
- Losing sight transitions chase → investigate → search → roam.
- A moving enemy follows the graph into a room and automatically opens a closed door.
- Capture advances through the timed sequence into death; menu return succeeds.

Earlier headless runs also completed the assertions, but the Godot dummy audio driver reported active WAV playback references at shutdown. The rendered run did not report those warnings.

## Render inspection

Generated and visually inspected actual viewport images of the main menu, options, corridor, classroom, creature and capture. Death was rendered as part of the audit. Revised the initial head geometry after inspection, replacing convex mouth shapes with an open sculpted skull and recessed cavity. Revised doorway placement and desk spacing after navigation checks exposed disconnected pockets. The final captures show readable lighting, supported Japanese glyphs, visible keys, clear teeth and eyes, and a framed close-up without the camera entering the head.

## Audio inspection

Generated all 13 real WAV assets and inspected sample peaks, RMS levels, duration and endpoint fades. The capture combines a noise transient, distorted formant-like harmonics and a decaying low impact. Playback streams and buses were exercised in a rendered run. No subjective listening claim is made.

## Remaining human checks

- A complete unassisted successful run and confirmation of the intended 5–10 minute pacing.
- Sustained chase balance, evasive room loops and recovery under extended play.
- Mouse/keyboard feel, every menu navigation path, fullscreen and several aspect ratios.
- Subjective audio mix and jumpscare intensity with headphones.
- Exported-build behavior and performance on other PCs; no export templates were installed here.

These are limits of the verification performed, not claims that these behaviors have failed.
