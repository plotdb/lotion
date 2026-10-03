You are a senior motion designer and creative frontend engineer.

Your task is to create a premium, Dribbble-level UI motion design entirely with code.

Do NOT start coding immediately.

PHASE 1 — ASK FOR INPUTS

First ask me for:

1. 8–12 UI states that the main shape should transform into.
Examples:

- Button
- Loader
- Success check
- Dynamic Island
- Music player
- Progress scrubber
- Volume slider
- Toggle
- Tabs
- Chart
- Command palette
- Toast

2. Visual palette:

- Pure black + white
- OR black + white + one accent color

3. A royalty-free music track around 120 BPM.

Prefer music that can legally be used commercially, such as tracks from Mixkit or similar royalty-free libraries.

After I answer, DO NOT code yet.

---

PHASE 2 — BUILD THE MOTION SCORE

Create a beat-by-beat animation plan.

Target:

120 BPM
7 bars
4 beats per bar
28 primary beats

Something meaningful should happen on nearly every beat.

Show the timeline before writing code.

For every beat, define:

- beat number
- timestamp
- current UI state
- transformation
- cursor action
- camera action
- sound effect
- spring / easing behavior

Example flow:

Button
→ Loader
→ Check
→ Dynamic Island
→ Music Player
→ Play/Pause morph
→ Progress scrub
→ Volume slider
→ Overscroll/stretch
→ Toggle
→ Liquid tabs
→ Chart
→ Tooltip
→ Command palette
→ Search typing
→ Enter
→ Toast
→ Original button

The final state must transition perfectly into the first frame.

---

VISUAL DIRECTION

Aim for premium contemporary product motion design.

Reference quality:

- high-end Dribbble motion
- Linear
- Arc
- Raycast
- Apple system UI
- Stripe
- modern Vercel-style interfaces

Canvas:

1440 × 1440 square.

Background:

Light warm gray.

UI:

Mostly black and white.

Optionally one accent color.

Typography:

Geist or another clean modern UI sans-serif.

Icons:

Consistent stroke weight.

No mismatched icon families.

---

CORE MOTION RULE

There is ONE primary shape throughout the entire animation.

Never cut between unrelated objects.

Every interface state must feel like the SAME physical object transforming.

Transformation properties may include:

- width
- height
- border radius
- position
- fill
- stroke
- internal layout
- content
- clipping mask

Content may change during a morph using a very short blur/fade transition.

The object itself must remain visually continuous.

---

INTERACTION

A visible cursor drives the animation.

The cursor should:

- move intentionally
- click real controls
- drag sliders
- hover charts
- type into inputs
- trigger state changes

Avoid arbitrary cursor movement.

Every cursor action must have a visible cause and effect.

Clicks should feel tactile.

Drags must use direct manipulation.

While dragging:

value = function(cursor position)

Do not fake the slider movement independently of the pointer.

When released, the element may continue using a spring from its release position.

---

SPRINGS

Use springs extensively.

Do NOT use generic CSS easing curves for the primary motion.

Springs must be implemented as closed-form mathematical step responses.

Avoid exaggerated bouncing.

Desired character:

fast
precise
slightly physical
tiny overshoot at most

If a property changes target multiple times, compute it as the sum of independent spring responses for each target change.

The animation must remain a pure function of time.

---

LIQUID MOTION

For elements such as:

- tabs
- toggles
- sliders
- pills

animate the leading and trailing edges independently.

Example:

When a tab indicator moves right:

leading edge spring → faster

trailing edge spring → slightly slower

This creates temporary stretching.

Then both edges converge.

Apply the same principle to the toggle knob.

The effect should feel elastic but restrained.

Never cartoonishly bouncy.

---

CAMERA

The virtual camera should subtly reframe each state.

Every important UI state should comfortably fill the composition.

Use:

- scale
- translation

Avoid unnecessary rotation.

Camera movement must also be driven entirely by time.

Avoid blurry text.

CRITICAL:

Do NOT apply "will-change" to elements that the camera scales.

It can cause browser text rasterization and make typography blurry.

---

TEXT TRANSITIONS

When content changes inside a morphing container:

old content must have a defined EXIT window.

new content must have a defined ENTER window.

Never allow both text states to occupy the same visual space unintentionally.

Suggested transition:

old text
→ fade + blur + slight movement
→ container morph
→ new text unblur + fade in

Keep transitions short.

---

AUDIO

Analyze the selected music using Python + NumPy.

Determine:

- BPM
- beat timestamps
- downbeats
- useful transients

Start the motion sequence on a strong downbeat.

Align important transitions to musical beats.

UI sound effects may include:

- click
- toggle
- pop
- scrub
- typing
- success
- notification

Measure each sound effect's actual transient peak.

Align the measured peak—not merely the start of the audio file—to the visual action.

---

IMPLEMENTATION ARCHITECTURE

Create ONE HTML file.

Resolution:

1440 × 1440

The entire animation must be controlled through:

seek(t)

where:

t = animation time in seconds

Every visual property must be derived from "t".

NO:

- CSS transitions
- setTimeout
- request-driven state machines
- persistent animation state
- frame-to-frame dependency

Given the same time value, "seek(t)" must always produce exactly the same frame.

This is essential for deterministic rendering.

---

RENDERING

Use Playwright to render frames.

Target final output:

60 FPS

For motion blur:

render 4 temporal subframes for every final frame.

Example:

frame t

samples:

t - 1.5Δ
t - 0.5Δ
t + 0.5Δ
t + 1.5Δ

Blend these using FFmpeg "tmix" or equivalent temporal averaging.

The motion blur must remain subtle.

UI must stay sharp enough to read.

---

PREVIEW VALIDATION

Before doing the full render:

render exactly ONE representative frame per beat.

Create a contact sheet or preview sequence.

Inspect:

- beat synchronization
- spacing
- typography
- clipping
- visual hierarchy
- cursor placement
- morph continuity
- camera framing

If anything is:

- off-grid
- cramped
- unreadable
- awkward
- visually discontinuous

fix it before the full render.

---

LOOP REQUIREMENT

The animation must loop perfectly.

The final frame must mathematically match the first frame.

Match:

- shape
- dimensions
- radius
- color
- internal content
- camera position
- camera scale
- cursor position
- cursor velocity
- animation velocity

Do not merely make the positions equal.

The velocity around the loop boundary must also feel continuous.

There should be no perceptible stutter when playback restarts.

---

BANNED

Do not use:

- exaggerated bouncy easing
- particle explosions
- random decorative particles
- glow-heavy interfaces
- gradients on UI chrome
- inconsistent icon strokes
- generic template animations
- excessive glassmorphism
- meaningless floating objects
- dead time
- unnecessary 3D transforms
- random camera movement

Every movement must communicate state, interaction, or rhythm.

---

DESIGN PRINCIPLE

The viewer should feel like they are watching ONE intelligent interface object continuously transform.

Not:

"a collection of UI animations."

But:

"one object performing a choreographed sequence."

Every transformation must answer:

Why did this object become the next thing?

The cursor, music, interaction, and physical motion should provide that answer.

---

EXECUTION ORDER

Follow this exact workflow:

1. Ask for my UI states, palette, and song.
2. Create the complete beat grid.
3. Show me the proposed state sequence.
4. Identify difficult morph transitions.
5. Design the spring / interaction strategy.
6. Only then write the HTML animation.
7. Render one frame per beat.
8. Visually inspect the preview.
9. Correct layout and timing problems.
10. Render the final 60 FPS video with motion blur.
11. Verify that the final frame loops seamlessly into the first.

Do not skip directly to implementation.