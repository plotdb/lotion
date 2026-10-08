# lotion: 以「時間的純函數」撰寫動畫的小工具組.
#  - 所有畫面狀態都由 seek(t) 依 t 決定, 不保留跨影格狀態, 不用 css transition / setTimeout.
#    因此同一個 t 一定得到同一張畫面, 可以直接逐格輸出成影片 ( 見 lotion cli ).
#  - 彈簧以閉合解 ( step response ) 計算; 目標改變多次時, 把每次改變的 step response 疊加.

{PI, sin, cos, exp, sqrt, round} = Math

# ---------- 數學 ----------
clamp = (v, a = 0, b = 1) -> if v < a => a else if v > b => b else v
lerp = (a, b, f) -> a + (b - a) * f
# smoothstep
ss = (x) -> x = clamp x; x * x * (3 - 2 * x)

# 彈簧 step response, 0 -> 1. w: 角頻率 ( rad/s ), z: 阻尼比; z < 1 時有些微 overshoot.
spring = (t, w = 14, z = 0.8) ->
  if t <= 0 => return 0
  if z >= 1 => return 1 - exp(-w * t) * (1 + w * t)
  wd = w * sqrt(1 - z * z)
  1 - exp(-z * w * t) * (cos(wd * t) + (z * w / wd) * sin(wd * t))

# 常用彈簧設定. 原則: 快、準、最多一點點 overshoot.
presets =
  fast: {w: 22, z: 0.86}
  std: {w: 14, z: 0.8}
  soft: {w: 9, z: 0.9}
  move: {w: 11, z: 0.85}
  # 無 overshoot, 適合透明度或不能超出範圍的值
  ease: {w: 10, z: 1}

# 由關鍵點建立時間函數: track [[t0, v0], [t1, v1], ...], opt
#  - opt: {w, z} 或 preset 名稱; 個別關鍵點也可帶第三個元素指定 preset
#  - 回傳 (t) -> 值. 數值以外的屬性 ( 如顏色 ) 請拆成數個 track 或對 0..1 的 track 做插值
track = (keys, opt = \std) ->
  p = (o) -> if typeof(o) == \string => presets[o] else o
  def = p opt
  (t) ->
    v = keys.0.1
    for i from 1 til keys.length
      k = keys[i]
      c = if k.2 => p(k.2) else def
      v += (k.1 - keys[i - 1].1) * spring(t - k.0, c.w, c.z)
    v

# 內容視窗: t0 開始淡入, t1 開始淡出 ( 省略 t1 則不淡出 ). 回傳 0..1
vis = (t, t0, t1 = 1e9, din = 0.4, dout = 0.35) -> ss((t - t0) / din) * (1 - ss((t - t1) / dout))
# t0 起長 d 秒的脈衝, 0 -> 1 -> 0
bump = (t, t0, d = 0.6) -> if t < t0 or t > t0 + d => 0 else sin(PI * (t - t0) / d) ** 2
# 打字效果: 回傳到 t 為止應顯示的字串
typing = (t, t0, text, dt = 0.06) ->
  chars = Array.from text
  chars.slice(0, clamp(Math.floor((t - t0) / dt) + 1, 0, chars.length)).join('')

# ---------- 顏色 ----------
hex = (h) -> [1 3 5].map (i) -> parseInt(h.slice(i, i + 2), 16)
mixc = (a, b, f) -> [0 1 2].map (i) -> lerp a[i], b[i], f
rgb = (c, a) -> if a? => "rgba(#{c.map(-> round it).join(',')},#a)" else "rgb(#{c.map(-> round it).join(',')})"

# ---------- DOM ----------
# 建立元素. cls 可含多個 class ( 以空白分隔 ), prefix 會加在每個 class 前.
mk = (cls = '', html = '', parent, prefix = '') ->
  e = document.createElement \div
  e.className = cls.split(' ').filter(-> it).map(-> prefix + it).join(' ')
  e.innerHTML = html
  if parent => parent.appendChild e
  e

