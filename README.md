# lotion

Deterministic motion toolkit: write animations as a pure function of time, `seek(t)`, then
play, scrub, embed, or render them frame by frame into video.

 - runtime ( `dist/index.js` ): springs in closed form, keyframe tracks, fade windows, small DOM helpers,
   and a player with scrubbing / chapters / fullscreen.
 - block player ( `dist/block/player.js` ): package an animation as a `@plotdb/block` and embed it anywhere.
 - cli ( `lotion` ): render any page following the render protocol into png frames, contact sheets or mp4,
   and bundle blocks.
 - prompt ( `prompt/lotion.md` ): how to write a lotion animation correctly, for people and AI agents.

lotion is self-contained for writing, playing and rendering animations. Authoring aids ( guides for specific forms,
a style library, asset and audio generation ) are kept in a separate toolkit, `@plotdb/lotitor`, which is not public
yet; nothing in lotion depends on it.


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
 - `chapters`: optional `[[t, name, meta?], ...]`, shown as ticks on the timeline and used by `←` / `→`. `meta` is
   an optional object ( such as `{description, thumb}` ) the player passes through in `player.chapter`.
 - `captions`: optional `[[t0, t1, text, meta?], ...]` ( `meta` such as `{speaker}` ), or `{zh: [...], en: [...]}`
   for several languages. See Captions.
 - `captionsBurned`: `true` when the scene already shows the narration as text: captions start off. default
   `false` ( captions start on ). Readers can always turn them on or off.
 - `captionLang`: initial caption language. default the first one.
 - `burnCaptions`: draw captions in `?render` mode ( frame export ). default `false`; `?render&captions` also works.
 - `start`: initial time. `?t=<sec>` in the url takes precedence.
 - `autoplay`: default `false`.
 - `cues`: optional function returning sound cues `[{t, ...}]`, exported by `lotion cues`.
 - `loading`: what to show before `start()`. default `true` ( a spinner ); a string is used as custom html;
   `false` shows nothing.

player methods: `start()`, `seek(t)`, `play(go = true)`, `pause()`, `toggle()`, `fullscreen()`, `encode(opt)`
( see Online Export ), `showCaptions(on = true)`, `setCaptionLang(lang)`, `on(name, cb)`, `off(name, cb)`.
`player.ready` is a promise resolved by `start()`.

player state: `t`, `playing`, `chapter` ( `{index, t, name, meta}` or `null` ), `caption`
( `{t0, t1, text, meta, lang}` or `null` ), `captionsOn`, `captionLang`, `captionLangs`.

events ( `player.on(name, cb)` ):

 - `time`: every seek, with `t`.
 - `chapter`: the current chapter changed, with `player.chapter`.
 - `caption`: the shown caption changed ( including to `null` ), with `player.caption`. Fired whether captions
   are on or off, so a page can read them anyway ( search, transcripts ).
 - `captions`: captions turned on / off or switched language, with `{on, lang}`.

Until `start()` is called, the stage is hidden behind the loading screen, the control bar is disabled, and
`seek` / `play` do nothing. Scenes often need asynchronous preparation before the first frame is right
( web fonts, measuring the layout to place things ), and a half-built stage should not be seen or scrubbed.
So build the scene, finish whatever it waits for, then call `start()`:

    Promise.all([document.fonts.ready, prepare!]).then -> p.start!
Keys ( when the player is focused ): `space` play / pause, `←` / `→` previous / next chapter, `f` fullscreen,
`c` captions on / off.

### Captions

Captions are drawn by the player, outside the stage: they keep their size when the stage scales, sit in a safe
area at the bottom, and are not part of `encode()` frames. Style them with css variables on `.lotion`:
`--lotion-caption-size`, `--lotion-caption-bg`, `--lotion-caption-color`, `--lotion-caption-font`.
The control bar shows a `CC` button when there are captions.

`lotion.vtt.parse(text)` reads WebVTT into the caption format ( a `<v name>` voice becomes `{speaker}` ),
`lotion.vtt.stringify(captions)` writes it back. `lotion video` writes a `.vtt` next to the mp4, and
`lotion captions` exports it alone.

Guidelines for splitting ( common subtitle practice ): Traditional Chinese up to about 16 characters a line, at most
2 lines, no faster than about 9 characters a second; English up to about 42 characters a line, 17 - 20 a second.
Keep each caption on screen 0.83 - 7 s, with at least 2 frames between captions. Break at punctuation or pauses,
not inside a phrase; merge captions that are too short. With word timings from a speech generator, cut at sentence
ends and at pauses longer than about 0.3 s, then split or merge by those limits.

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


## Online Export

