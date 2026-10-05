# lotion

Deterministic motion toolkit: write animations as a pure function of time, `seek(t)`, then
play, scrub, embed, or render them frame by frame into video.

 - runtime ( `dist/index.js` ): springs in closed form, keyframe tracks, fade windows, small DOM helpers,
   and a player with scrubbing / chapters / fullscreen.
 - block player ( `dist/block/player.js` ): package an animation as a `@plotdb/block` and embed it anywhere.
 - cli ( `lotion` ): render any page following the render protocol into png frames, contact sheets or mp4,
   and bundle blocks.
 - audio tools ( `audio/` ): beat detection, ui sound effects, a simple bassline bgm synthesizer and a cue mixer.
 - prompts ( `prompt/` ): workflow notes for producing motion designs and explainer animations with an AI agent.


## Install

    npm install --save @plotdb/lotion

The cli additionally needs `playwright` ( with chromium installed, `npx playwright install chromium` ) and
`ffmpeg` in `PATH`. Audio tools need `python3` with `numpy`.


## Runtime

include the script and css:

    <link rel="stylesheet" href="index.min.css">
    <script src="index.min.js"></script>

create a player, build your scene into `player.stage`, then call `start()`:

    p = new lotion.player do
      root: '#demo'
      duration: 10
      chapters: [[0, 'intro'], [4, 'detail']]
      seek: (t) -> seek t
    x = lotion.track [[0, 100], [1, 800], [3, 100]]
    dot = lotion.mk 'dot', '', p.stage
    seek = (t) -> lotion.put dot, x(t), 300, 1, lotion.vis(t, 0.2)
    p.start!

player options:

 - `root`: container element or selector.
 - `width`, `height`: design size of the stage. default `1920` x `1080`. The stage scales to fit the container.
 - `duration`: total length in seconds.
 - `seek(t)`: render the frame at time `t`. must depend on `t` only.
 - `chapters`: optional `[[t, name], ...]`, shown as ticks on the timeline and used by `←` / `→`.
 - `start`: initial time. `?t=<sec>` in the url takes precedence.
 - `autoplay`: default `false`.
 - `cues`: optional function returning sound cues `[{t, ...}]`, exported by `lotion cues`.
 - `loading`: what to show before `start()`. default `true` ( a spinner ); a string is used as custom html;
   `false` shows nothing.

player methods: `start()`, `seek(t)`, `play(go = true)`, `pause()`, `toggle()`, `fullscreen()`.
`player.ready` is a promise resolved by `start()`.

Until `start()` is called, the stage is hidden behind the loading screen, the control bar is disabled, and
`seek` / `play` do nothing. Scenes often need asynchronous preparation before the first frame is right
( web fonts, measuring the layout to place things ), and a half-built stage should not be seen or scrubbed.
So build the scene, finish whatever it waits for, then call `start()`:

    Promise.all([document.fonts.ready, prepare!]).then -> p.start!
Keys ( when the player is focused ): `space` play / pause, `←` / `→` previous / next chapter, `f` fullscreen.

helpers:

 - `spring(t, w = 14, z = 0.8)`: step response of a damped spring, `0 -> 1`.
 - `track(keys, opt = 'std')`: `keys` is `[[t, value, preset?], ...]`. returns `(t) -> value`, summing one
   spring response per change of target. `opt` / `preset` is `{w, z}` or a name in `presets`
   ( `fast`, `std`, `soft`, `move`, `ease` ).
 - `vis(t, t0, t1, din, dout)`: fade window. `0 -> 1` from `t0`, back to `0` from `t1`.
 - `bump(t, t0, d)`: a `0 -> 1 -> 0` pulse.
 - `typing(t, t0, text, dt)`: the part of `text` typed by time `t`.
 - `hex(str)`, `mixc(a, b, f)`, `rgb(c, alpha)`: color helpers working on `[r, g, b]`.
 - `mk(cls, html, parent, prefix)`: create a div.
 - `put(el, x, y, s, o, {hide, blur})`: set transform / opacity. hides the element by `visibility` when
   transparent; pass `hide: false` for nested elements, since a visible child overrides a hidden parent.
 - `txt(el, html)`: set innerHTML only when changed.
 - `svg(tag, attrs, parent)`: create an svg element.


## Render protocol

With `?render` in the url, a page should cover the viewport with its stage and expose:

 - `window.seek(t)`: render the frame at `t`.
 - `window.DURATION`: total length in seconds.
 - `window.cues()`: optional, list of sound cues.

`lotion.player` does this automatically, and only when `start()` is called: the cli waits for `window.seek` to
exist before rendering, so it never captures a scene that is still being prepared. Any other page can follow
the protocol by itself; likewise, define `window.seek` only when the first frame can be rendered correctly.


## Block Player

