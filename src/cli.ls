# lotion cli: 以 playwright 開啟動畫頁面, 依 render 協定逐格截圖.
#  render 協定: 頁面帶 ?render 時須提供 window.seek(t) 與 window.DURATION; 選用 window.cues() 與
#  window.CAPTIONS ( 字幕 {lang: [[t0, t1, text, meta?], ...]} ), window.DOC ( 文稿 ),
#  window.LANG / window.LANGS ( 目前語系與作品支援的語言, 網址 ?lang=xx 決定 ),
#  window.ASPECT / window.ASPECTS ( 目前版面方向與各方向的尺寸 {name: [w, h]}, 網址 ?aspect=xx 決定 ).
#  lotion.player 會自動提供; 其它頁面自行設定這兩個值即可.
#
#  lotion frames <src> <outdir> <t...>      指定時間點各輸出一張 png
#  lotion sheet  <src> <out.png> <t...>     同上, 但拼成一張 contact sheet, 方便快速檢查版面
#  lotion video  <src> <out.mp4>            輸出影片 ( 需要 ffmpeg ). 頁面有字幕時, 另輸出同名的 .vtt
#  lotion cues   <src> <out.json>           匯出 window.cues() 的結果 ( 音效時間點 )
#  lotion captions <src> <out.vtt>          匯出字幕為 WebVTT ( 多語言時為 out.<lang>.vtt )
#  lotion doc    <src> <out.md>             匯出文稿 ( window.DOC ); 沒有時以章節與字幕起草 ( spec/document.md )
#  lotion bundle <base-url> <block> <out>   以 @plotdb/block 的 manager.bundle 把 block 與其依賴打包成單一檔案
#  lotion bgm | sfx | mix | beats           已移除 ( 移到尚未公開的 @plotdb/lotitor ), 這裡只提示
#
#  <src> 可以是 http(s) 網址, 或本地的 html 檔 / 目錄 ( 會以內建的靜態 server 提供 ).
#  選項:
#   --width 1920 --height 1080   視窗尺寸. 未指定時, 頁面有宣告版面方向 ( window.ASPECTS ) 就用目前方向的尺寸
#   --fps 60 --sub 1 --shutter 0.5   影片設定. sub > 1 時每格取 sub 個子樣本以 ffmpeg tmix 平均成 motion blur
#   --workers 1                  video 以 N 個瀏覽器平行渲染 ( 影格切成連續片段, 最後串接, 不重新編碼 )
#   --from 0 --to <duration>     只輸出一段 ( 秒 )
#   --crf 16                     x264 品質
#   --cols 3 --tile 640          contact sheet 的欄數與每格寬度
#   --query a=1&b                附加到網址的參數
#   --lang xx                    以該語系輸出 ( 網址帶 ?lang=xx ). video / captions 只輸出該語系的字幕.
#                                all: 每個語系 ( window.LANGS ) 各輸出一份, 檔名加上語系, 如 out.en.mp4
#   --aspect portrait            以該版面方向輸出 ( 網址帶 ?aspect=portrait, 視窗用該方向的尺寸 ).
#                                all: 每個方向 ( window.ASPECTS ) 各輸出一份, 如 out.portrait.mp4;
#                                與 --lang all 並用時為 out.<lang>.<aspect>.mp4
#   --state '{"temp":30}'        互動作品以此狀態輸出 ( 網址帶 ?state=<JSON>, 合併進 player 的 state 初始值 )
#   --block-root /block --lib-root /assets/lib   bundle 時的 registry 位置 ( 相對於 base-url )

require! <[fs path http child_process]>

usage = '''
  usage:
    lotion <frames|sheet|video|cues|captions|doc> <src> <out> [t...] [options] [--lang <xx|all>] [--aspect <xx|all>]
    lotion bundle <base-url> <block-name> <out> [options]
    audio generators ( bgm | sfx | mix | beats ) were removed, see README > Audio
  see README for options.
'''

parse = (argv) ->
  [pos, opt] = [[], {}]
  i = 0
  while i < argv.length
    a = argv[i]
    if /^--/.test a => opt[a.replace(/^--/, '')] = argv[i + 1]; i += 2
    else pos.push a; i++
  {pos, opt}