`player.encode(opt)` renders the animation to mp4 inside the browser, with no server: it seeks frame by frame, captures
the stage with [snapdom](https://github.com/zumerlab/snapdom) and encodes with WebCodecs through
[mediabunny](https://github.com/Vanilagy/mediabunny). Returns a promise of a `Blob` ( `video/mp4` ).

    p.encode({fps: 30, progress: (v) -> console.log v})
      .then (blob) -> a.href = URL.createObjectURL(blob)

options:

 - `width`, `height`: output size, default the player's design size; rounded to even numbers.
 - `fps`: default `30`. `from`, `to`: render only a range, in seconds.
 - `sub`, `shutter`: motion blur, as in the cli.
 - `bitrate`: in bps. default mediabunny's `QUALITY_HIGH` for the size.
 - `background`: default the stage's background color; black when transparent, since mp4 has no alpha.
 - `progress(v)`: `0..1`. `signal`: an `AbortSignal`; aborting rejects with an `AbortError`.

While encoding, the player is paused and locked, the stage is shown unscaled ( snapdom pads a scaled element by a few
pixels, which shrinks the frame slightly ) behind a cover showing the progress, and afterwards it returns to the time
it was at.

snapdom and mediabunny are loaded by dynamic `import()` only when encoding, from jsdelivr by default. Point
`lotion.libs.snapdom` / `lotion.libs.mediabunny` to self-hosted ES module builds
( `@zumer/snapdom/dist/snapdom.mjs`, `mediabunny/dist/bundles/mediabunny.min.mjs` ), or pass loaded modules as
`opt.snapdom` / `opt.mediabunny`. `lotion.encode({el, seek, duration, ...})` does the same for any element, such as a
block; `el` should not be scaled by a transform.

Frames match the cli's closely ( about 49 dB PSNR on the demo, the remaining difference being compression ), since
both are rasterized by the browser; what snapdom cannot capture ( cross-origin images or fonts without CORS, iframes )
differs. Requires `VideoEncoder` ( Chrome / Edge, Safari 16.4+, Firefox 130+ ). Speed is bound by snapdom cloning the
DOM, not by resolution: the 17 seconds demo at 1080p30 takes about 46 seconds in Chrome on a development mac. For long or
final renders, the cli remains faster ( `--workers` ) and exact.


## Vector ( experimental )

`dist/vector.js` converts the current frame into a vector svg with [satori](https://github.com/vercel/satori):

    <script src="index.min.js"></script>
    <script src="vector.min.js"></script>

    lotion.vector(el).then ({svg, warnings}) -> ...
    player.vector(t).then ({svg, warnings}) -> ...   # the frame at t, without moving the player

`vector.js` extends the `lotion` object loaded before it, so load it after `index.js`. In a block, declare it as a
dependency after lotion ( `{name: 'lotion', path: 'vector.min.js'}` ); rescope gives it the same `lotion`.

 - layout is read from the browser ( `offsetLeft` / `offsetWidth` ... ) and every element becomes an absolutely
   positioned satori node with its computed style; text becomes paths.
 - fonts are collected from the page's `@font-face` rules by the families, weights and characters in use, following
   `font-family` fallbacks and `unicode-range`. woff2 is decompressed ( woff2-encoder ), then each font is subset with
   HarfBuzz, which also pins variable fonts ( as served by Google Fonts ) to the weight in use; satori would otherwise
   draw only their default instance. Pass `opt.fonts` to provide fonts yourself.
 - `mix-blend-mode` on children of the root is kept by converting the children in layers and stacking them with
   svg `mix-blend-mode` ( honored by browsers, not by every svg viewer ).
 - inline `<svg>` is embedded as an svg image with its computed styles, the external definitions it references and
   the fonts its text needs. `<img>` and `<canvas>` are embedded as raster images.
 - satori, woff2-encoder and the HarfBuzz subsetter ( wasm ) are loaded on demand; urls are in `lotion.libs`.
 - what may differ is listed in `warnings`: blend on nested elements, text mixed with elements, characters without a
   web font ( system fonts are not available ), mask or clip-path under a transform other than a translation
   ( satori does not move masks with transforms ).

### Animated svg

`lotion.animate({el, seek, duration, fps})` ( or `player.animate({fps})` ) converts the whole animation into one svg
that plays by itself, resolving to `{svg, warnings, stats}`:

 - every element becomes a `<g>`, nested as in the dom. Its motion, the position and transform combined into a
   matrix, opacity and a `blur()` filter, is sampled at `fps` and written as css keyframes, keeping only the samples
   linear interpolation needs.
 - everything else is its appearance. Each distinct appearance is drawn once ( by satori ) and shown by visibility
   keyframes, so an element that only moves costs one drawing, while one whose content changes ( typing, a growing
   width ) costs one per state. Elements with a css mask, clip-path or other filters, `<img>` and `<canvas>`, are
   drawn with their children as one appearance.
 - inline svg is kept as svg: groups animate like elements, leaves keep their markup with numeric attributes
   ( coordinates, `stroke-dashoffset`, opacities ... ) written as smil `<animate>`, definitions are written once,
   and text uses fonts embedded once. nested `<svg>` becomes a group, since smil inside a nested svg does not follow
   the outer svg when paused or seeked.
 - tracks are written once per element: positions of svg leaves join the group matrix, and inheritable values
   ( `stroke-dashoffset`, `stroke-width`, fill / stroke opacity ) animate on the group.
 - a css mask of one `linear-gradient` ( horizontal or vertical, `no-repeat` ) becomes an svg mask whose rect follows
   `mask-position` / `mask-size`, so a wipe draws its content once. Other masks and clip-paths are drawn per state.
 - a path whose `d` grows ( each one a prefix of a longer one, stroked without fill, dashes or markers ) becomes the
   longest path revealed by a dash animation.
 - options: `fps` ( default 30 ), `from`, `to`, `loop` ( default true ), `progress`, `signal`.

The demo converts in under a second into 230 KB ( 35 KB with brotli ); the code-only sumi-ink trial ( 44 s at 10 fps )
in about 2 seconds into 1.5 MB ( 230 KB with brotli ). Serve it compressed, or save it as `.svgz`. Frames of the animated svg match screenshots as closely as single frames do.

On the demo and the sumi-ink trial of lotitor, frames rasterized from the svg match screenshots at 29 - 39 dB PSNR;
the remaining difference is mostly text antialiasing and baselines in fixed line-heights. A frame takes 50 - 300 ms.


## Render protocol

With `?render` in the url, a page should cover the viewport with its stage and expose:

 - `window.seek(t)`: render the frame at `t`.
 - `window.DURATION`: total length in seconds.
 - `window.cues()`: optional, list of sound cues.
 - `window.CAPTIONS`: optional, captions as `{lang: [[t0, t1, text, meta?], ...]}` ( `lotion video` writes them as
   `.vtt` ).

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
    lotion video  <src> <out.mp4>            render to mp4, plus <out>.vtt when the page has captions
    lotion cues   <src> <out.json>           dump window.cues()
    lotion captions <src> <out.vtt>          export captions as WebVTT ( out.<lang>.vtt for several languages )
    lotion bundle <base-url> <block> <out>   pack a block and its dependencies into one file
    lotion bgm | sfx | mix | beats           removed, see Audio

`<src>` is an http(s) url, or a local html file / directory served by a built-in static server.

options:

 - `--width 1920 --height 1080`: viewport size.
 - `--fps 60`, `--sub 1`, `--shutter 0.5`: video settings. with `--sub` greater than 1, each frame averages
   `sub` sub-samples spread over `shutter` of the frame interval ( motion blur, via ffmpeg `tmix` ).
 - `--workers 1`: render a video with N browsers in parallel. frames are split into contiguous ranges, each encoded on
   its own, then joined without re-encoding. since every frame depends on `t` only, the result matches a single worker.
 - `--from`, `--to`: render only a range, in seconds.
 - `--crf 16`: x264 quality.
 - `--cols 3`, `--tile 640`: contact sheet layout.
 - `--query`: extra url parameters, such as `--query bar=1`.
 - `--block-root /block`, `--lib-root /assets/lib`: registry paths for `bundle`, relative to `base-url`.


## Audio

The audio generators ( `bgm`, `sfx`, `mix`, `beats` ) are no longer part of lotion; `lotion bgm ...` and the like
only print a notice. Sound stays aligned through cues: the page's `cues()` lists `[{t, ...}]`, `lotion cues` exports
it, and any audio tool can place sounds at those times. Then add the track to the rendered video:

    lotion cues page.html cues.json
    lotion video page.html silent.mp4
    ffmpeg -i silent.mp4 -i audio.wav -c:v copy -c:a aac -shortest out.mp4


## Prompts

 - `prompt/lotion.md`: writing `seek(t)`, embedding into pages, block packaging, and common pitfalls.

Guides for specific forms ( explainers, UI loops ) and for choosing a style moved to the authoring toolkit
`@plotdb/lotitor` ( not public yet ). `prompt/lotion.md` covers everything needed to write a lotion animation.


## Development

    npm start          # dev server for the demo in web/
    ./build            # src -> dist, and copy to web/static/assets/lib/lotion/dev

the packed block demo is generated from the running dev server:

    node dist/cli.js bundle http://localhost:<port> lotion-demo web/static/block/lotion-demo.bundle.html


## Credits

Releases up to v0.1.0 included `prompt/ui-loop.md`, derived from a prompt template posted by zero
( [@twoclipping](https://x.com/twoclipping) ) on X on 2026-09-25: https://x.com/twoclipping/status/2103273003555402193 .
The post says "im open sourcing the prompt template for these motion designs" but attaches no explicit license, so that
file was never covered by lotion's MIT license; rights remain with the author. It is no longer part of lotion.


## License

MIT
