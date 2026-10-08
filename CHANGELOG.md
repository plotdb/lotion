## master

 - features:
   - `lotion.animate(opt)` / `player.animate(opt)` ( experimental, in `vector.js` ): convert a whole animation into one
     animated svg. each element becomes a `<g>` nested as in the dom; its motion ( position and transform as a matrix,
     opacity, blur ) is sampled per frame and written as css keyframes, simplified to the points linear interpolation
     needs; each distinct appearance is drawn once by satori and switched by visibility. inline svg is walked
     natively: groups animate, leaves keep their markup with numeric attributes as smil `<animate>`, definitions are
     written once, and text uses fonts embedded once. `mix-blend-mode` now works at any depth.
   - demo: the `/vector/` page converts the whole animation and plays the animated svg
   - animate, size: numeric tracks are written once per element instead of once per appearance ( positions of svg
     leaves join the group matrix, inheritable values such as `stroke-dashoffset` animate on the group );
     css gradient masks moved by `mask-position` / `mask-size` ( wipes ) become one svg mask with a moving rect, so
     the content is drawn once; paths drawn progressively ( each `d` a prefix of a longer one ) become the full path
     revealed by a dash animation. the code-only sumi-ink trial drops from 3.2 MB to 1.5 MB.
 - tweaks:
   - vector: inline svg keeps a content-based placeholder `src` until fonts are ready


## v0.3.0

 - features:
   - `player.encode(opt)` / `lotion.encode(opt)`: render to mp4 in the browser ( snapdom capture, WebCodecs encode via
     mediabunny ), both libraries loaded on demand by dynamic `import()`; urls configurable in `lotion.libs`
   - demo: export button
   - `dist/vector.js` ( experimental ): `lotion.vector(el)` / `player.vector(t)` convert the current frame to a vector svg
     with satori. layout is taken from the browser and each element becomes an absolutely positioned node; web fonts
     are collected from `@font-face` by the characters in use, woff2 decompressed, subset with HarfBuzz and variable
     fonts pinned to the used weight. root-level `mix-blend-mode` is composed as svg layers; inline svg is embedded
     with its computed styles, referenced external defs and fonts.
   - `lotion.lib(name)`: load an on-demand dependency listed in `lotion.libs`
   - demo: `/vector/` compares the player with its converted svg side by side; the block demo loads `vector.min.js`


## v0.2.1

 - features:
   - cli: `video --workers N` renders with N browsers in parallel, splitting frames into contiguous ranges and joining
     the encoded parts without re-encoding. each part first renders the 3 preceding frames and discards them, since a
     freshly opened page that jumps straight to a frame rasterizes its first frames slightly differently; with this the
     output matches a single worker frame for frame. about 2.7x faster with 4 workers on an 8-core ( 4 performance ) mac.


## v0.2.0

 - breaking:
   - remove audio generators ( `audio/`, `lotion bgm | sfx | mix | beats` ); the commands now only print a notice.
     they moved to the authoring toolkit `@plotdb/lotitor` ( not public yet )
   - move `prompt/explainer.md` and `prompt/ui-loop.md` to `@plotdb/lotitor`
 - features:
   - `prompt/lotion.md`: how to write a lotion animation, independent of form and style
     ( split from `prompt/explainer.md` )
 - tweaks:
   - cli: when `playwright` is missing, print how to install it instead of a node stack trace


## v0.1.0

 - features:
   - player: show a loading screen until `start()` ( `loading` option: `true` / custom html / `false` );
     the stage is hidden, the control bar disabled, and `seek` / `play` ignored meanwhile
   - player: `player.ready`, a promise resolved by `start()`
   - block loader: wait for the interface's `ready` before exposing the render protocol
 - tweaks:
   - player: under `?render`, expose `window.seek` / `window.DURATION` at `start()` instead of construction,
     so the cli never renders a scene still being prepared
   - demo: simulate asynchronous preparation ( `?loading=<ms>`, default 1500 ) to show the loading screen
   - cli: locate `audio/` both next to `cli.js` ( published by `fedep publish`, dist flattened ) and one level up
     ( in the repo ), so audio commands work in either layout
 - docs:
   - document the loading behavior in README and `prompt/explainer.md`


## v0.0.1

 - init release
   - runtime: spring, track, vis, bump, typing, color and DOM helpers
   - runtime: player with timeline, chapters, keyboard control, fullscreen and render protocol
   - block player: `@plotdb/block` runtime bundled with a loader, supporting registry and packed modes
   - cli: `frames`, `sheet`, `video` ( optional motion blur ), `cues` and `bundle`
   - audio: `bgm` ( bassline synthesizer ), `beats`, `sfx` and `mix`
   - prompts: `ui-loop.md` and `explainer.md`
   - demo pages in `web/`
