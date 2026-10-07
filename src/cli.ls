# lotion cli: 以 playwright 開啟動畫頁面, 依 render 協定逐格截圖.
#  render 協定: 頁面帶 ?render 時須提供 window.seek(t) 與 window.DURATION; 選用 window.cues().
#  lotion.player 會自動提供; 其它頁面自行設定這兩個值即可.
#
#  lotion frames <src> <outdir> <t...>      指定時間點各輸出一張 png
#  lotion sheet  <src> <out.png> <t...>     同上, 但拼成一張 contact sheet, 方便快速檢查版面
#  lotion video  <src> <out.mp4>            輸出影片 ( 需要 ffmpeg )
#  lotion cues   <src> <out.json>           匯出 window.cues() 的結果 ( 音效時間點 )
#  lotion bundle <base-url> <block> <out>   以 @plotdb/block 的 manager.bundle 把 block 與其依賴打包成單一檔案
#  lotion bgm | sfx | mix | beats           已移除 ( 移到尚未公開的 @plotdb/lotitor ), 這裡只提示
#
#  <src> 可以是 http(s) 網址, 或本地的 html 檔 / 目錄 ( 會以內建的靜態 server 提供 ).
#  選項:
#   --width 1920 --height 1080   視窗尺寸
#   --fps 60 --sub 1 --shutter 0.5   影片設定. sub > 1 時每格取 sub 個子樣本以 ffmpeg tmix 平均成 motion blur
#   --from 0 --to <duration>     只輸出一段 ( 秒 )
#   --crf 16                     x264 品質
#   --cols 3 --tile 640          contact sheet 的欄數與每格寬度
#   --query a=1&b                附加到網址的參數
#   --block-root /block --lib-root /assets/lib   bundle 時的 registry 位置 ( 相對於 base-url )

require! <[fs path http child_process]>

usage = '''
  usage:
    lotion <frames|sheet|video|cues> <src> <out> [t...] [options]
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
    chromium.launch!then (browser) ->
      browser.newPage({viewport: {width: +(opt.width or 1920), height: +(opt.height or 1080)}, deviceScaleFactor: 1})
        .then (page) ->
          page.on \pageerror, (e) -> console.error "[page] #{e.message}"
          page.goto u, {waitUntil: \networkidle}
            .then -> page.waitForFunction (-> typeof(window.seek) == \function and window.DURATION?), null, {timeout: 30000}
            .then -> page.evaluate -> document.fonts.ready.then -> true
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

video = (src, out, opt) ->
  fps = +(opt.fps or 60)
  sub = +(opt.sub or 1)
  shutter = +(opt.shutter or 0.5)
  open(src, opt).then ({page, duration, close}) ->
    from = +(opt.from or 0)
    to = +(opt.to or duration)
    n = Math.round((to - from) * fps)
    d = shutter / fps / sub
    # 子樣本依序送入; tmix 平均連續 sub 張, select 取每組最後一張 -> 恰為該格 sub 個樣本的平均
    vf = if sub > 1 => ['-vf', "tmix=frames=#sub,select='eq(mod(n\\,#sub)\\,#{sub - 1})',setpts=N/#fps/TB"] else []
    ff = child_process.spawn \ffmpeg, [
      '-y', '-v', 'error', '-f', 'image2pipe', '-framerate', "#{fps * sub}", '-i', '-'
    ] ++ vf ++ [
      '-r', "#fps", '-c:v', 'libx264', '-preset', 'slow', '-crf', "#{opt.crf or 16}"
      '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out
    ], {stdio: ['pipe', 'inherit', 'inherit']}
    t0 = Date.now!
    write = (buf) -> new Promise (res) -> if ff.stdin.write(buf) => res! else ff.stdin.once \drain, res
    step = (i, j) ->
      if i >= n => return Promise.resolve!
      if j >= sub =>
        if i % 300 == 0 => console.log "frame #i/#n #{((Date.now! - t0) / 1000).toFixed(0)}s"
        return step i + 1, 0
      t = Math.max 0, from + i / fps + (if sub > 1 => (j - (sub - 1) / 2) * d else 0)
      shot(page, t).then(write).then -> step i, j + 1
    step 0, 0
      .then -> new Promise (res) -> ff.on(\close, res); ff.stdin.end!
      .then -> close!
      .then -> console.log "#out ( #{n} frames, #{((Date.now! - t0) / 1000).toFixed(0)}s )"

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
  p = switch cmd
  | \frames => frames src, out, times, opt
  | \sheet => sheet src, out, times, opt
  | \video => video src, out, opt
  | \cues => cues src, out, opt
  | \bundle => (if rest.0 => bundle(src, out, rest.0, opt) else null)
  | otherwise => null
  if !p or !src or !out => console.log usage; process.exit 1
  p.catch (e) -> console.error e.message or e; process.exit 1
