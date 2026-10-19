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

# ---------- 語系 ----------
# 作品支援的語言在載入時決定 ( 換語言 = 重新載入 ), 腳本依此挑選文字與素材.
# 決定順序: 網址 ?lang=xx > 指定的偏好 > langs[0]. 比對寬鬆: zh-TW / zh-Hant 對到 zh, en-US 對到 en.
# 狀態是頁面層級的: lotion.lang(langs) 決定一次後, lotion.t 與之後建立的 player 都用它.
lang-state = {lang: null, langs: []}
# 在 list 中找出 want 對應的項目: 完全相同 ( 不分大小寫 ) 優先, 其次比主標籤 ( zh-Hant -> zh, zh -> zh-TW ). 找不到為 null
match-lang = (want, list = []) ->
  if !want => return null
  w = "#want".toLowerCase!
  if (r = list.find (l) -> "#l".toLowerCase! == w)? => return r
  p = w.split(/[-_]/).0
  list.find((l) -> "#l".toLowerCase!split(/[-_]/).0 == p) ? null
url-lang = ->
  if typeof(location) == \undefined => return null
  m = /[?&]lang=([^&#]*)/.exec location.search
  if m => decodeURIComponent m.1 else null
# decide-lang ( lotion.lang ) (langs, prefer): 宣告作品支援的語言並決定目前語系, 回傳之. 不帶參數時回傳目前語系 ( 未宣告為 null )
# 模組內的 t / lang 常是區域變數名稱 ( LiveScript 的 = 會改到外層 ), 所以內部用別名, 匯出時才叫 lang / t
decide-lang = (langs, prefer) ->
  if langs? and langs.length
    lang-state.langs = langs.slice!
    lang-state.lang = match-lang(url-lang!, langs) ? match-lang(prefer, langs) ? langs.0
  lang-state.lang
# pick ( lotion.t ) ({zh: ..., en: ...}): 目前語系的值, 缺的時候退回預設語言 ( langs[0] ), 再缺則取第一個. 值不限字串.
# 不是物件 ( 字串、數字、陣列 ) 時原樣回傳. 未宣告語系時取網址 ?lang 對到的鍵, 否則第一個.
pick = (v) ->
  if !v or typeof(v) != \object or Array.isArray(v) => return v
  keys = Object.keys v
  {lang: cur, langs} = lang-state
  k = if cur? => (match-lang(cur, keys) ? match-lang(langs.0, keys)) else match-lang(url-lang!, keys)
  v[k ? keys.0]

# ---------- 互動 ----------
# at() 的「經過」: 相鄰兩次前進超過這個秒數視為跳轉 ( 外層逐格驅動時, 分頁在背景會一次跳很多 )
MAX_STEP = 1
clone-state = (s) -> if s => JSON.parse(JSON.stringify s) else {}
# 標記可互動元素: 點擊、拖動、長按交給作品, 不觸發播放器的播放 / 暫停
hit = (el) -> el.classList.add \lotion-hit; el

# ---------- 播放器 ----------
# 把 seek(t) 包成可播放 / 拖曳 / 全螢幕的元件, 並提供逐格輸出用的 render 協定.
#  opt:
#   - root: 容器元素或 selector. 播放器會在其中建立 stage 與控制列.
#   - width / height: 舞台的設計尺寸, 預設 1920 x 1080. 舞台會等比縮放以填入容器.
#   - duration: 總長 ( 秒 )
#   - seek: (t, state) -> 依 t 與狀態更新畫面. state 即 p.state ( 互動作品的狀態, 見 state )
#   - chapters: [[t, name, meta?], ...] 選用. 顯示於時間軸, 並供 ← / → 跳段. meta 為選填物件
#     ( 如 {description, thumb} ), 播放器不使用, 原樣放在 p.chapter 中供外層取用.
#   - captions: 字幕 [[t0, t1, text, meta?], ...] ( meta 如 {speaker} ), 或多語言 {zh: [...], en: [...]}.
#     也可用 lotion.vtt.parse 讀入 WebVTT. 讀者可自由開關 ( 控制列的 CC 鈕、c 鍵、p.showCaptions(on) ).
#   - captionsBurned: 畫面上已有旁白文字時設為 true: 字幕預設關閉 ( 讀者仍可打開 ). 未設定時預設開啟.
#   - captionLang: 初始語言, 預設為目前語系 ( 有宣告 langs 時 ), 否則第一個.
#   - langs: 作品支援的語言, 如 ['zh', 'en'], 第一個是預設. lang: 偏好的語言. 決定順序見 lotion.lang;
#     腳本先呼叫過 lotion.lang(langs) 時可省略. 結果存於 p.lang / p.langs. 未宣告時 p.lang 為 null, 行為不變.
#   - burnCaptions: ?render 模式 ( 逐格輸出 ) 是否畫上字幕, 預設 false. 網址帶 ?render&captions 亦可.
#   - doc: 作品的文稿 ( Markdown, 實驗性, 格式見 spec/document.md ), 或各語系一份 {zh: '…', en: '…'}.
#     未給時讀頁面中的 <script type="text/markdown" id="lotion-doc"> 與 class="lotion-doc" 的 script,
#     以其 lang 屬性為語系. p.docs 為全部 {lang: md} ( 無語系的鍵為 '' ), p.doc 為目前語系那份.
#   - cover: 標題畫面的時間 ( 秒 ). 還沒播放、或暫停在 0 秒時, 舞台顯示這一幅; 播放時間仍是 0 ( 時間軸顯示 0 ),
#     一播放就從 0 秒畫起. ?render 模式 ( 逐格輸出 ) 不使用.
#   - start: 初始時間 ( 從中間開始看 ). 網址的 ?t=秒數 優先. 要一打開就看到標題畫面請用 cover, 不要用 start.
#   - autoplay: 預設 false
#   - cues: 選用, -> [{t, name, ...}] 給 cli 匯出音效時間點
#   - loop: true 時整支循環: 播到結尾接回 0 ( 倒播到 0 接回結尾 ). 區段循環用 p.loop(a, b). ?render 不循環.
#   - interactive: 宣告作品有互動 ( 外層據此把點擊交給作品 ). 可互動的元素加上 class lotion-hit ( lotion.hit(el) ).
#   - state: 狀態的初始值 ( 可 JSON 序列化的物件 ), 也是逐格輸出用的值. 網址 ?state=<JSON> 會合併進去.
#     p.set(k, v) / p.set({...}) 改變狀態並以目前的 t 重畫, p.reset() 回到初始值.
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
    # 目前的章節 {index, t, name, meta} 與字幕 {t0, t1, text, meta}; 無則為 null
    chapter: null
    caption: null
    handlers: {}
    playing: false
    last: null
    started: false
    # 播放速率 ( 負數為倒播 ) 與 at() 登記的時間點
    speed: 1
    # 循環區段 [a, b], 由 loop(a, b) 設定
    span: null
    marks: []
    # 外層 ( 如書架 ) 掌握時鐘時設定 {play, pause, seek, rate}: 作品與控制列的播放要求改交給它
    host: null
    interactive: !!opt.interactive
  # 狀態: reset() 回到 opt.state; 網址 ?state=<JSON> 合併進目前狀態
  @state = clone-state opt.state
  if m = /[?&]state=([^&#]*)/.exec location.search
    try @state <<< JSON.parse(decodeURIComponent m.1)
    catch e => console.warn "[lotion] ?state is not valid JSON: #{e.message}"
  # 外層驅動用的方法: 不經 host, 直接改變播放器 ( 見 README > Host )
  @drive =
    play: (go = true) ~> @_play go
    pause: ~> @_play false
    seek: (t, o) ~> @_seek t, o
    rate: (r) ~> @_rate r
    loop: (v) ~> @_loop v
  # start() 時 resolve: 供外部 ( 如 block loader ) 等待內容就緒
  @ready = new Promise (res) ~> @ready-res = res
  @render-mode = /[?&]render\b/.test location.search
  # 字幕: 一律整理成 {lang: [[t0, t1, text, meta?], ...]}, 依開始時間排序
  c = opt.captions
  tracks = if !c => {} else if Array.isArray(c) => {'': c} else c
  @caption-tracks = {}
  for k, v of tracks => @caption-tracks[k] = v.slice!sort (a, b) -> a.0 - b.0
  # 語系: 選項有 langs 時在此決定; 否則沿用腳本先前以 lotion.lang(langs) 決定的. 都沒有時 lang 為 null
  @lang = if opt.langs and opt.langs.length => decide-lang(opt.langs, opt.lang) else lang-state.lang
  @langs = if @lang? => lang-state.langs.slice! else []
  @caption-langs = Object.keys @caption-tracks
  @caption-lang = if opt.captionLang in @caption-langs => opt.captionLang
  else (match-lang(@lang, @caption-langs) ? @caption-langs.0 ? null)
  @captions-on = if @render-mode => !!(opt.burnCaptions or /[?&]captions\b/.test location.search) else !opt.captionsBurned
  @init!
  @

player.prototype = Object.create(Object.prototype) <<<
  constructor: player

  init: ->
    r = @root
    r.classList.add \lotion
    if @interactive => r.classList.add \lotion-interactive
    # 宣告語系時標上 lang, 讓字型選擇、斷行與輔助工具依語言處理
    if @lang? => r.setAttribute \lang, @lang
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
      <div class="lotion-track"><div class="lotion-rail"></div><div class="lotion-fill"></div>
      <div class="lotion-chapters"></div><div class="lotion-knob"></div></div>
      <div class="lotion-btn lotion-play"></div>
      <div class="lotion-time"></div>
      <div class="lotion-chapter"></div>
      <div class="lotion-btn lotion-cc" title="字幕 ( c )">CC</div>
      <div class="lotion-btn lotion-fs" title="全螢幕"><svg width="16" height="16" viewBox="0 0 16 16" fill="none"
      stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M2 6V2h4M10 2h4v4M14 10v4h-4M6 14H2v-4"/></svg></div>
    ''', r
    q = (n) ~> @bar.querySelector ".lotion-#n"
    @el = {play: q(\play), fill: q(\fill), knob: q(\knob), time: q(\time), chapter: q(\chapter), track: q(\track), chapters: q(\chapters), fs: q(\fs), cc: q(\cc)}
    @chapters.map ([t, name, meta]) ~>
      e = mk \lotion-ch, '', @el.chapters
      e.title = name + (if meta and meta.description => "\n#{meta.description}" else '')
      e.style.left = "#{100 * t / @duration}%"
    # 字幕放在舞台之外 ( 不隨舞台縮放, 不進入線上匯出的截圖 ), 位於視窗底部的安全區
    @el.captions = mk \lotion-captions, '', @viewport
    if !@caption-langs.length => @el.cc.remove!
    @root.classList.toggle \lotion-captions-on, @captions-on
    @bind!
    if @render-mode => r.classList.add \lotion-render
    @fit!
    if typeof(ResizeObserver) != \undefined => new ResizeObserver(~> @fit!).observe @viewport
    else window.addEventListener \resize, ~> @fit!

  # 內容建好後呼叫: 移除載入畫面、顯示初始畫面, 並依設定自動播放
  start: ->
    @started = true
    # 文稿: 選項優先, 其次是頁面中的 #lotion-doc / .lotion-doc ( start 時才讀, 頁面已解析完 )
    @docs = @read-docs!
    keys = Object.keys @docs
    k = match-lang(@lang, keys) ? match-lang(@langs.0, keys) ? keys.0
    @doc = if k? => @docs[k] else null
    @root.classList.remove \lotion-loading
    if @loading => @loading.remove!
    if @render-mode
      window.seek = (t) ~> @opt.seek t, @state
      if @interactive or @opt.state => window.STATE = @state
      window.DURATION = @duration
      if @opt.cues => window.cues = @opt.cues
      # cli 依此輸出 .vtt
      if @caption-langs.length => window.CAPTIONS = @caption-tracks
      # cli 依此輸出文稿 ( lotion doc ); 沒有文稿時以章節與字幕起草
      if @doc => window.DOC = @doc
      if Object.keys(@docs).length > 1 => window.DOCS = @docs
      if @lang? => window.LANG = @lang; window.LANGS = @langs
      if @chapters.length => window.CHAPTERS = @chapters
    @ready-res @
    m = /[?&]t=([\d.]+)/.exec location.search
    @_seek(if m => +m.1 else if @render-mode => 0 else (@opt.start or 0))
    if @opt.autoplay and !@render-mode => document.fonts.ready.then ~> @play true
    @

  # 所有語系的文稿 {lang: md}; 沒有語系標示的那份鍵為 ''
  read-docs: ->
    d = @opt.doc
    if d and typeof(d) == \object => return {} <<< d
    if d => return {'': d}
    ret = {}
    for e in document.querySelectorAll('script#lotion-doc, script.lotion-doc')
      if (v = e.textContent?trim!) and !((k = e.getAttribute(\lang) or '') of ret) => ret[k] = v
    ret

  bind: ->
    @el.play.addEventListener \click, (e) ~> e.stopPropagation!; @toggle!
    @el.fs.addEventListener \click, (e) ~> e.stopPropagation!; @fullscreen!
    @el.cc.addEventListener \click, (e) ~> e.stopPropagation!; @show-captions !@captions-on
    # 點在可互動元素 ( .lotion-hit ) 上的交給作品, 不切換播放
    @viewport.addEventListener \click, (e) ~>
      @root.focus!
      if e.target.closest and e.target.closest('.lotion-hit') => return
      @toggle!
    dragging = false
    from-event = (e) ~>
      b = @el.track.getBoundingClientRect!
      @seek @duration * clamp((e.clientX - b.left) / b.width)
    drag = (v) ~> dragging := v; @root.classList.toggle \lotion-dragging, v
    @el.track.addEventListener \pointerdown, (e) ~>
      drag true
      @el.track.setPointerCapture e.pointerId
      from-event e
    @el.track.addEventListener \pointermove, (e) ~> if dragging => from-event e
    @el.track.addEventListener \pointerup, ~> drag false
    @el.track.addEventListener \pointercancel, ~> drag false
    # 鍵盤只在播放器取得焦點時作用, 以免干擾頁面捲動
    @root.addEventListener \keydown, (e) ~>
      starts = @chapters.map (c) -> c.0
      if e.code == \Space => e.preventDefault!; @toggle!
      else if e.key == \f => @fullscreen!
      else if e.key == \c and @caption-langs.length => @show-captions !@captions-on
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

  # 跳到 t. 設了 host 時改交給 host
  seek: (t) ->
    if @host => @host.seek t; return @
    @_seek t, {jump: true}
    @

  # start() 之前內容尚未就緒, encode() 期間畫面由匯出控制: 都不呼叫 opt.seek, 也不播放.
  # o.jump: 跳轉 ( 拖曳、程式跳時間 ), 不算「經過」at() 的時間點. 播放中逐格前進時不帶
  _seek: (t, o = {}) ->
    if !@started or @encoding => return
    prev = @t
    @t = t = clamp t, 0, @duration
    @opt.seek @frame-t(t), @state
    p = "#{100 * t / @duration}%"
    @el.fill.style.width = p
    @el.knob.style.left = p
    ci = -1
    for c, i in @chapters when c.0 <= t => ci = i
    ch = @chapters[ci]
    @el.time.textContent = "#{@fmt t} / #{@fmt @duration}"
    @el.chapter.textContent = @el.chapter.title = if ch => ch.1 else ''
    @root.classList.toggle \lotion-playing, @playing
    if (if ch => ci else -1) != (if @chapter => @chapter.index else -1)
      @chapter = if ch => {index: ci, t: ch.0, name: ch.1, meta: ch.2 or null} else null
      @fire \chapter, @chapter
    @update-caption!
    @fire \time, t
    if !o.jump => @pass prev, t

  # 播放經過的時間點: 播放中、方向與速率相同、一步不超過 MAX_STEP 秒, 才算連續經過 ( 見 README > Interaction )
  # 前進經過 T: prev < T <= t; 倒播: t <= T < prev. 沒有 host 的 ?render ( 逐格輸出 ) 不執行
  pass: (a, b) ->
    if !@playing or !@marks.length or a == b or (@render-mode and !@host) => return
    d = b - a
    if Math.abs(d) > MAX_STEP or (@speed != 0 and (d > 0) != (@speed > 0)) => return
    dir = if d > 0 => 1 else -1
    due = @marks.filter (m) -> if dir > 0 => a < m.t and m.t <= b else b <= m.t and m.t < a
    due.sort (x, y) -> dir * (x.t - y.t)
    # 前一個回呼可能取消了後面的時間點
    for m in due when m.fn in @marks.map((x) -> x.fn) => m.fn {t: m.t, dir}

  # 播放經過 t 時呼叫 fn({t, dir}). 回傳取消函式
  at: (t, fn) ->
    m = {t, fn}
    @marks.push m
    ~> @marks = @marks.filter (x) -> x != m

  # 以目前的 t 重畫 ( 狀態改變時 ), 暫停中也重畫
  redraw: -> if @started and !@encoding => @opt.seek @frame-t(@t), @state

  # 改變狀態: set(key, value) 或 set({...}), 合併後重畫, 送出 state 事件
  set: (k, v) ->
    if k and typeof(k) == \object => @state <<< k else @state[k] = v
    @redraw!
    @fire \state, @state
    @
  reset: ->
    @state = clone-state @opt.state
    @redraw!
    @fire \state, @state
    @

  # 自訂事件, 如 emit('quiz', {correct: true}). 也送出 emit 事件 {name, data} 供外層一併轉送
  emit: (name, data) ->
    @fire name, data
    @fire \emit, {name, data}
    @

  # 時間 t 時舞台要畫的那一幅: 停在 0 秒而且沒在播放時是標題畫面 ( opt.cover ), 其餘就是 t
  frame-t: (t) ->
    c = @opt.cover
    if c? and c > 0 and !@render-mode and !@playing and t < 0.001 => c else t

  # 目前時間的字幕 ( 同時有多段時以換行合併 ); 改變時更新畫面並送出 caption 事件
  update-caption: ->
    t = @t
    list = (@caption-lang? and @caption-tracks[@caption-lang]) or []
    act = list.filter (c) -> c.0 <= t and t < c.1
    cap = if !act.length => null else
      {t0: act.0.0, t1: act[* - 1].1, text: act.map((c) -> c.2).join('\n'), meta: act.0.3 or null, lang: @caption-lang}
    key = (c) -> if c => "#{c.lang}|#{c.t0}|#{c.text}" else ''
    if key(cap) == key(@caption) => return
    @caption = cap
    @el.captions.innerHTML = ''
    if cap => for line in cap.text.split('\n') => mk \lotion-caption, '', @el.captions .textContent = line
    @fire \caption, cap

  # 字幕開關 ( 讀者偏好 ). 狀態為 p.captionsOn; 送出 captions 事件 {on, lang}
  show-captions: (v = true) ->
    @captions-on = !!v
    @root.classList.toggle \lotion-captions-on, @captions-on
    @fire \captions, {on: @captions-on, lang: @caption-lang}
    @
  set-caption-lang: (lang) ->
    if !(lang in @caption-langs) => return @
    @caption-lang = lang
    @update-caption!
    @fire \captions, {on: @captions-on, lang}
    @

  # 事件: time ( t ), chapter ( p.chapter ), caption ( p.caption ), captions ( {on, lang} )
  'on': (name, cb) -> (@handlers[name] ?= []).push cb; @
  'off': (name, cb) ->
    if @handlers[name] => @handlers[name] = @handlers[name].filter (h) -> h != cb
    @
  fire: (name, v) -> for h in (@handlers[name] or []).slice! => h v

  # 播放器自己的時鐘 ( 沒有 host 時 ). 依速率前進, 正向到尾、倒播到 0 時停止 ( 循環時接回, 見 wrap )
  # 會越過循環的邊界時, 先連續前進到邊界 ( 觸發邊界上的 at ), 回呼沒有暫停才接回
  tick: (now, id) ->
    if !@playing or @host or id != @clock => return
    wrapped = false
    if @last?
      prev = @t
      nt = prev + @speed * (now - @last) / 1000
      e = @edge prev, nt
      @_seek (if e? => e else nt)
      if !@playing or id != @clock => return
      # 回呼可能剛設定了區段 ( 如 at(b) 裡呼叫 loop(a, b) ), 以目前的區段判斷是否接回
      if (w = @wrap prev, nt)? => @_seek w, {jump: true}; wrapped = true
    @last = now
    if !wrapped and ((@speed > 0 and @t >= @duration) or (@speed < 0 and @t <= 0)) => @_play false; return
    requestAnimationFrame (n) ~> @tick n, id

  # 目前的循環範圍: 區段 [a, b] 優先, 其次是整支循環 ( opt.loop ) [0, duration]; 沒有為 null
  loop-range: -> @span or (if @opt.loop and @duration > 0 => [0, @duration] else null)
  # 從 prev 前進到 nt 會越過的循環邊界 ( 正向 b, 倒播 a ); 不會越過為 null
  edge: (prev, nt) ->
    if !(r = @loop-range!) => return null
    [a, b] = r
    if nt > prev and prev <= b and nt >= b => b
    else if nt < prev and prev >= a and nt <= a => a
    else null
  # 越過邊界後接回的時間 ( 帶溢出量 ): 正向 a + 溢出, 倒播 b - 溢出; 不需接回為 null
  wrap: (prev, nt) ->
    if !(e = @edge prev, nt)? => return null
    [a, b] = @loop-range!
    len = b - a
    if nt > prev => a + (nt - b) % len else b - (a - nt) % len

  # 播放 / 暫停. 設了 host 時改交給 host
  play: (go = true) ->
    if @host => (if go => @host.play! else @host.pause!); return @
    @_play go
    @
  pause: -> @play false
  toggle: -> @play !@playing

  # 實際改變播放狀態. 有 host 時不啟動自己的時鐘 ( 由外層逐格 drive.seek ), 只標記播放中
  _play: (go = true) ->
    if !@started or @encoding => return
    go = !!go
    if go and @speed >= 0 and @t >= @duration => @_seek 0, {jump: true}
    if go and @speed < 0 and @t <= 0 => (if @loop-range! => @_seek @loop-range!.1, {jump: true} else go = false)
    was = @playing
    @playing = go
    @last = null
    @_seek @t, {jump: true}
    if go != was => @fire (if go => \play else \pause)
    if go and !was and !@host
      id = @clock = (@clock or 0) + 1
      requestAnimationFrame (n) ~> @tick n, id

  # 播放速率: 小數為慢 / 快動作, 負數為倒播. 不帶參數時回傳目前速率. 設了 host 時改交給 host
  rate: (r) ->
    if !arguments.length => return @speed
    if @host => @host.rate r; return @
    @_rate r
    @
  # 循環區段: loop(a, b) 或 loop([a, b]) 設定, loop(false) / loop(null) 取消, loop() 回傳 [a, b] 或 null.
  # 區段優先於整支循環 ( opt.loop ). 設了 host 時改交給 host ( host.loop([a, b] | null) )
  loop: (a, b) ->
    if !arguments.length => return (if @span => @span.slice! else null)
    v = if Array.isArray(a) => a else if a? and a != false => [a, b] else null
    if @host => @host.loop(if v => v.slice! else null); return @
    @_loop v
    @
  _loop: (v) ->
    v = if v and v.length == 2 => [clamp(+v.0, 0, @duration), clamp(+v.1, 0, @duration)] else null
    if v and !(v.0 < v.1) => v = null
    if "#{@span}" == "#{v}" => return
    @span = v
    @fire \loop, (if v => v.slice! else null)

  _rate: (r) ->
    r = +r
    if !isFinite(r) or r == @speed => return
    @speed = r
    @fire \rate, r

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
      @_seek t0, {jump: true}
    progress = (v) ->
      bar.textContent = "#{Math.round(v * 100)}%"
      if opt.progress => opt.progress v
    encode({el: @stage, seek: ((t) ~> @opt.seek t, @state), duration: @duration, width: @width, height: @height} <<< opt <<< {progress})
      .then (b) -> done!; b
      .catch (e) -> done!; throw e

# ---------- 線上匯出 ----------
# 在瀏覽器中逐格 seek(t), 以 snapdom 截圖, 以 WebCodecs ( 透過 mediabunny ) 編碼成 mp4.
# 兩個函式庫只在匯出時才以 dynamic import 載入; 網址可由 lotion.libs 覆寫 ( 例如改用自架的檔案 ),
# 或在 opt.snapdom / opt.mediabunny 直接傳入已載入的模組. lotion.lib(name) 依 lotion.libs 載入並快取,
# 其他選用模組 ( 如 vector.js ) 也以此載入自己的依賴.
libs =
  snapdom: 'https://cdn.jsdelivr.net/npm/@zumer/snapdom@3.3.0/dist/snapdom.mjs'
  mediabunny: 'https://cdn.jsdelivr.net/npm/mediabunny@1.61.3/dist/bundles/mediabunny.min.mjs'
lib-cache = {}
lib = (name) -> lib-cache[name] ?= ``import(libs[name])``

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
    if opt.snapdom => Promise.resolve that else lib(\snapdom)
    if opt.mediabunny => Promise.resolve that else lib(\mediabunny)
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

# ---------- WebVTT ----------
# 字幕格式與 WebVTT 互轉. captions: [[t0, t1, text, meta?], ...]; meta.speaker 對應 <v 名稱>
vtt-time = (t) ->
  ms = Math.round(t * 1000)
  h = Math.floor(ms / 3600000); m = Math.floor(ms / 60000) % 60; s = Math.floor(ms / 1000) % 60
  pad = (v, n = 2) -> "#v".padStart n, '0'
  "#{pad h}:#{pad m}:#{pad s}.#{pad ms % 1000, 3}"
vtt-parse-time = (s) ->
  p = s.trim!split ':'
  p.reduce ((a, v) -> a * 60 + parseFloat(v)), 0
vtt =
  parse: (text) ->
    ret = []
    blocks = text.replace(/\r\n?/g, '\n').split(/\n{2,}/)
    for b in blocks
      lines = b.split('\n').filter (l) -> l.trim!
      i = lines.findIndex (l) -> /-->/.test l
      if i < 0 => continue
      [a, z] = lines[i].split('-->')
      body = lines.slice(i + 1).join('\n')
      meta = null
      if m = /^<v(?:\.[^\s>]*)?\s+([^>]+)>/.exec body => meta = {speaker: m.1.trim!}
      body = body.replace(/<\/?[^>]+>/g, '').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&')
      cue = [vtt-parse-time(a), vtt-parse-time(z.trim!split(/\s+/).0), body]
      if meta => cue.push meta
      ret.push cue
    ret
  stringify: (captions) ->
    esc = (s) -> s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    cues = captions.map ([t0, t1, text, meta]) ->
      body = esc text
      if meta and meta.speaker => body = "<v #{esc meta.speaker}>#body"
      "#{vtt-time t0} --> #{vtt-time t1}\n#body"
    "WEBVTT\n\n" + cues.join('\n\n') + '\n'

# ---------- 文稿 ( 實驗性, spec/document.md ) ----------
# draft: 以章節與字幕起草一份文稿. opt: {title, lang, duration, chapters, captions}
#  captions 可為陣列或 {lang: [...]} ( 取 lang 或第一個語言 ). 每章一節 ( 標題帶 {t=a-b} ), 章內的字幕列為 say:
doc =
  draft: (opt = {}) ->
    c = opt.captions
    tracks = if !c => {} else if Array.isArray(c) => {'': c} else c
    lang = match-lang(opt.lang, Object.keys tracks) ? Object.keys(tracks).0
    caps = (if lang? => tracks[lang] else []).slice!sort (a, b) -> a.0 - b.0
    dur = opt.duration
    num = (v) -> +(+v).toFixed(2)
    q = (v) -> JSON.stringify "#v"
    fm = ['---', 'lotion: 1']
    if opt.title => fm.push "title: #{q opt.title}"
    if opt.lang or lang => fm.push "lang: #{opt.lang or lang}"
    if dur => fm.push 'kind: linear', "duration: #{num dur}"
    fm.push '---', ''
    chs = (opt.chapters or []).slice!sort (a, b) -> a.0 - b.0
    parts = if chs.length => chs.map (ch, i) -> {name: ch.1, t0: ch.0, t1: (chs[i + 1]?0 ? dur), meta: ch.2}
    else [{name: (opt.title or 'content'), t0: 0, t1: dur}]
    out = fm
    for p in parts
      range = if p.t1? => " {t=#{num p.t0}-#{num p.t1}}" else " {t=#{num p.t0}-}"
      out.push "## #{p.name}#range", ''
      if p.meta and p.meta.description => out.push p.meta.description, ''
      says = caps.filter (c) -> c.0 >= p.t0 and (!p.t1? or c.0 < p.t1)
      for c in says => out.push "- say: #{c.2.replace /\n/g, ' '}"
      if says.length => out.push ''
    out.join('\n')

lotion = {
  doc, vtt, lang: decide-lang, t: pick, hit, clamp, lerp, ss, spring, presets, track, vis, bump, typing
  hex, mixc, rgb, mk, put, txt, svg, player, encode, libs, lib
}

if module? => module.exports = lotion
else if window? => window.lotion = lotion