# 設定位置 / 縮放 / 透明度.
#  - 透明度近 0 時以 visibility 隱藏. 注意: 子元素設為 visible 會蓋過父層的 hidden,
#    所以巢狀的子元素請傳 hide: false, 只對最外層元素切換 visibility.
put = (e, x, y, s = 1, o = 1, opt = {}) ->
  hide = opt.hide ? true
  if hide and o <= 0.002
    if e._lv != false => e.style.visibility = \hidden; e._lv = false
    return
  if hide and e._lv != true => e.style.visibility = \visible; e._lv = true
  e.style.transform = "translate(#{x.toFixed(2)}px,#{y.toFixed(2)}px) scale(#{s.toFixed(4)})"
  e.style.opacity = o.toFixed(3)
  if opt.blur? => e.style.filter = if opt.blur > 0.05 => "blur(#{opt.blur.toFixed(2)}px)" else ''

# 只在內容改變時才寫入 innerHTML
txt = (e, v) -> if e._lt != v => e.innerHTML = v; e._lt = v

NS = 'http://www.w3.org/2000/svg'
svg = (tag, attrs = {}, parent) ->
  e = document.createElementNS NS, tag
  for k, v of attrs => e.setAttribute k, v
  if parent => parent.appendChild e
  e

# ---------- 播放器 ----------
# 把 seek(t) 包成可播放 / 拖曳 / 全螢幕的元件, 並提供逐格輸出用的 render 協定.
#  opt:
#   - root: 容器元素或 selector. 播放器會在其中建立 stage 與控制列.
#   - width / height: 舞台的設計尺寸, 預設 1920 x 1080. 舞台會等比縮放以填入容器.
#   - duration: 總長 ( 秒 )
#   - seek: (t) -> 依 t 更新畫面
#   - chapters: [[t, name], ...] 選用. 顯示於時間軸, 並供 ← / → 跳段.
#   - start: 初始時間. 網址的 ?t=秒數 優先.
#   - autoplay: 預設 false
#   - cues: 選用, -> [{t, name, ...}] 給 cli 匯出音效時間點
#   - loading: start() 之前顯示的載入畫面. 預設 true ( 內建 spinner ); 字串為自訂 html; false 不顯示
#  建構時只建立 dom ( stage 可由 .stage 取得 ); 畫面內容建好後呼叫 start(). .ready 為 start() 時 resolve 的 promise.
#  start() 之前舞台隱藏並顯示載入畫面, 控制列不作用: 內容常需非同步準備 ( 字型、依版面量測位置 ),
#  未完成時的畫面是錯亂的, 不該被看到或被拖曳.
#  網址帶 ?render 時: 舞台蓋滿視窗、隱藏控制列、不播放; 並在 start() 時才設定 window.seek / window.DURATION,
#  讓逐格輸出以「seek 已存在」判斷頁面就緒.
player = (opt = {}) ->
  @opt = opt
  @root = if typeof(opt.root) == \string => document.querySelector(opt.root) else opt.root
  @ <<<
    width: opt.width or 1920
    height: opt.height or 1080
    duration: opt.duration or 0
    chapters: opt.chapters or []
    t: 0
    playing: false
    last: null
    started: false
  # start() 時 resolve: 供外部 ( 如 block loader ) 等待內容就緒
  @ready = new Promise (res) ~> @ready-res = res
  @render-mode = /[?&]render\b/.test location.search
  @init!
  @