An animation can be packaged as a [@plotdb/block](https://github.com/plotdb/block): HTML, scoped CSS and JS in
one file, with libraries ( including lotion itself ) declared as dependencies and injected by `rescope` /
`csscope`. `dist/block/player.js` bundles `@plotdb/block` with its dependencies ( semver, proxise, csscope,
rescope ) and a loader, about 47KB minified.

    <div data-block="my-animation"></div>
    <script src="player.js" data-block-root="/block" data-lib-root="/assets/lib"></script>

 - `data-block`: block name. optional `data-version`, `data-path`.
 - `data-bundle`: optional url of a packed block ( see `lotion bundle` ). With it, nothing is fetched from
   the registry, so `player.js` plus the bundle file can be copied to any site.
 - script attributes: `data-block-root` ( default `/block`, blocks at `<root>/<name>/index.html` ),
   `data-lib-root` ( default `/assets/lib`, libraries at `<root>/<name>/<version>/<path>` ), `data-manual`
   ( don't mount automatically; use `lotionBlock.mount(el)` ).
 - `window.lotionBlock`: `{manager, mount, ready}`.
 - If a mounted block's interface provides `seek(t)` and `duration`, they are exposed per the render protocol
   under `?render`. If it also provides `ready` ( a promise, e.g. `player.ready` ), they are exposed after it
   resolves. A block using `lotion.player` should pass `ready: player.ready` in its interface.

Note that csscope scopes a block's style to the *descendants* of its root, so put the element your style
targets under the root ( or use `:scope` ). A block sample is in `web/src/pug/block/lotion-demo`.


## CLI

    lotion frames <src> <outdir> <t...>      one png per time
    lotion sheet  <src> <out.png> <t...>     the same, tiled into one contact sheet
    lotion video  <src> <out.mp4>            render to mp4
    lotion cues   <src> <out.json>           dump window.cues()
    lotion bundle <base-url> <block> <out>   pack a block and its dependencies into one file
    lotion bgm | sfx | mix | beats ...       audio tools, see below

`<src>` is an http(s) url, or a local html file / directory served by a built-in static server.

options:

 - `--width 1920 --height 1080`: viewport size.
 - `--fps 60`, `--sub 1`, `--shutter 0.5`: video settings. with `--sub` greater than 1, each frame averages
   `sub` sub-samples spread over `shutter` of the frame interval ( motion blur, via ffmpeg `tmix` ).
 - `--from`, `--to`: render only a range, in seconds.
 - `--crf 16`: x264 quality.
 - `--cols 3`, `--tile 640`: contact sheet layout.
 - `--query`: extra url parameters, such as `--query bar=1`.
 - `--block-root /block`, `--lib-root /assets/lib`: registry paths for `bundle`, relative to `base-url`.


## Audio

Each command forwards its arguments to the python script of the same name in `audio/`; pass `-h` for all options.
All times are aligned so that `t = 0` matches the start of the animation.

 - `lotion bgm out.wav --bpm 120 --bars 16 --key A --scale minor --prog 1,6,3,7 --bass drive --drums four --pad`:
   synthesize a track around a repeating bassline. bass presets: `pulse`, `octave`, `house`, `drive`, `walk`,
   or 16 custom steps ( semitones from the chord root, `.` rest, `-` hold ). drum presets: `four`, `half`, `broken`,
   `none`. `--loop` makes it loop seamlessly; `--grid grid.json` writes its beat grid.
 - `lotion beats music.mp3 --start 64.11 --dur 30 --out grid.json`: estimate bpm and the beat grid
   ( `{bpm, offset, beats, downbeats}` ). with an off-beat bassline and syncopated kicks the grid may be half a beat
   off; correct it with `--shift 0.5`.
 - `lotion sfx sfx/`: synthesize ui sound effects ( click, tick, scrub, pop, toggle, success, notify, type, whoosh )
   and measure each transient peak into `sfx/peaks.json`.
 - `lotion mix cues.json out.wav --dur 30 --music bgm.wav --sfx sfx/ [--loop | --fade 2]`: mix music with sound
   effects placed at cue times ( `[{t, sfx, gain}]`, e.g. from `lotion cues` ), aligning each effect's measured
   peak rather than its file start.

A typical flow:

    lotion bgm bgm.wav --bpm 120 --bars 16 --grid grid.json   # time the animation on this grid
    lotion sfx sfx/
    lotion cues page.html cues.json
    lotion mix cues.json audio.wav --dur 32 --music bgm.wav --sfx sfx/ --fade 2
    lotion video page.html silent.mp4
    ffmpeg -i silent.mp4 -i audio.wav -c:v copy -c:a aac -shortest out.mp4


## Prompts

 - `prompt/ui-loop.md`: a phased workflow for short, looping, single-object UI motion with music.
 - `prompt/explainer.md`: practices for longer explainer animations, embedding them into pages, and common pitfalls.


## Development

    npm start          # dev server for the demo in web/
    ./build            # src -> dist, and copy to web/static/assets/lib/lotion/dev

the packed block demo is generated from the running dev server:

    node dist/cli.js bundle http://localhost:<port> lotion-demo web/static/block/lotion-demo.bundle.html


## License

MIT
