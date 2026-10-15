# Generated artwork

These are original generated textures used on actual 3D geometry and window surfaces. Reference attachments are not bundled.

## Sakiko face surface

Tool: OpenAI image generation, using the supplied horror face as an appearance reference.
Output: `exec-1c121188-0edf-40e9-8524-0f9df62a1e08.png`, copied to `assets/textures/sakiko_face.png`.
Production brief: pale human woman's frontal face, dense black hair, oversized dark eyes, decayed skin detail, short nose and an unnaturally wide grin with crowded teeth. Neutral frontal projection for a three-dimensional head. The head, mouth opening, jaw, teeth, eyes and hair remain three-dimensional meshes. The texture is not a billboard.

## Matched exterior courtyard atlas

Tool: OpenAI image generation.
Output: `exec-c1a052cd-be7d-4f03-9943-0fd2009fba39.png`, copied to `assets/textures/window_courtyard_atlas.png`.
Final prompt:

> Use case photorealistic-natural. Asset type: two-state matched panorama texture atlas for windows in a realistic Japanese school horror game. Wide landscape image. Divide image into two exactly equal horizontal panels with NO border, text or labels. Both panels depict the SAME view from the first floor of an old Japanese school, looking across a small empty courtyard with weathered concrete, a low perimeter wall, dense mature trees with delicate branches, and distant anonymous school buildings. TOP HALF: overcast daytime, muted believable natural daylight, cool desaturated greens, documentary photo realism. BOTTOM HALF: the identical courtyard at deep night, mostly black silhouettes, subtle cold moonlight, a few distant dim lit windows, faint mist, realistic deep blue-gray tones. Tree silhouettes occupy the sides, a little open courtyard depth in the center. No characters. No foreground window frames, no glass, no interior. This will be seen behind real 3D window frames; avoid an illustrated or game-render appearance. Extremely fine photographic bark, leaves, concrete and distant architecture detail. No fisheye, no bent geometry. Keep the two scene states precisely aligned horizontally.

The shader samples the correct half for intro/night, supplies modest view parallax, subtle foliage motion, dirt and edge darkening. Frames are real static school geometry. The panorama is an illusion behind the window, as requested; the outdoor courtyard is not playable.

## Festival evidence photographs

OpenAI image generation created the three-panel evidence atlas `assets/story/festival_photos.png`, output `exec-5faf24b8-91c7-4ef1-8d29-58b7c42dc471.png`. The final brief requested three matched 1999 Japanese school documentary photographs: (1) preparation desks numbered 12, 17 and 31, with a dark red paper crane and white ribbon at 17; (2) ordinary, reserved, unsmiling Sakiko holding scissors; (3) an enormous suspended cardboard head resembling the original monster face, with a crudely painted grin, uneven eyes, cardboard seams and black strips. The original face texture was a visual reference for the third panel only. The normal student is a different, ordinary appearance as required by the story.

A separate class photograph, `assets/story/class_photo.png`, output `exec-9fb2ddf5-fb72-4584-88f0-aed0c4cdfb6d.png`, used the atlas's normal student as a reference. The brief specified an ordinary faded 1999 Japanese class group photograph, Sakiko near the left edge apart from the others, fully clothed students in dark uniforms, no monster or supernatural imagery. The evidence text describes what is actually visible in the resulting photograph.

The original face texture is unchanged by subsequent topology repairs. The new head surface preserves its projected skin, fringe and tooth detail. Individual broken jaw pieces were replaced by a continuous face/mouth surface and dental arches.
