# Final two-floor school

The authoritative contract is `SAKIKO_TWO_FLOOR_REVAMP.md`, amended by `SAKIKO_IMPLEMENTATION_CORRECTIONS.md` and later direct user feedback. `scripts/school_layout.gd` is the only architecture generator. The previous west/old-wing map and portrait-fragment route are no longer spawned.

Both floors use Y=0/4.2 m, four connected 4 m corridors around an inaccessible courtyard, and opposite dogleg stairs. Seventeen rooms have 26 sliding entrances. The ground lobby exits west onto a real exterior floor; the ending starts after walking outside.

## Furniture clearance adjustment

The imported desk measures approximately .712 m wide, .883 m high, .546 m deep. The chair measures .566 m wide, 1.006 m high, .675 m deep. At their existing scales and .83 m seat offset, the pair is about 1.40 m deep. G01, U01 and U02 use twelve seats: three teaching rows of four columns, facing the west board. This preserves the teaching area, approximately .75 m access between teaching rows, .73 m rear clearance and a 1.88 m southern chase route. A forced twenty-seat arrangement would compromise these routes. G01 has eleven classmates and the player's seat.

Door openings are 2 m clear. Stair flights are 2.2 m wide, with twelve .175 m rises and .28 m treads per flight, a middle landing and an open upper slab. Invisible ramps follow the visible stair flights. Enemy navigation connects both floors through these routes and moves in three dimensions.

## Physical progression

1. G03 staff service drawer contains the ordinary cabinet key. The side-wall cabinet holds entrance I, the upper-wing gate key and festival storage key. The upper-wing key opens both stair gates; festival storage opens G05/G09.
2. G08 art drawer contains a packing envelope, original photograph and archive collection key. This key opens U06/U07. Inspect and flip F-12 in U07; take the existing compartment key from its physical rear sleeve. That key opens U06 B3-12, holding entrance II, tape, media key, classmates note and dated program.
3. The media key opens U05. Manually insert/play the actual 24-second festival tape. Its date clue and program solve G05 case 1015. The case holds entrance III and a separate U08 utility key. The tape encounter is lethal; no invincibility is enabled for the tested escape.
4. G09 brake and tracked shelf expose the report about U08. The utility key opens U08 without a report-reading permission flag. Its student bag holds entrance IV and the letter. Each entrance key removes one actual metal padlock; then slide the entrance open and walk outside.

Keys and documents physically preexist. Reading does not spawn keys. Ordinary utility keys are separate from four entrance keys. Inspection supports front/back, zoom, optional transcription and journal reopening. Safe checkpoint snapshots after each entrance key and the tape retain all inventory, containers, doors, released locks/open entrance, evidence, tape and one-shot voice/encounter state. Retry restores stamina and an occluded enemy with eight seconds of reorientation grace.

## Intro, windows and encounters

The lesson lasts 145 seconds including shared sleep/bell/wake. Skip enters that transition at 125 seconds. A connected Japanese literature explanation replaces repeated textbook orders; translated English captions match actual clips. Sparse player comments and the two-student tape are Japanese too. Voice volume/subtitles are configurable. Existing male exhaustion panting is unchanged. Stamina is a thin muted red bar at the screen bottom.

Windows are ordinary framed glazing. The courtyard, drainage, two planters, tree, immediate ground, walls and neighboring school volumes are 3D. A complete 2:1 spherical day/night panorama supplies distant scenery and sky, so up/down views cannot reveal a landscape card edge in an aperture. No runtime viewport windows or fixed window cards are used. Generated student paintings and photographic foliage/facade textures have provenance under assets/environment/generated/manifest.json.

The first upper-hall sighting is separate from pursuit: opposite end, over 23 m away, dark face, one texture-assisted blink after noticed, physical withdrawal behind the corner, no hunt. Tape playback is followed by silence/breath and an actual lethal pursuit. Later autonomous hunting remains active with pressure cooldown. Slabs/corners block sight; stairs connect both floors. Capture has Sakiko's hum/scream on approach, a black cut, then separate dry male pain.

## Current verification

Final automated checks: 96 physical progression checks, 26 furnished route/door safety checks, 23 audio/queue/exhaustion checks, 11 exit/checkpoint/ending checks. Seven focused capture checks pass for the latest vocal separation. Inspected renders include doors from both sides, window pitch changes, courtyard/exterior, supported props and papers, front/side/rear/blink/mouth-open head and capture. See HANDOFF.md for exact logs and commands.

No manual full playthrough, native Japanese performance/pronunciation review, first-player duration study, or exported-build performance measurement was performed. Hair is a real Blender curve groom converted to an embedded GLB; its editable source and build receipt are retained. Original menu, ending and credits remain intact.


## Latest audio/lighting override

SAKIKO_BUGFIX_AUDIO_LIGHTING.md and later user feedback now govern input/UI/audio. Night ceiling fixtures are off: only moonlight through glazing, faint reflected light and the real flashlight illuminate gameplay. Day intro remains separate. Rejected player/teacher speech and synthetic classroom chatter are disabled pending a credible Japanese performance; translated timed captions and the Japanese tape/transcript remain. Three stock-Japanese auditions are retained without another full-library generation. Recorded CC0 surface footsteps/material foley, held left/right Shift, single responsive menu indicator, generic aimed door prompts and temporary locked feedback are implemented. See HANDOFF.md and assets/audio/runtime_manifest.json for current focused evidence and explicit listening limitations.
