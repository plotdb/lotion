# lotion document ( experimental, version 1 )

A lotion work can carry a Markdown document that describes it: what it says, what it shows, where its
data comes from, what it is built with. The work's code stays the source of truth; the document is
for readers that should not have to run or parse it ( search, review, summaries, translation, agents
about to edit the work ), and it stays readable by people.

This spec fixes only where the document lives, how it refers to other things, and how readers treat
what they do not know. What to write, and how much, is up to the author; a document with only a title
is valid.


## Where

Readers take the first one found:

 1. the player option `doc`: a Markdown string.
 2. an element in the page: `<script type="text/markdown" id="lotion-doc">…</script>`. It travels
    with single-file works and `lotion bundle`.
 3. a file `index.md` beside the work's `index.html` ( a directory or a zip ).

`lotion.player` reads 1 or 2 into `player.doc` and, in `?render` mode, exposes it as `window.DOC`.
`lotion doc <src> <out.md>` exports it, or drafts one from the page's chapters and captions when the
page has none.


## Format

Markdown, with an optional YAML front matter between `---` lines.

Every field is optional. Readers ignore fields, sections and labels they do not know, and must not
fail on them: a newer document stays readable by an older reader.

### Front matter fields

 - `lotion`: the version of this spec the document follows. `1`.
 - `title`, `summary`: strings.
 - `lang`: BCP 47 tag, such as `zh-TW`.
 - `kind`: what kind of work it is. Known values: `linear` ( plays from start to end ), `loop`,
   `infinite` ( generative, no end ), `interactive` ( driven by the reader ). The set is open.
 - `duration`: seconds, for `linear` and `loop`.
 - `style`: a ref ( see below ) to the style the work follows.
 - `uses`: refs the work is built with: styles, assets, libraries.
 - `sources`: where facts and data come from. Strings, or `{title, url}`.
 - `authors`, `license`, `created`: as usual.
 - `ext`: extension data, keyed by the package that defines it, for example
   `ext: {"@plotdb/shelf": {...}}`. Anything not listed here goes in `ext`.

### Refs

A ref names a thing published elsewhere, npm style:

    <package>[@<version>]:<path>[#<fragment>]

 - `package`: an npm package name, scoped or not.
 - `version`: an npm version or range. Leave it out for "any".
 - `path`: an item inside the package. The package defines its paths; lotitor's style library uses
   `style/<id>`.
 - `fragment`: defined by the package as well, such as a revision of the item.
 - without `package:`, the path is relative to the work itself.

Examples: `@plotdb/lotitor@0.0.1:style/p-sumi-e`, `@plotdb/lotitor:style/p-sumi-e#v1`,
`asset/paper.jpg`.

### Body

Free Markdown. These conventions help machines and cost people nothing, but none is required:

 - one heading per part of the work: a chapter, a scene, a state.
 - attributes after a heading, in braces, describe the part:
   - `{t=0-6}` a time range in seconds, for linear parts.
   - `{state=compare}` or `{on="click: next"}` for interactive ones.
   - `{#id}` an id other parts can link to.
 - inside a part, list items starting with a label:
   - `say:` narration, or text shown on screen.
   - `show:` what the viewer sees.
   - `data:` the numbers shown, with their source.
   - `note:` anything else.
   The set of labels is open.

If the player has `chapters` and `captions`, the document should agree with them; the player data is
authoritative for timing.


## Example

    ---
    lotion: 1
    title: 焚風
    summary: 為什麼翻過山的空氣會變熱：上升時凝結放熱，下沉時乾絕熱增溫。
    lang: zh-TW
    kind: linear
    duration: 44
    style: "@plotdb/lotitor@0.0.1:style/p-sumi-e"
    sources:
      - title: 中央氣象署 CODiS 2005-07-18 07 時
    ---

    ## 開場 {t=0-6}

    - say: 翻過一座山，空氣為什麼變熱了？
    - show: 水墨山形淡入，標題以筆刷擦入。

    ## 對照 {t=29-37}

    - say: 上升冷得慢、下沉熱得快：回到地面，比出發時熱了將近 10 °C。
    - show: 溫度－高度圖：上升線斜率 −6 °C/km，下沉線 +9.8 °C/km。
    - data: 高雄 27.3 °C、臺東觀測 36.9 °C ( 模型 37.6 °C )。
