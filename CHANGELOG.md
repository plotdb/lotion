## master

 - features:
   - `player.encode(opt)` / `lotion.encode(opt)`: render to mp4 in the browser ( snapdom capture, WebCodecs encode via
     mediabunny ), both libraries loaded on demand by dynamic `import()`; urls configurable in `lotion.libs`
   - demo: export button


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