types =
  '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json'
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.woff2': 'font/woff2'
  '.woff': 'font/woff', '.mp3': 'audio/mpeg', '.wav': 'audio/wav'

# 本地檔案以簡易靜態 server 提供, 回傳 {url, close}
serve = (src) -> new Promise (res, rej) ->
  stat = fs.statSync src
  root = if stat.isDirectory! => src else path.dirname(src)
  page = if stat.isDirectory! => '' else path.basename(src)
  server = http.createServer (req, rsp) ->
    f = path.join root, decodeURIComponent(req.url.split('?').0)
    if fs.existsSync(f) and fs.statSync(f).isDirectory! => f = path.join f, 'index.html'
    fs.readFile f, (e, buf) ->
      if e => rsp.writeHead 404; return rsp.end!
      rsp.writeHead 200, {'Content-Type': types[path.extname(f)] or 'application/octet-stream'}
      rsp.end buf
  server.on \error, rej
  server.listen 0, -> res {url: "http://localhost:#{server.address!port}/#page", close: -> server.close!}

# playwright 是 peer dependency, 需由使用者另外安裝; 缺少時給出安裝方式而非 node 的堆疊訊息.
# 瀏覽器本體 ( chromium ) 未安裝時, playwright 自己的錯誤訊息已會提示 `npx playwright install`.
playwright = ->
  try require \playwright
  catch e
    if e.code != \MODULE_NOT_FOUND or !/playwright/.test(e.message) => throw e
    console.error '''
    lotion: this command needs playwright, which is not installed. install it with:

        npm i -D playwright
        npx playwright install chromium
    '''
    process.exit 1

open = (src, opt) ->
  {chromium} = playwright!
  p = if /^https?:/.test(src) => Promise.resolve({url: src, close: ->}) else serve(src)
  p.then (srv) ->
    [u, h] = srv.url.split '#'
    u += (if /\?/.test(u) => '&' else '?') + 'render' + (if opt.query => "&#{opt.query}" else '')
    if opt.lang => u += "&lang=#{encodeURIComponent opt.lang}"
    if opt.aspect => u += "&aspect=#{encodeURIComponent opt.aspect}"
    if opt.state => JSON.parse(opt.state); u += "&state=#{encodeURIComponent opt.state}"
    chromium.launch!then (browser) ->
      browser.newPage({viewport: {width: +(opt.width or 1920), height: +(opt.height or 1080)}, deviceScaleFactor: 1})
        .then (page) ->
          page.on \pageerror, (e) -> console.error "[page] #{e.message}"
          page.goto u, {waitUntil: \networkidle}
            .then -> page.waitForFunction (-> typeof(window.seek) == \function and window.DURATION?), null, {timeout: 30000}
            .then -> page.evaluate -> document.fonts.ready.then -> true
            # 有宣告版面方向且未指定視窗尺寸: 視窗改為目前方向的尺寸, 等播放器依新尺寸排好
            .then -> page.evaluate -> if window.ASPECTS and window.ASPECT => window.ASPECTS[window.ASPECT] else null
            .then (sz) ->
              if !sz or opt.width or opt.height => return
              page.setViewportSize {width: sz.0, height: sz.1}
                .then -> page.evaluate -> new Promise (res) -> requestAnimationFrame -> requestAnimationFrame -> res!
            .then -> page.evaluate -> window.DURATION
            .then (duration) ->
              {page, duration, close: -> browser.close!then -> srv.close!}

shot = (page, t, type = \png) ->
  page.evaluate ((t) -> window.seek t), t
    .then -> page.screenshot {type}