player.prototype = Object.create(Object.prototype) <<<
  constructor: player

  init: ->
    r = @root
    r.classList.add \lotion
    if !r.hasAttribute(\tabindex) => r.setAttribute \tabindex, 0
    @viewport = mk \lotion-viewport, '', r
    @stage = mk \lotion-stage, '', @viewport
    @stage.style <<< {width: "#{@width}px", height: "#{@height}px"}
    @viewport.style.aspectRatio = "#{@width} / #{@height}"
    r.classList.add \lotion-loading
    if @opt.loading != false
      html = if typeof(@opt.loading) == \string => @opt.loading else '<div class="lotion-spinner"></div>'
      @loading = mk \lotion-loading-screen, html, @viewport
    @bar = mk \lotion-bar, '''
      <div class="lotion-btn lotion-play"></div>
      <div class="lotion-track"><div class="lotion-rail"></div><div class="lotion-fill"></div>
      <div class="lotion-chapters"></div><div class="lotion-knob"></div></div>
      <div class="lotion-time"></div>
      <div class="lotion-btn lotion-fs" title="全螢幕"><svg width="16" height="16" viewBox="0 0 16 16" fill="none"
      stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M2 6V2h4M10 2h4v4M14 10v4h-4M6 14H2v-4"/></svg></div>
    ''', r
    q = (n) ~> @bar.querySelector ".lotion-#n"
    @el = {play: q(\play), fill: q(\fill), knob: q(\knob), time: q(\time), track: q(\track), chapters: q(\chapters), fs: q(\fs)}
    @chapters.map ([t, name]) ~>
      e = mk \lotion-ch, '', @el.chapters
      e.title = name
      e.style.left = "#{100 * t / @duration}%"
    @bind!
    if @render-mode => r.classList.add \lotion-render
    @fit!
    if typeof(ResizeObserver) != \undefined => new ResizeObserver(~> @fit!).observe @viewport
    else window.addEventListener \resize, ~> @fit!

  # 內容建好後呼叫: 移除載入畫面、顯示初始畫面, 並依設定自動播放
  start: ->
    @started = true
    @root.classList.remove \lotion-loading
    if @loading => @loading.remove!
    if @render-mode
      window.seek = (t) ~> @opt.seek t
      window.DURATION = @duration
      if @opt.cues => window.cues = @opt.cues
    @ready-res @
    m = /[?&]t=([\d.]+)/.exec location.search
    @seek(if m => +m.1 else if @render-mode => 0 else (@opt.start or 0))
    if @opt.autoplay and !@render-mode => document.fonts.ready.then ~> @play true
    @

  bind: ->
    @el.play.addEventListener \click, (e) ~> e.stopPropagation!; @toggle!
    @el.fs.addEventListener \click, (e) ~> e.stopPropagation!; @fullscreen!
    @viewport.addEventListener \click, ~> @root.focus!; @toggle!
    dragging = false
    from-event = (e) ~>
      b = @el.track.getBoundingClientRect!
      @seek @duration * clamp((e.clientX - b.left) / b.width)
    @el.track.addEventListener \pointerdown, (e) ~>
      dragging := true
      @el.track.setPointerCapture e.pointerId
      from-event e
    @el.track.addEventListener \pointermove, (e) ~> if dragging => from-event e
    @el.track.addEventListener \pointerup, ~> dragging := false
    # 鍵盤只在播放器取得焦點時作用, 以免干擾頁面捲動
    @root.addEventListener \keydown, (e) ~>
      starts = @chapters.map (c) -> c.0
      if e.code == \Space => e.preventDefault!; @toggle!
      else if e.key == \f => @fullscreen!
      else if e.key == \ArrowRight => @seek(starts.find((s) ~> s > @t + 0.05) ? @duration)
      else if e.key == \ArrowLeft => @seek(starts.filter((s) ~> s < @t - 0.5).pop! ? 0)

  # encode() 期間舞台維持原尺寸 ( 見 encode ), 不縮放
  fit: ->
    if @encoding => return
    w = @viewport.clientWidth; h = @viewport.clientHeight
    if !w or !h => return
    s = Math.min w / @width, h / @height
    @stage.style.transform = "translate(#{(w - @width * s) / 2}px,#{(h - @height * s) / 2}px) scale(#s)"

  fmt: (t) -> "#{Math.floor(t / 60)}:#{"0#{Math.floor(t % 60)}".slice(-2)}"

  # start() 之前內容尚未就緒, encode() 期間畫面由匯出控制: 都不呼叫 opt.seek, 也不播放
  seek: (t) ->
    if !@started or @encoding => return
    @t = t = clamp t, 0, @duration
    @opt.seek t
    p = "#{100 * t / @duration}%"
    @el.fill.style.width = p
    @el.knob.style.left = p
    ch = @chapters.filter((c) -> c.0 <= t).pop!
    @el.time.textContent = (if ch => "#{ch.1} · " else '') + "#{@fmt t} / #{@fmt @duration}"
    @root.classList.toggle \lotion-playing, @playing

  tick: (now) ->
    if !@playing => return
    if @last? => @seek @t + (now - @last) / 1000
    @last = now
    if @t >= @duration => @playing = false; @seek @t; return
    requestAnimationFrame (n) ~> @tick n

  play: (go = true) ->
    if !@started or @encoding => return
    if go and @t >= @duration => @t = 0
    @playing = go
    @last = null
    @seek @t
    if go => requestAnimationFrame (n) ~> @tick n

  pause: -> @play false
  toggle: -> @play !@playing

  fullscreen: ->
    d = document
    if d.fullscreenElement or d.webkitFullscreenElement
      (d.exitFullscreen or d.webkitExitFullscreen).call d
    else (@root.requestFullscreen or @root.webkitRequestFullscreen).call @root
    @root.focus!

  # 線上匯出 mp4, 回傳 Promise<Blob>. opt 同 lotion.encode, el / seek / duration / 尺寸由播放器提供.
  # 匯出期間暫停並鎖住播放器 ( 拖曳或播放會改動畫面 ), 結束後回到原本的時間.
  # 舞台縮放時 snapdom 會在截圖四周留出幾 px 的邊, 使內容略為縮小偏移; 所以匯出期間取消縮放,
  # 以顯示進度的遮罩蓋住超出容器的舞台.
  encode: (opt = {}) ->
    if !@started => return Promise.reject new Error('[lotion] encode() before start()')
    if @encoding => return Promise.reject new Error('[lotion] already encoding')
    @pause!
    t0 = @t
    @encoding = true
    @root.classList.add \lotion-encoding
    tf = @stage.style.transform
    @stage.style.transform = \none
    cover = mk \lotion-encoding-screen, '<div class="lotion-spinner"></div><div class="lotion-progress"></div>', @viewport
    bar = cover.querySelector \.lotion-progress
    done = ~>
      cover.remove!
      @stage.style.transform = tf
      @encoding = false
      @root.classList.remove \lotion-encoding
      @fit!
      @seek t0
    progress = (v) ->
      bar.textContent = "#{Math.round(v * 100)}%"
      if opt.progress => opt.progress v
    encode({el: @stage, seek: @opt.seek, duration: @duration, width: @width, height: @height} <<< opt <<< {progress})
      .then (b) -> done!; b
      .catch (e) -> done!; throw e