frames = (src, out, times, opt) ->
  fs.mkdirSync out, {recursive: true}
  open(src, opt).then ({page, close}) ->
    times.reduce(((p, t, i) ->
      p.then -> shot(page, t).then (buf) ->
        fs.writeFileSync path.join(out, "f#{"#i".padStart(3, '0')}-#{t}.png"), buf
    ), Promise.resolve!)
      .then -> close!

sheet = (src, out, times, opt) ->
  tmp = fs.mkdtempSync path.join(require(\os).tmpdir!, 'lotion-')
  cols = +(opt.cols or 3)
  rows = Math.ceil(times.length / cols)
  frames(src, tmp, times, opt).then ->
    new Promise (res, rej) ->
      ff = child_process.spawn \ffmpeg, [
        '-v', 'error', '-y', '-pattern_type', 'glob', '-i', path.join(tmp, '*.png')
        '-vf', "scale=#{opt.tile or 640}:-1,tile=#{cols}x#{rows}", '-frames:v', '1', out
      ], {stdio: \inherit}
      ff.on \close, (c) ->
        fs.rmSync tmp, {recursive: true, force: true}
        if c => rej new Error("ffmpeg exited with #c") else res!

WARM = 3
# 以 ffmpeg 編碼第 i0 ~ i1 格 ( 不含 i1 ). 每格取 sub 個子樣本, 以 tmix 平均成 motion blur
encode = (page, i0, i1, out, o, tick) ->
  {fps, sub, shutter, from} = o
  d = shutter / fps / sub
  # 子樣本依序送入; tmix 平均連續 sub 張, select 取每組最後一張 -> 恰為該格 sub 個樣本的平均
  vf = if sub > 1 => ['-vf', "tmix=frames=#sub,select='eq(mod(n\\,#sub)\\,#{sub - 1})',setpts=N/#fps/TB"] else []
  ff = child_process.spawn \ffmpeg, [
    '-y', '-v', 'error', '-f', 'image2pipe', '-framerate', "#{fps * sub}", '-i', '-'
  ] ++ vf ++ [
    '-r', "#fps", '-c:v', 'libx264', '-preset', 'slow', '-crf', "#{o.crf}"
    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out
  ], {stdio: ['pipe', 'inherit', 'inherit']}
  write = (buf) -> new Promise (res) -> if ff.stdin.write(buf) => res! else ff.stdin.once \drain, res
  step = (i, j) ->
    if i >= i1 => return Promise.resolve!
    if j >= sub => tick!; return step i + 1, 0
    t = Math.max 0, from + i / fps + (if sub > 1 => (j - (sub - 1) / 2) * d else 0)
    shot(page, t).then(write).then -> step i, j + 1
  # 暖機: 片段開頭先渲染前 WARM 格並丟棄. 剛開的頁面直接跳到某一格時, 頭兩格的點陣化會和連續播放時略有不同
  # ( 實測差異只在片段開頭兩格, PSNR 約 86 dB ), 先走過前幾格就與單一 worker 逐格一致.
  warm = [Math.max(0, i0 - WARM) til i0].reduce ((p, i) -> p.then -> shot page, Math.max(0, from + i / fps)), Promise.resolve!
  warm.then -> step i0, 0
    .then -> new Promise (res, rej) ->
      ff.on \close, (c) -> if c => rej new Error("ffmpeg exited with #c") else res!
      ff.stdin.end!

# --workers N: 畫面是 t 的純函數, 任一格都能獨立算出, 所以把影格切成 N 段連續範圍,
# 各開一個瀏覽器同時渲染、各自編碼, 最後以 concat 串接 ( 不重新編碼 ). 每段從整數格開始, sub 的分組不會被切斷.
video = (src, out, opt) ->
  o = {fps: +(opt.fps or 60), sub: +(opt.sub or 1), shutter: +(opt.shutter or 0.5), crf: (opt.crf or 16)}
  workers = Math.max 1, Math.floor(+(opt.workers or 1))
  t0 = Date.now!
  open(src, opt).then (first) ->
    o.from = +(opt.from or 0)
    n = Math.round((+(opt.to or first.duration) - o.from) * o.fps)
    done = 0
    tick = -> if ++done % 300 == 0 => console.log "frame #done/#n #{((Date.now! - t0) / 1000).toFixed(0)}s"
    console.log "frame 0/#n 0s" + (if workers > 1 => " ( #workers workers )" else '')
    finish = -> console.log "#out ( #n frames, #{((Date.now! - t0) / 1000).toFixed(0)}s )"
    vtt = write-vtt first.page, out, o.from, +(opt.to or first.duration), opt.lang
    if workers == 1 => return vtt.then(-> encode first.page, 0, n, out, o, tick).then(-> first.close!).then finish
    k = Math.min workers, n
    tmp = fs.mkdtempSync path.join(require(\os).tmpdir!, 'lotion-')
    parts = [0 til k].map (w) -> {i0: Math.floor(n * w / k), i1: Math.floor(n * (w + 1) / k), out: path.join(tmp, "part-#w.mp4")}
    vtt.then(-> Promise.all [Promise.resolve(first)] ++ [1 til k].map(-> open src, opt))
      .then (pages) ->
        Promise.all(parts.map (p, w) -> encode(pages[w].page, p.i0, p.i1, p.out, o, tick))
          .finally -> Promise.all pages.map (p) -> p.close!
      .then ->
        list = path.join tmp, 'list.txt'
        fs.writeFileSync list, parts.map((p) -> "file '#{p.out}'").join('\n')
        new Promise (res, rej) ->
          ff = child_process.spawn \ffmpeg, [
            '-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', '-movflags', '+faststart', out
          ], {stdio: \inherit}
          ff.on \close, (c) -> if c => rej new Error("ffmpeg concat exited with #c") else res!
      .finally -> fs.rmSync tmp, {recursive: true, force: true}
      .then finish

# 字幕寫成 WebVTT: 只取 [from, to) 範圍內的段落, 時間改為相對 from. 多語言時每個語言一個檔
# 指定 one ( --lang ) 時只輸出頁面目前語系 ( window.LANG ) 對應的那一軌, 寫成單一檔案
write-vtt = (page, out, t0, t1, one) ->
  {vtt} = require './index'
  page.evaluate(-> {tracks: window.CAPTIONS or null, lang: window.LANG or null}).then ({tracks, lang: cur}) ->
    if !tracks => return
    langs = Object.keys tracks
    if one
      langs = [match-lang(cur or one, langs) ? langs.0]
    base = out.replace /\.(vtt|mp4|webm|mov)$/i, ''
    for lang in langs
      list = tracks[lang].filter((c) -> c.1 > t0 and c.0 < t1).map (c) ->
        [Math.max(0, c.0 - t0), Math.min(t1, c.1) - t0] ++ c.slice(2)
      f = if langs.length > 1 and lang => "#base.#lang.vtt" else "#base.vtt"
      fs.writeFileSync f, vtt.stringify list
      console.log f

# 文稿: 頁面有就原樣輸出, 否則以章節、字幕與頁面標題起草
write-doc = (src, out, opt) ->
  open(src, opt).then ({page, close}) ->
    page.evaluate(-> {doc: window.DOC, chapters: window.CHAPTERS, captions: window.CAPTIONS, duration: window.DURATION, title: document.title, lang: window.LANG or document.documentElement.lang})
      .then (r) ->
        text = if r.doc => r.doc else require('./index').doc.draft(r)
        fs.write-file-sync out, text.replace(/\s*$/, '\n')
        console.log "#out ( #{if r.doc => 'from the page' else 'drafted from chapters and captions'} )"
      .then -> close!

# 寬鬆比對語系 ( 同 lotion 的 match-lang ): 完全相同優先, 其次比主標籤
match-lang = (want, list) ->
  w = "#want".toLowerCase!
  list.find((l) -> "#l".toLowerCase! == w) ? list.find((l) -> "#l".toLowerCase!split(/[-_]/).0 == w.split(/[-_]/).0)

# --lang all / --aspect all: 先讀頁面宣告的清單, 再逐一以 --<key> <xx> 執行, 輸出檔名加上該值
# ( out.mp4 -> out.en.mp4; frames / sheet 的目錄則加一層 ). 兩者並用時巢狀執行: out.en.portrait.mp4
for-each = (key, src, out, opt, run) ->
  open(src, ({} <<< opt <<< {lang: null, aspect: null})).then ({page, close}) ->
    page.evaluate(((k) -> if k == \lang => window.LANGS or [] else Object.keys(window.ASPECTS or {})), key)
      .then (list) -> close!then -> list
  .then (list) ->
    if !list.length
      console.error "lotion: the page declares no #{if key == \lang => 'languages ( window.LANGS )' else 'aspects ( window.ASPECTS )'}; rendering once"
      return run out, ({} <<< opt <<< {(key): null})
    with-v = (v) ->
      ext = path.extname out
      if ext => out.slice(0, -ext.length) + ".#v#ext" else path.join(out, v)
    list.reduce ((p, v) -> p.then -> run with-v(v), ({} <<< opt <<< {(key): v})), Promise.resolve!

cues = (src, out, opt) ->
  open(src, opt).then ({page, close}) ->
    page.evaluate(-> if window.cues => window.cues! else [])
      .then (c) -> fs.writeFileSync out, JSON.stringify(c, null, 1)
      .then -> close!

# block 打包需要 DOM 與 eval, 借瀏覽器執行. bundle 版的 csscope / rescope / block 才帶有 bundle API.
bundle = (base, name, out, opt) ->
  {chromium} = playwright!
  base = base.replace /\/$/, ''
  m = (f) -> require.resolve f
  chromium.launch!then (browser) ->
    browser.newPage!
      .then (page) ->
        page.on \pageerror, (e) -> console.error "[page] #{e.message}"
        # 同源頁面才能取用 registry 上的檔案; 頁面本身是否存在不重要
        page.goto base, {waitUntil: \load} .catch(->)
          .then ->
            libs = <[@plotdb/semver/index.min.js proxise/index.min.js @plotdb/csscope/bundle.js
            @plotdb/rescope/bundle.js @plotdb/block/bundle.js]>
            libs.reduce ((p, f) -> p.then -> page.addScriptTag {path: m(f)}), Promise.resolve!
          .then ->
            page.evaluate (({base, name, br, lr}) ->
              mgr = new block.manager registry:
                lib: ({name, version, path}) -> "#base#lr/#name/#{version or \main}/#{path or 'index.min.js'}"
                block: ({name, path}) -> "#base#br/#name/#{path or 'index.html'}"
              mgr.bundle({blocks: [{name}]}).then (r) -> r.code
            ), {base, name, br: (opt['block-root'] or '/block'), lr: (opt['lib-root'] or '/assets/lib')}
      .then (code) ->
        fs.writeFileSync out, code
        console.log "#out ( #{code.length} bytes )"
      .finally -> browser.close!

# 音訊產生器已移到 @plotdb/lotitor ( 尚未公開 ); 保留指令名稱, 只提示. 沒有 lotitor 也能以 cues 對齊任何音訊工具
moved = (cmd) ->
  console.error """
    lotion #cmd: audio generators are no longer part of lotion ( moved to @plotdb/lotitor, not public yet ).
    to align any audio with the animation, export cue times with `lotion cues <src> cues.json`. see README > Audio.
  """
  process.exit 1

argv = process.argv.slice(2)
if argv.0 in <[bgm sfx mix beats]> => moved argv.0
else
  {pos, opt} = parse argv
  [cmd, src, out, ...rest] = pos
  times = rest.map(-> +it)
  run = (out, opt) -> switch cmd
  | \frames => frames src, out, times, opt
  | \sheet => sheet src, out, times, opt
  | \video => video src, out, opt
  | \cues => cues src, out, opt
  | \doc => write-doc src, out, opt
  | \captions => (open(src, opt).then ({page, close}) -> write-vtt(page, out, 0, Infinity, opt.lang).then -> close!)
  | \bundle => (if rest.0 => bundle(src, out, rest.0, opt) else null)
  | otherwise => null
  known = cmd in <[frames sheet video cues doc captions bundle]>
  # --aspect all 包在內層, 檔名順序為 out.<lang>.<aspect>.<ext>
  run-aspects = if opt.aspect == \all => (o, op) -> for-each \aspect, src, o, op, run else run
  p = if !known or !src or !out => null
  else if cmd == \bundle => run out, opt
  else if opt.lang == \all => for-each \lang, src, out, opt, run-aspects
  else run-aspects out, opt
  if !p => console.log usage; process.exit 1
  p.catch (e) -> console.error e.message or e; process.exit 1