# ---------- 線上匯出 ----------
# 在瀏覽器中逐格 seek(t), 以 snapdom 截圖, 以 WebCodecs ( 透過 mediabunny ) 編碼成 mp4.
# 兩個函式庫只在匯出時才以 dynamic import 載入; 網址可由 lotion.libs 覆寫 ( 例如改用自架的檔案 ),
# 或在 opt.snapdom / opt.mediabunny 直接傳入已載入的模組.
libs =
  snapdom: 'https://cdn.jsdelivr.net/npm/@zumer/snapdom@3.3.0/dist/snapdom.mjs'
  mediabunny: 'https://cdn.jsdelivr.net/npm/mediabunny@1.61.3/dist/bundles/mediabunny.min.mjs'
lib-cache = {}
load-lib = (name) -> lib-cache[name] ?= ``import(libs[name])``

# 匯出 mp4, 回傳 Promise<Blob>. 一般透過 player.encode(opt) 使用.
#  opt:
#   - el: 要截圖的元素. seek: (t) -> 更新畫面. duration: 總長 ( 秒 )
#   - width / height: 輸出尺寸, 預設 1920 x 1080; 會調成偶數 ( H.264 需要 )
#   - fps: 預設 30. from / to: 只輸出一段 ( 秒 )
#   - sub / shutter: 同 cli. sub > 1 時每格取 sub 個子樣本平均成 motion blur
#   - bitrate: 位元率 ( bps ), 預設為 mediabunny 依尺寸決定的 QUALITY_HIGH
#   - background: 底色, 預設取 el 的背景色; mp4 沒有透明, 未指定且透明時為黑
#   - progress: (p) -> 0..1 進度. signal: AbortSignal, 中止時 reject 一個 AbortError
encode = (opt = {}) ->
  if typeof(VideoEncoder) == \undefined
    return Promise.reject new Error('[lotion] WebCodecs ( VideoEncoder ) is not supported in this browser')
  even = (v) -> 2 * Math.round(v / 2)
  w = even(opt.width or 1920); h = even(opt.height or 1080)
  fps = opt.fps or 30
  sub = Math.max 1, Math.round(opt.sub or 1)
  d = (opt.shutter ? 0.5) / fps / sub
  from = opt.from or 0
  to = opt.to ? opt.duration
  n = Math.max 1, Math.round((to - from) * fps)
  bg = opt.background or getComputedStyle(opt.el).backgroundColor
  if !bg or bg == 'rgba(0, 0, 0, 0)' or bg == \transparent => bg = '#000'
  abort = -> if opt.signal and opt.signal.aborted => throw new DOMException('export aborted', \AbortError)
  output = null
  Promise.all [
    if opt.snapdom => Promise.resolve that else load-lib(\snapdom)
    if opt.mediabunny => Promise.resolve that else load-lib(\mediabunny)
  ]
    .then ([sd, mb]) ->
      snap = sd.snapdom or sd
      canvas = document.createElement \canvas
      canvas <<< {width: w, height: h}
      ctx = canvas.getContext \2d
      mb.getFirstEncodableVideoCodec(<[avc vp9 av1]>, {width: w, height: h})
        .then (codec) ->
          if !codec => throw new Error("[lotion] no encodable video codec for #{w}x#h")
          output := new mb.Output do
            format: new mb.Mp4OutputFormat fastStart: \in-memory
            target: new mb.BufferTarget!
          src = new mb.CanvasSource canvas, {codec, bitrate: opt.bitrate or mb.QUALITY_HIGH}
          output.addVideoTrack src, frameRate: fps
          output.start!then -> src
        .then (src) ->
          # 依序處理第 i 格的第 j 個子樣本; 子樣本以逐步平均疊在 canvas 上.
          # add() 呼叫時即複製 canvas, 所以不等它編碼完就截下一格, 下一次 add() 前再等 ( 背壓 )
          pending = Promise.resolve!
          step = (i, j) ->
            abort!
            if i >= n => return pending
            if j >= sub
              return pending.then ->
                abort!
                pending := src.add i / fps, 1 / fps
                if opt.progress => opt.progress (i + 1) / n
                step i + 1, 0
            t = clamp from + i / fps + (if sub > 1 => (j - (sub - 1) / 2) * d else 0), 0, opt.duration
            opt.seek t
            snap.toCanvas opt.el, {width: w, height: h, dpr: 1, backgroundColor: bg}
              .then (c) ->
                ctx.globalAlpha = 1 / (j + 1)
                ctx.drawImage c, 0, 0, w, h
                step i, j + 1
          step 0, 0
    .then -> output.finalize!
    .then -> new Blob [output.target.buffer], type: \video/mp4
    .catch (e) ->
      if output and output.state in <[started pending]> => output.cancel!
      throw e

lotion = {
  clamp, lerp, ss, spring, presets, track, vis, bump, typing
  hex, mixc, rgb, mk, put, txt, svg, player, encode, libs
}

if module? => module.exports = lotion
else if window? => window.lotion = lotion
