# lotion vector ( 實驗性 ): 把目前的畫面 ( DOM ) 轉成向量 SVG; lotion.animate 則轉成一個動畫 SVG.
#  - 版面直接取瀏覽器的結果 ( offsetLeft / offsetWidth ... ), 每個元素轉成絕對定位的 satori 節點,
#    樣式取 computed style; 由 satori 畫成 SVG, 文字轉成 path.
#  - 字型自動收集: 依畫面用到的字型、粗細與字元, 從頁面的 @font-face 找出需要的檔案載入.
#    satori 不吃 woff2, 遇到 woff2 以 woff2-encoder 解壓; 再以 HarfBuzz 取子集並固定可變字型的粗細.
#  - satori / woff2-encoder / harfbuzz-subset 都按需載入, 網址在 lotion.libs.
#  - 不支援或可能失真的地方收集在回傳的 warnings.
#  需先載入 lotion ( index.js ).
do ->
  lotion = window.lotion
  lotion.libs <<<
    satori: 'https://cdn.jsdelivr.net/npm/satori@0.36.0/+esm'
    woff2: 'https://cdn.jsdelivr.net/npm/woff2-encoder@2.0.0/dist/decompress.js'
    # 非 ES module, 是 wasm 檔本身
    hbsubset: 'https://cdn.jsdelivr.net/npm/harfbuzzjs@1.6.3/dist/harfbuzz-subset.wasm'

  # ---------- 樣式 ----------
  # 直接帶過去的 computed style ( 值為瀏覽器解析後的字串 ). 與預設值相同者略過, 讓樹小一點.
  props = <[
    color fontFamily fontSize fontWeight fontStyle lineHeight letterSpacing textAlign whiteSpace wordBreak
    textTransform textShadow textIndent
    backgroundColor backgroundImage backgroundPosition backgroundSize backgroundRepeat backgroundClip
    borderTopWidth borderRightWidth borderBottomWidth borderLeftWidth
    borderTopStyle borderRightStyle borderBottomStyle borderLeftStyle
    borderTopColor borderRightColor borderBottomColor borderLeftColor
    borderTopLeftRadius borderTopRightRadius borderBottomRightRadius borderBottomLeftRadius
    paddingTop paddingRight paddingBottom paddingLeft
    boxShadow opacity filter clipPath overflow zIndex transform transformOrigin
    maskImage maskPosition maskSize maskRepeat
  ]>
  skip =
    textShadow: \none, textIndent: '0px', textTransform: \none
    backgroundColor: 'rgba(0, 0, 0, 0)', backgroundImage: \none
    backgroundPosition: '0% 0%', backgroundSize: \auto, backgroundRepeat: \repeat, backgroundClip: \border-box
    boxShadow: \none, opacity: '1', filter: \none, clipPath: \none, overflow: \visible, zIndex: \auto
    transform: \none, maskImage: \none, maskPosition: '0% 0%', maskSize: \auto, maskRepeat: \repeat
    lineHeight: \normal, letterSpacing: \normal
  for s in <[Top Right Bottom Left]>
    skip["border#{s}Width"] = '0px'
    skip["border#{s}Style"] = \none
    skip["padding#{s}"] = '0px'
  for c in <[TopLeft TopRight BottomRight BottomLeft]> => skip["border#{c}Radius"] = '0px'
  # 文字以外不需要的屬性: 只有含文字的元素才帶字型相關屬性
  text-props = <[color fontFamily fontSize fontWeight fontStyle lineHeight letterSpacing textAlign whiteSpace
    wordBreak textTransform textShadow textIndent]>

  # 已知 satori 不支援, 遇到非預設值就記在 warnings
  unsupported =
    backdropFilter: \none
    textDecorationLine: \none

  # ---------- DOM -> satori 節點 ----------
  # satori 以 btoa 處理 svg 圖片, 非 latin1 字元 ( 如中文 ) 會失敗: 一律轉成 utf-8 的 base64
  b64-bytes = (buf) ->
    bytes = new Uint8Array buf
    bin = ''
    for i from 0 til bytes.length by 0x8000 => bin += String.fromCharCode.apply null, bytes.subarray(i, i + 0x8000)
    btoa bin
  b64 = (str) -> b64-bytes new TextEncoder!encode(str)
  svg-uri = (xml) -> "data:image/svg+xml;base64,#{b64 xml}"
  # css 值中的 url("data:image/svg+xml;utf8,...") 也轉成 base64
  fix-uri = (v) ->
    v.replace /url\("data:image\/svg\+xml(?:;charset=[^,;]+)?(?:;utf8)?,([^"]*)"\)/g, (m, d) ->
      "url(\"#{svg-uri(try decodeURIComponent d catch => d)}\")"

  # el 相對於 DOM 父元素的位置與尺寸 ( 未經 transform 的版面座標 ): [x, y, w, h]
  #  svg 等非 html 元素沒有 offset*: 尺寸取 computed width / height, 位置只認絕對定位的 left / top
  box = (el, parent, cs, ctx) ->
    if el.offsetWidth?
      x = el.offsetLeft; y = el.offsetTop
      if el.offsetParent != parent and parent.offsetParent == el.offsetParent
        x -= parent.offsetLeft + parent.clientLeft; y -= parent.offsetTop + parent.clientTop
      return [x, y, el.offsetWidth, el.offsetHeight]
    [w, h] = [parseFloat(cs.width) or 0, parseFloat(cs.height) or 0]
    if cs.position in <[absolute fixed]> => return [parseFloat(cs.left) or 0, parseFloat(cs.top) or 0, w, h]
    ctx.warn "<#{el.tagName.toLowerCase!}> not absolutely positioned: placed at its parent's origin"
    [0, 0, w, h]

  # inline svg 轉成 svg 圖片. 圖片中讀不到頁面的 css 與網頁字型, 所以:
  #  - 在複本上寫入 computed style ( 只寫與父元素不同的值 )
  #  - 複製引用到的外部定義 ( 如另一個 svg 的 <defs> 中的 filter )
  #  - 文字所需字型取子集後以 data uri 嵌入; 字型要等全部收集完才產生, 所以 src 在 finish 時才填上
  svg-props = <[font-family font-size font-weight font-style letter-spacing text-anchor dominant-baseline
    fill fill-opacity fill-rule stroke stroke-width stroke-opacity stroke-dasharray stroke-dashoffset
    stroke-linecap stroke-linejoin paint-order opacity visibility display filter mask clip-path color]>
  svg-src = (el, w, h, ctx, node) ->
    c = el.cloneNode true
    # satori 由 svg 的 width / height / viewBox 取得尺寸, 缺少時會失敗
    c.setAttribute \width, w
    c.setAttribute \height, h
    if !c.getAttribute(\viewBox) => c.setAttribute \viewBox, "0 0 #w #h"
    c.removeAttribute \style
    srcs = [el] ++ Array.from(el.querySelectorAll '*')
    dsts = [c] ++ Array.from(c.querySelectorAll '*')
    texts = []
    srcs.map (e, i) ->
      d = dsts[i]
      cs = getComputedStyle e
      pcs = if i == 0 => null else getComputedStyle e.parentNode
      decl = []
      for k in svg-props
        v = cs.getPropertyValue k
        if pcs and pcs.getPropertyValue(k) == v => continue
        if i == 0 and k in <[opacity visibility display filter mask clip-path]> => continue
        decl.push "#k:#v"
      if decl.length => d.setAttribute \style, decl.join(';')
      if e.tagName.toLowerCase! in <[text tspan textpath]> and !e.querySelector('tspan, textPath')
        f = {}
        ctx.text cs, e.textContent, f
        texts.push [d, f]
    # 引用到但不在此 svg 中的 id
    ids = new Set
    for d in dsts
      for a in Array.from(d.attributes)
        re = /url\(\s*['"]?#([^'")\s]+)['"]?\s*\)|^#(.+)$/g
        while m = re.exec a.value => ids.add(m.1 or m.2)
    defs = null
    ids.forEach (id) ->
      if c.querySelector "[id=\"#{CSS.escape id}\"]" => return
      if !(src = document.getElementById id) => return
      if !defs => defs := document.createElementNS 'http://www.w3.org/2000/svg', \defs; c.insertBefore defs, c.firstChild
      defs.appendChild src.cloneNode(true)
    ctx.later (fonts) ->
      names = new Set
      for [d, f] in texts
        if !f.fontFamily => continue
        st = d.getAttribute(\style) or ''
        d.setAttribute \style, "#st;font-family:#{f.fontFamily}"
        for n in f.fontFamily.split(',') => names.add n.trim!replace(/'/g, '')
      faces = fonts.filter(-> names.has it.name).map (f) ->
        "@font-face{font-family:'#{f.name}';font-weight:#{f.weight};font-style:#{f.style};" +
        "src:url(data:font/ttf;base64,#{b64-bytes f.data}) format('truetype')}"
      if faces.length
        st = document.createElementNS 'http://www.w3.org/2000/svg', \style
        st.textContent = faces.join ''
        c.insertBefore st, c.firstChild
      node.props.src = svg-uri new XMLSerializer!serializeToString(c)
    # 暫時的 src: 字型就緒前先以內容表示, 讓動畫取樣能區分不同內容的 svg ( 見 sample )
    "pending:#{new XMLSerializer!serializeToString c}"

  # satori 的 mask / clip-path 畫在未轉換的座標, 不隨元素 ( 或祖先 ) 的 transform 移動.
  # 只有平移時 ( lotion.put 未縮放的情形 ) 把平移併入 left / top; 其他情形記為警告
  bake-transform = (node, ctx) ->
    st = node.props.style
    if !(st.maskImage or st.clipPath) => return node
    if !st.transform => return node
    m = /^matrix\(([^)]+)\)$/.exec st.transform
    v = if m => m.1.split(',').map(-> +it) else null
    if v and v.0 == 1 and v.1 == 0 and v.2 == 0 and v.3 == 1
      st.left += v.4; st.top += v.5
      delete st.transform; delete st.transformOrigin
    else ctx.warn "mask / clip-path with a non-translation transform: misplaced"
    node

  # depth: 0 為根元素.
  #  o.own: 只轉元素本身 ( 含其文字 ), 不含子元素; o.nobake: 不把 transform 併入位置 ( 動畫中另外處理 transform )
  convert = (el, ctx, depth = 0, o = {}) ->
    root = depth == 0
    cs = getComputedStyle el
    if cs.display == \none or +cs.opacity == 0 => return null
    tag = el.tagName.toLowerCase!
    [x, y, w, h] = box el, el.parentNode, cs, ctx
    hidden = cs.visibility != \visible
    for k, v of unsupported => if cs[k] and cs[k] != v => ctx.warn "#k: #{cs[k]}"
    # mix-blend-mode: satori 不支援, 根元素的直接子元素在組合時以分層處理 ( 見 render )
    blend = if cs.mixBlendMode != \normal => cs.mixBlendMode else null
    if blend and depth != 1 => ctx.warn "mixBlendMode on a nested element: #blend ignored"
    kids = Array.from el.childNodes
    texts = kids.filter (n) -> n.nodeType == 3 and n.textContent.trim!
    elems = kids.filter (n) -> n.nodeType == 1
    if texts.length and elems.length => ctx.warn "mixed text and elements in <#tag>"
    style = {display: \flex, boxSizing: \border-box, width: w, height: h}
    if !root
      style <<< {position: \absolute, left: x, top: y}
    for k in props
      if !texts.length and k in text-props => continue
      v = cs[k]
      if !v or skip[k] == v => continue
      style[k] = if /data:image\/svg/.test(v) => fix-uri(v) else v
    for s in <[Top Right Bottom Left]> => if !style["border#{s}Width"] => delete style["border#{s}Color"]
    # satori 的 overflow 只有 visible / hidden
    if style.overflow => style.overflow = \hidden
    if style.transform => style.transformOrigin = cs.transformOrigin
    else delete style.transformOrigin
    if hidden
      # visibility: hidden 的元素不畫自己, 但子元素可能是 visible
      for k in <[backgroundColor backgroundImage boxShadow color textShadow]> => delete style[k]
      for s in <[Top Right Bottom Left]> => delete style["border#{s}Width"]
    # 圖片類元素轉成 satori 的 img; 隱藏時不畫 ( visibility 會繼承, 已含父層的 hidden )
    if tag in <[img canvas svg]>
      if hidden => return null
      node = {blend: (if depth == 1 => blend else null), type: \img, props: {width: w, height: h, style}}
      node.props.src = switch tag
      | \img => el.currentSrc or el.src
      | \canvas => el.toDataURL!
      | \svg => svg-src el, w, h, ctx, node
      return if o.nobake => node else bake-transform node, ctx
    children = []
    if texts.length and !hidden
      text = texts.map(-> it.textContent).join ''
      ctx.text cs, text, style
      children.push text
      # satori 的文字盒子縮到內容寬度, 單行時 textAlign 沒有作用; 以 justifyContent 對齊
      jc = {center: \center, right: \flex-end, end: \flex-end}[cs.textAlign]
      if jc and !elems.length => style.justifyContent = jc
    if !o.own => for c in elems => if convert(c, ctx, depth + 1) => children.push that
    node = {type: \div, props: {style, children}}
    if blend and depth == 1 => node.blend = blend
    if o.nobake => node else bake-transform node, ctx

  # ---------- 字型 ----------
  font-cache = {}
  unquote = (s) -> s.trim!replace /^["']|["']$/g, ''
  # unicode-range: "U+0000-00FF, U+4E00-9FFF, U+30??" -> [[a, b], ...]
  parse-range = (s) ->
    if !s => return [[0, 0x10FFFF]]
    s.split(',').map (r) ->
      r = r.trim!replace /^u\+/i, ''
      if /\?/.test r => return [parseInt(r.replace(/\?/g, '0'), 16), parseInt(r.replace(/\?/g, 'F'), 16)]
      [a, b] = r.split '-'
      [parseInt(a, 16), parseInt(b or a, 16)]
  # src: url("a.woff2") format("woff2"), url(b.woff) format("woff") -> [{url, format}]
  parse-src = (s, base) ->
    ret = []
    re = /url\(\s*(['"]?)([^'")]+)\1\s*\)\s*(?:format\(\s*['"]?([^'")]+)['"]?\s*\))?/g
    while m = re.exec s
      try ret.push {url: new URL(m.2, base).href, format: (m.3 or m.2.split('.').pop!).toLowerCase!}
    ret
  face-of = (get, base) ->
    family: unquote(get(\font-family))
    weight: (get(\font-weight) or '400').split(/\s+/).map(-> if it == \normal => 400 else if it == \bold => 700 else +it)
    style: get(\font-style) or \normal
    range: parse-range get(\unicode-range)
    src: parse-src get(\src), base
  # 讀不到 cssRules ( 跨來源 ) 的 stylesheet 改用 fetch 取文字解析
  faces-in-text = (text, base) ->
    (text.match(/@font-face\s*\{[^}]*\}/g) or []).map (b) ->
      face-of ((k) -> (new RegExp("(?:^|[{;\\s])#k\\s*:\\s*([^;}]+)").exec(b) or [])[1]), base
  faces-in-sheet = (sheet) ->
    base = sheet.href or location.href
    try rules = sheet.cssRules catch => rules = null
    if !rules
      return if sheet.href => fetch(sheet.href).then((r) -> r.text!).then((t) -> faces-in-text t, base).catch(-> [])
      else Promise.resolve []
    Promise.all Array.from(rules).map (r) ->
      if r.styleSheet => return faces-in-sheet r.styleSheet
      if r.type == 5 => return [face-of ((k) -> r.style.getPropertyValue k), base]
      []
    .then (l) -> l.flat!
  all-faces = null
  get-faces = -> all-faces ?= Promise.all(Array.from(document.styleSheets).map faces-in-sheet).then (l) -> l.flat!

  # 取得字型檔 ( sfnt ). woff2 先解壓
  load-font = (src) ->
    pick = src.find(-> it.format in <[truetype opentype woff ttf otf]>) or src.find(-> it.format == \woff2)
    if !pick => return Promise.resolve null
    font-cache[pick.url] ?= fetch(pick.url).then((r) -> r.arrayBuffer!).then (buf) ->
      if pick.format != \woff2 => return buf
      lotion.lib(\woff2)
        .then (m) -> decompress = m.decompress or m.default; decompress buf
        .then (u8) -> u8.buffer.slice u8.byteOffset, u8.byteOffset + u8.byteLength

  # 以 HarfBuzz ( hb-subset ) 只留下用到的字元; 可變字型同時把 wght 軸固定在 weight.
  # 網頁字型常是可變字型 ( 如 Google Fonts 對各粗細給同一個檔 ), satori 只畫得出預設粗細, 必須先固定.
  # 子集也讓 CJK 字型從數 MB 降到數 KB, satori 解析快得多.
  hb = null
  get-hb = ->
    hb ?= fetch(lotion.libs.hbsubset)
      .then (r) -> r.arrayBuffer!
      .then (b) -> WebAssembly.instantiate b, {}
      .then ({instance}) -> e = instance.exports; (if e._initialize => e._initialize!); e
  WGHT = 0x77676874
  subset = (buf, weight, cps) ->
    get-hb!then (e) ->
      n = buf.byteLength
      p = e.malloc n
      new Uint8Array(e.memory.buffer).set new Uint8Array(buf), p
      blob = e.hb_blob_create p, n, 1, 0, 0
      face = e.hb_face_create blob, 0
      e.hb_blob_destroy blob
      input = e.hb_subset_input_create_or_fail!
      us = e.hb_subset_input_unicode_set input
      for c in cps => e.hb_set_add us, c
      # 不是可變字型時沒有 wght 軸, 呼叫會失敗但無害
      e.hb_subset_input_pin_axis_location input, face, WGHT, weight
      sub = e.hb_subset_or_fail face, input
      e.hb_subset_input_destroy input
      ret = null
      if sub
        rb = e.hb_face_reference_blob sub
        d = e.hb_blob_get_data rb, 0
        ret = new Uint8Array(e.memory.buffer).slice(d, d + e.hb_blob_get_length rb).buffer
        e.hb_blob_destroy rb
        e.hb_face_destroy sub
      e.hb_face_destroy face
      e.free p
      ret

  clamp = (v, a, b) -> Math.min b, Math.max(a, v)
  # 依 css 字型比對規則為 face 的粗細排序 ( 小者優先 ): 範圍涵蓋需求者最優先;
  # 需求 > 500 先往重找, < 400 先往輕找, 400 ~ 500 先找到 500 為止的較重者, 再往輕, 最後才往重
  weight-rank = (f, w) ->
    [a, b] = [f.weight.0, f.weight.1 or f.weight.0]
    if w >= a and w <= b => return 0
    if w > 500 => return if a > w => a - w else 1000 + w - b
    if w < 400 => return if b < w => w - b else 1000 + a - w
    if a > w and a <= 500 => a - w
    else if b < w => 1000 + w - b
    else 2000 + a - w

  # used: {key: {families: [...], weight, style, chars: Set}}
  # 每個字元沿 font-family 順序, 找第一個 unicode-range 涵蓋它的 @font-face; 同一個檔案 / 粗細的字元合併成一份子集.
  # 網頁字型常依 unicode-range 切成多個檔 ( 如 CJK ), 都同名同粗細, 但 satori 同名只認一個:
  # 所以每份子集取唯一的名字, 記在 u.names, 之後把文字節點的 fontFamily 改成這些名字.
  fonts-for = (used, ctx) ->
    get-faces!then (faces) ->
      groups = {}
      missing = 0
      n-group = 0
      for key, u of used
        u.names = []
        for c in Array.from(u.chars)
          cp = c.codePointAt 0
          if cp < 33 => continue
          f = null
          for fam in u.families
            cand = faces.filter (f) ->
              f.family == fam and f.src.length and f.range.some((r) -> cp >= r.0 and cp <= r.1)
            if !cand.length => continue
            same = cand.filter (f) -> f.style == u.style
            if same.length => cand = same
            f = cand.reduce (a, b) -> if weight-rank(b, u.weight) < weight-rank(a, u.weight) => b else a
            break
          if !f => missing++; continue
          # 可變字型固定的粗細: 瀏覽器只在 face 宣告的範圍內變化, 超出就夾在範圍邊緣
          pin = clamp u.weight, f.weight.0, (f.weight.1 or f.weight.0)
          gk = "#{f.src.0.url}|#{u.weight}|#{u.style}"
          g = groups[gk] ?= {name: "lotion-font-#{n-group++}", face: f, weight: u.weight, pin, style: u.style, cps: new Set([32])}
          g.cps.add cp
          if !(g.name in u.names) => u.names.push g.name
      if missing => ctx.warn "#missing characters have no web font ( system fonts are not available to satori )"
      Promise.all [v for k, v of groups].map (g) ->
        load-font(g.face.src).then (buf) ->
          if !buf => return null
          subset(buf, g.pin, Array.from(g.cps)).then (data) ->
            if !data => ctx.warn "font #{g.face.family}: subset failed"; return null
            {name: g.name, data, weight: g.weight, style: g.style}
      .then (l) -> l.filter -> it

  # ---------- 組合 ----------
  # 根元素的直接子元素有 mix-blend-mode 時, 依序切成數層各自轉換, 再以 svg 的 mix-blend-mode 疊起來
  # ( 瀏覽器支援; 其他 svg 檢視器可能不支援 ). 第一層只有根元素本身的背景.
  render = (satori, tree, o) ->
    kids = tree.props.children
    if !kids.some(-> it.blend) => return satori tree, o
    segs = [{kids: []}]
    for k in kids
      if k.blend => segs.push {blend: k.blend, kids: [k]}
      else if segs[* - 1].blend => segs.push {kids: [k]}
      else segs[* - 1].kids.push k
    bare = {display: \flex, width: o.width, height: o.height, overflow: \hidden}
    Promise.all segs.map (g, i) ->
      satori {type: \div, props: {style: (if i == 0 => tree.props.style else bare), children: g.kids}}, o
        .then (svg) ->
          # 各層的 clip / mask id 都從同一組名字開始, 加上層號避免衝突
          inner = svg.replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '').replace /satori_/g, "satori_#{i}_"
          if g.blend => "<g style=\"mix-blend-mode:#{g.blend}\">#inner</g>" else "<g>#inner</g>"
    .then (layers) ->
      "<svg width=\"#{o.width}\" height=\"#{o.height}\" viewBox=\"0 0 #{o.width} #{o.height}\" xmlns=\"http://www.w3.org/2000/svg\">#{layers.join ''}</svg>"

  # ---------- 主函式 ----------
  # 把 el 目前的畫面轉成 SVG. 回傳 Promise<{svg, warnings}>.
  #  opt:
  #   - width / height: 輸出尺寸, 預設 el 的版面尺寸 ( 不受 el 本身的 transform 影響 )
  #   - fonts: 自行指定 satori 字型 [{name, data, weight, style}], 不自動收集
  #   - satori: 直接傳入已載入的 satori 模組
  # 轉換時共用的狀態: 警告、用到的字型與字元、字型就緒後才能完成的工作 ( 如 svg 圖片 )
  make-ctx = ->
    ctx =
      warns: {}
      used: {}
      laters: []
      warn: (m) -> ctx.warns[m] = (ctx.warns[m] or 0) + 1
      later: (f) -> ctx.laters.push f
      text: (cs, text, style) ->
        weight = +cs.fontWeight or 400
        key = "#{cs.fontFamily}|#weight|#{cs.fontStyle}"
        u = ctx.used[key] ?= {families: cs.fontFamily.split(',').map(unquote), weight, style: cs.fontStyle, chars: new Set, styles: []}
        for c in Array.from(text) => u.chars.add c
        u.styles.push style
      warnings: -> [k + (if v > 1 => " ( x#v )" else '') for k, v of ctx.warns]
  # 載入 satori 與字型, 字型就緒後把文字節點的 fontFamily 改成子集的名字. 回傳 [satori, fonts]
  prepare = (ctx, opt) ->
    Promise.all [
      if opt.satori => Promise.resolve that else lotion.lib(\satori)
      if opt.fonts => Promise.resolve that else fonts-for ctx.used, ctx
    ]
      .then ([m, fonts]) ->
        if !opt.fonts => for k, u of ctx.used => for s in u.styles => s.fontFamily = u.names.map(-> "'#it'").join(', ')
        [m.default or m.satori or m, fonts]

  vector = (el, opt = {}) ->
    ctx = make-ctx!
    tree = convert el, ctx
    w = opt.width or el.offsetWidth; h = opt.height or el.offsetHeight
    # 根元素輸出原尺寸: 去掉它本身的 transform ( 如播放器為了填入容器的縮放 )
    tree.props.style <<< {width: w, height: h, overflow: \hidden}
    delete tree.props.style.transform
    delete tree.props.style.transformOrigin
    prepare ctx, opt
      .then ([satori, fonts]) ->
        for f in ctx.laters => f fonts
        render satori, tree, {width: w, height: h, fonts}
      .then (svg) -> {svg, warnings: ctx.warnings!}

  # ---------- 動畫 ----------
  # 把一段動畫轉成一個動畫 svg ( css @keyframes ). 每個元素對應一個 <g>, 巢狀與 dom 相同:
  #  - 運動: 位置與 transform 合成的矩陣、opacity、blur 濾鏡; 逐格取樣後刪去可由線性內插還原的點
  #  - 外觀: 其餘樣式、文字、尺寸. 每一種外觀只以 satori 畫一次 ( 一個變體 ), 以 visibility 切換
  #  有 mask / clip-path / 其他濾鏡的元素, 以及 img / canvas / svg, 連同子元素整個當作一個外觀,
  #  因為這些效果作用在整個子樹上.
  IDENT = [1, 0, 0, 1, 0, 0]
  mul = (m, n) -> [
    m.0 * n.0 + m.2 * n.1, m.1 * n.0 + m.3 * n.1
    m.0 * n.2 + m.2 * n.3, m.1 * n.2 + m.3 * n.3
    m.0 * n.4 + m.2 * n.5 + m.4, m.1 * n.4 + m.3 * n.5 + m.5
  ]
  # css transform ( computed, matrix 或 matrix3d ) -> 2d 矩陣
  parse-matrix = (v, ctx) ->
    if !v or v == \none => return IDENT
    if m = /^matrix\(([^)]+)\)$/.exec v => return m.1.split(',').map(-> +it)
    if m = /^matrix3d\(([^)]+)\)$/.exec v
      a = m.1.split(',').map(-> +it)
      ctx.warn "3d transform flattened to 2d"
      return [a.0, a.1, a.4, a.5, a.12, a.13]
    IDENT
  # 元素在父元素座標中的矩陣: translate(x, y) · translate(origin) · M · translate(-origin)
  motion-matrix = (x, y, cs, ctx) ->
    m = parse-matrix cs.transform, ctx
    if m == IDENT => return [1, 0, 0, 1, x, y]
    [ox, oy] = cs.transformOrigin.split(' ').map(-> parseFloat(it) or 0)
    mul [1, 0, 0, 1, x + ox, y + oy], mul(m, [1, 0, 0, 1, -ox, -oy])
  # svg 元素: css transform 優先, 否則取 transform 屬性 ( computed style 不反映屬性 )
  svg-matrix = (e, cs, ctx) ->
    if cs.transform != \none => return motion-matrix 0, 0, cs, ctx
    l = e.transform and e.transform.baseVal
    if !(l and l.numberOfItems) => return IDENT
    m = l.consolidate!matrix
    [m.a, m.b, m.c, m.d, m.e, m.f]
  # inline svg 的 viewBox -> 盒子座標的矩陣 ( 依 preserveAspectRatio )
  viewbox-matrix = (e, w, h) ->
    vb = e.viewBox and e.viewBox.baseVal
    if !(vb and vb.width and vb.height) => return IDENT
    [sx, sy] = [w / vb.width, h / vb.height]
    par = e.preserveAspectRatio.baseVal
    if par.align == 1 => return [sx, 0, 0, sy, -vb.x * sx, -vb.y * sy]
    s = if par.meetOrSlice == 2 => Math.max(sx, sy) else Math.min(sx, sy)
    # align: 2..10 = xMinYMin, xMidYMin, xMaxYMin, xMinYMid, ...
    ax = (par.align - 2) % 3; ay = Math.floor((par.align - 2) / 3)
    dx = (w - vb.width * s) * ax / 2; dy = (h - vb.height * s) * ay / 2
    [s, 0, 0, s, dx - vb.x * s, dy - vb.y * s]
  # lotion.put 的模糊是 filter: blur(); 只有單一 blur 時當作運動, 否則是外觀
  blur-of = (f) -> if !f or f == \none => 0 else if m = /^blur\(([\d.]+)px\)$/.exec(f) => +m.1 else null

  # Ramer–Douglas–Peucker: 保留必要的取樣點, 使線性內插與取樣值的差在 tol 之內 ( 各分量分別比較 )
  simplify = (vals, tol) ->
    n = vals.length
    if n < 3 => return [0 til n]
    keep = new Uint8Array n
    keep[0] = keep[n - 1] = 1
    stack = [[0, n - 1]]
    while stack.length
      [a, b] = stack.pop!
      [worst, at] = [1, -1]
      for i from a + 1 til b
        f = (i - a) / (b - a)
        for k from 0 til vals[a].length
          e = Math.abs(vals[a][k] + (vals[b][k] - vals[a][k]) * f - vals[i][k]) / tol[k]
          if e > worst => worst = e; at = i
      if at >= 0 => keep[at] = 1; stack.push [a, at], [at, b]
    [i for i from 0 til n when keep[i]]

  fmt = (v) -> +v.toFixed(4)
  pct = (i, n) -> "#{+(100 * i / n).toFixed(4)}%"

  # inline svg 不當成一張圖, 而是走進它的 dom: <g> 等容器成為動畫群組; 葉節點 ( path / text ... ) 各自有外觀變體,
  # 逐格變化的數值屬性寫成 smil <animate>; <defs> 等定義只輸出一次.
  SVG-GROUP = <[g a switch]>
  SVG-STATIC = <[defs clippath mask lineargradient radialgradient filter pattern symbol style marker title desc metadata]>
  NUM-ATTRS = <[x y x1 y1 x2 y2 cx cy r rx ry width height]>
  NUM-PROPS = <[stroke-dashoffset stroke-width fill-opacity stroke-opacity]>
  LEAF-STYLE = svg-props.filter -> !(it in NUM-PROPS) and !(it in <[opacity visibility display]>)
  NUMERIC = /^\s*-?(\d+\.?\d*|\.\d+)(e-?\d+)?\s*$/
  xml = (e) -> new XMLSerializer!serializeToString e
  # 與父元素不同的 computed style ( 頁面的 css 規則在輸出中不存在, 改寫成行內樣式 )
  style-diff = (e, cs) ->
    pcs = getComputedStyle e.parentNode
    decl = []
    for k in LEAF-STYLE
      v = cs.getPropertyValue k
      if pcs.getPropertyValue(k) != v => decl.push "#k:#v"
    decl.join ';'
  # 葉節點的外觀: 去掉 transform / opacity ( 由外層 <g> 處理 ) 與數值屬性 ( 寫成軌道 ) 的複本
  leaf = (e, cs, ctx) ->
    c = e.cloneNode true
    for k in <[transform opacity style class]> => c.removeAttribute k
    a = {}
    for k in NUM-ATTRS
      v = e.getAttribute k
      if v? and NUMERIC.test(v) => a[k] = +v; c.removeAttribute k
    for k in NUM-PROPS => a[k] = parseFloat(cs.getPropertyValue k) or 0; c.removeAttribute k
    if d = style-diff e, cs => c.setAttribute \style, d
    f = null
    if e.tagName.toLowerCase! == \text => f = {}; ctx.text cs, e.textContent, f
    {c, a, f}
  # 容器的屬性: 去掉由動畫處理的部分, 加上行內樣式
  group-attrs = (e, cs) ->
    ret = for at in Array.from(e.attributes) when !(at.name in <[class style transform opacity]>)
      "#{at.name}=\"#{at.value.replace(/"/g, '&quot;')}\""
    if d = style-diff e, cs => ret.push "style=\"#{d.replace(/"/g, "'")}\""
    ret.join ' '

  # 逐格取樣. 回傳 recs; rec: {id, el, parent, kids, kind, variants, frames, ...}
  #  kind: html ( 預設, 外觀以 satori 畫 ) / svg ( inline svg 本身 ) / g ( svg 容器 ) / leaf ( svg 葉節點 ) / static
  #  frames[i]: {m, o, b, v, a} ( 矩陣、opacity、blur、外觀變體 ( -1 為不畫 )、數值屬性 ), 不存在的格為 null
  sample = (opt, ctx) ->
    {el, seek, n, fps, from} = opt
    recs = []
    by-el = new Map
    rec-of = (e, parent) ->
      if rec = by-el.get e => return rec
      rec = {id: recs.length, el: e, parent, kids: [], variants: [], keys: new Map, frames: []}
      recs.push rec
      by-el.set e, rec
      if parent => parent.kids.push rec
      rec
    variant = (rec, sig, make) ->
      v = rec.keys.get sig
      if !v? => v = rec.variants.length; rec.keys.set sig, v; rec.variants.push make!
      v
    walk-svg = (e, parent, i) ->
      cs = getComputedStyle e
      if cs.display == \none => return
      tag = e.tagName.toLowerCase!
      rec = rec-of e, parent
      if tag in SVG-STATIC
        if !rec.kind => rec <<< {kind: \static, markup: xml(e)}
        else if xml(e) != rec.markup => ctx.warn "<#tag> changes over time: only the first frame is kept"
        rec.frames[i] = {m: IDENT, o: 1, b: 0, v: -1}
        return
      m = svg-matrix e, cs, ctx
      o = +cs.opacity
      if cs.mixBlendMode != \normal => rec.blend = cs.mixBlendMode
      if tag in SVG-GROUP
        if !rec.kind => rec <<< {kind: \g, attrs: group-attrs(e, cs)}
        rec.frames[i] = {m, o, b: 0, v: -1}
        for c in Array.from(e.children) => walk-svg c, rec, i
        return
      rec.kind = \leaf
      v = -1
      a = null
      if cs.visibility == \visible and o > 0
        r = leaf e, cs, ctx
        a = r.a
        v = variant rec, xml(r.c), -> {c: r.c, f: r.f}
      rec.frames[i] = {m, o, b: 0, v, a}
    walk = (e, parent, i, depth) ->
      cs = getComputedStyle e
      if cs.display == \none => return
      tag = e.tagName.toLowerCase!
      rec = rec-of e, parent
      [x, y, w, h] = box e, e.parentNode, cs, ctx
      m = if depth == 0 => IDENT else motion-matrix x, y, cs, ctx
      rec.blend = if cs.mixBlendMode != \normal => cs.mixBlendMode else null
      if cs.zIndex != \auto => ctx.warn "z-index ignored ( dom order is used )"
      masked = cs.maskImage != \none or cs.clipPath != \none
      if tag == \svg and !masked
        # 不輸出巢狀 <svg> ( 其中的 smil 不隨外層 svg 暫停 / 跳轉 ): viewBox 換成矩陣, overflow 換成 clipPath
        if !rec.kind
          rec <<< {kind: \svg, vb: viewbox-matrix(e, w, h), clip: (if cs.overflow == \visible => null else [w, h]), style: style-diff(e, cs)}
        rec.frames[i] = {m, o: +cs.opacity, b: 0, v: -1}
        if +cs.opacity > 0 => for c in Array.from(e.children) => walk-svg c, rec, i
        return
      blur = blur-of cs.filter
      elems = Array.from(e.children)
      has-text = Array.from(e.childNodes).some (n) -> n.nodeType == 3 and n.textContent.trim!
      atomic = tag in <[img canvas svg]> or masked or !(blur?) or (has-text and elems.length)
      rec.atomic = atomic
      if cs.overflow != \visible and !atomic and elems.length => rec.clip ?= [w, h]
      v = -1
      if cs.visibility == \visible and +cs.opacity > 0
        ctx.laters = []
        node = convert e, ctx, 1, {own: !atomic, nobake: true}
        if node
          st = node.props.style
          for k in <[position left top transform transformOrigin opacity]> => delete st[k]
          if blur? => delete st.filter
          delete node.blend
          # 外觀相同就共用同一個變體 ( svg 圖片在字型就緒前以內容暫代 src, 仍可區分 )
          laters = ctx.laters
          v = variant rec, JSON.stringify(node), -> {node, w, h, laters}
      rec.frames[i] = {m, o: +cs.opacity, b: blur or 0, v}
      if !atomic and +cs.opacity > 0 => for c in elems => walk c, rec, i, depth + 1
    for i from 0 til n
      if opt.signal and opt.signal.aborted => throw new DOMException('aborted', \AbortError)
      seek from + i / fps
      walk el, null, i, 0
      if opt.progress => opt.progress 0.5 * (i + 1) / n
    recs

  # 以 satori 畫一個變體. 四周留白以容納陰影等超出盒子的效果, 再平移回來
  PAD = 64
  draw = (satori, fonts, rec, k, va) ->
    W = va.w + 2 * PAD; H = va.h + 2 * PAD
    va.node.props.style <<< {position: \absolute, left: PAD, top: PAD}
    satori {type: \div, props: {style: {display: \flex, width: W, height: H}, children: [va.node]}}, {width: W, height: H, fonts}
      .then (svg) ->
        inner = svg.replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '').replace /satori_/g, "s#{rec.id}_#{k}_"
        "<g transform=\"translate(#{-PAD},#{-PAD})\">#inner</g>"

  # 數值軌道的容許誤差
  attr-tol = (k) -> if /opacity/.test(k) => 0.004 else 0.05

  # 組成 svg: 每個 rec 一個 <g class="n{id}">, 依 rec.kids 巢狀; 運動與變體切換寫成 css, svg 數值屬性寫成 smil
  compose = (recs, opt, fonts) ->
    {n, fps, width, height} = opt
    dur = n / fps
    css = []
    font-names = new Set
    tail = if opt.repeat => ' infinite' else ' forwards'
    # 每格的值 ( null 表示該格不存在, 沿用前一格 ); 全部相同時回傳 null
    series = (frames) ->
      last = frames.find(-> it?)
      vals = frames.map (f) -> last := f ? last
      if vals.every((v) -> v.every((x, j) -> x == vals.0[j])) => [vals, false] else [vals, true]
    rule = (cls, base, frames, prop, tol, val, step) ->
      [vals, varies] = series frames
      if !varies => base.push "#prop:#{val vals.0}"; return
      idx = if step => [i for i from 0 til n when i == 0 or vals[i].join! != vals[i - 1].join!] else simplify vals, tol
      kf = idx.map((i) -> "#{pct i, n}{#prop:#{val vals[i]}}").join('') + "100%{#prop:#{val vals[n - 1]}}"
      name = "#{cls}-#{prop.replace(/[^a-z]/g, '')}"
      css.push "@keyframes #name{#kf}"
      base.push "#prop:#{val vals.0}"
      return name
    # 葉節點的數值屬性: 不變的直接寫入, 會變的加上 <animate>
    attrs-of = (rec) ->
      F = rec.frames
      keys = new Set
      for f in F when f and f.a => for k of f.a => keys.add k
      ret = []
      keys.forEach (k) ->
        [vals, varies] = series [0 til n].map (i) -> if F[i] and F[i].a and F[i].a[k]? => [F[i].a[k]] else null
        if !varies => return ret.push [k, fmt vals.0.0]
        idx = simplify vals, [attr-tol k]
        times = idx.map (i) -> i / n
        vs = idx.map (i) -> fmt vals[i].0
        if times[* - 1] < 1 => times.push 1; vs.push fmt(vals[n - 1].0)
        ret.push [k, fmt(vals.0.0), {times, vs}]
      ret
    leaf-markup = (rec, va) ->
      c = va.c
      for [k, v, anim] in rec.tracks
        c.setAttribute k, v
        if anim
          a = document.createElementNS 'http://www.w3.org/2000/svg', \animate
          a.setAttribute \attributeName, k
          a.setAttribute \dur, "#{dur}s"
          a.setAttribute \calcMode, \linear
          a.setAttribute \keyTimes, anim.times.map(-> +it.toFixed 5).join(';')
          a.setAttribute \values, anim.vs.join(';')
          if opt.repeat => a.setAttribute \repeatCount, \indefinite else a.setAttribute \fill, \freeze
          c.appendChild a
      if va.f and va.f.fontFamily
        c.setAttribute \style, "#{c.getAttribute(\style) or ''};font-family:#{va.f.fontFamily}"
        for f in va.f.fontFamily.split(',') => font-names.add f.trim!replace(/'/g, '')
      xml c
    out = (rec) ->
      if rec.kind == \static => return rec.markup
      cls = "n#{rec.id}"
      base = []
      anims = []
      F = rec.frames
      at = (f) -> [0 til n].map (i) -> if F[i] => f F[i] else null
      if name = rule(cls, base, at((f) -> f.m), \transform, [0.005, 0.005, 0.005, 0.005, 0.25, 0.25],
        ((v) -> "matrix(#{v.map(fmt).join(',')})"), false) => anims.push "#name #{dur}s linear"
      # 不存在的格視為透明
      opa = [0 til n].map (i) -> [if F[i] => F[i].o else 0]
      if name = rule(cls, base, opa, \opacity, [0.004], ((v) -> fmt v.0), false) => anims.push "#name #{dur}s linear"
      if name = rule(cls, base, at((f) -> [f.b]), \filter, [0.05], ((v) -> if v.0 > 0.01 => "blur(#{fmt v.0}px)" else \none), false)
        anims.push "#name #{dur}s linear"
      if rec.blend => base.push "mix-blend-mode:#{rec.blend}"
      if anims.length => base.push "animation:#{anims.map(-> it + tail).join(',')}"
      css.push ".#cls{#{base.join(';')}}"
      if rec.kind == \leaf => rec.tracks = attrs-of rec
      # 外觀變體: 只在用到它的格顯示
      vs = rec.variants.map (va, k) ->
        vcls = "#{cls}v#k"
        vb = []
        shown = [0 til n].map (i) -> [if F[i] and F[i].v == k => 1 else 0]
        if name = rule(vcls, vb, shown, \visibility, [0.5], ((v) -> if v.0 => \visible else \hidden), true)
          vb.push "animation:#name #{dur}s step-end#tail"
        css.push ".#vcls{#{vb.join(';')}}"
        "<g class=\"#vcls\">#{if rec.kind == \leaf => leaf-markup(rec, va) else va.svg}</g>"
      kids = rec.kids.map(out).join('')
      if rec.kind == \svg
        inner = "<g transform=\"matrix(#{rec.vb.map(fmt).join(',')})\" style=\"#{rec.style.replace(/"/g, "'")}\">#kids</g>"
        if rec.clip
          inner = "<clipPath id=\"c#{rec.id}\"><rect width=\"#{rec.clip.0}\" height=\"#{rec.clip.1}\"/></clipPath><g clip-path=\"url(#c#{rec.id})\">#inner</g>"
        return "<g class=\"#cls\">#inner</g>"
      if rec.kind == \g => return "<g class=\"#cls\" #{rec.attrs}>#kids</g>"
      if rec.clip and kids
        kids = "<clipPath id=\"c#{rec.id}\"><rect width=\"#{rec.clip.0}\" height=\"#{rec.clip.1}\"/></clipPath><g clip-path=\"url(#c#{rec.id})\">#kids</g>"
      "<g class=\"#cls\">#{vs.join('')}#kids</g>"
    body = out recs.0
    # svg 中的文字 ( 未經 satori ) 需要的字型, 以 data uri 嵌入一次
    faces = fonts.filter(-> font-names.has it.name).map (f) ->
      "@font-face{font-family:'#{f.name}';font-weight:#{f.weight};font-style:#{f.style};" +
      "src:url(data:font/ttf;base64,#{b64-bytes f.data}) format('truetype')}"
    style = "#{faces.join('')}g{transform-box:view-box;transform-origin:0 0}#{css.join('')}"
    "<svg width=\"#width\" height=\"#height\" viewBox=\"0 0 #width #height\" xmlns=\"http://www.w3.org/2000/svg\"><style>#style</style>#body</svg>"

  # 把動畫轉成一個動畫 svg. 回傳 Promise<{svg, warnings, stats}>.
  #  opt:
  #   - el / seek / duration: 同 lotion.encode. fps: 取樣率, 預設 30. from / to: 只轉一段
  #   - loop: 預設 true. width / height: 預設 el 的版面尺寸
  #   - fonts / satori: 同 lotion.vector. progress: (p) -> 0..1. signal: AbortSignal
  animate = (opt = {}) ->
    ctx = make-ctx!
    fps = opt.fps or 30
    from = opt.from or 0
    to = opt.to ? opt.duration
    n = Math.max 1, Math.round((to - from) * fps)
    el = opt.el
    o = {el, seek: opt.seek, n, fps, from, signal: opt.signal, progress: opt.progress}
    t0 = performance.now!
    recs = sample o, ctx
    t1 = performance.now!
    fonts = null
    prepare ctx, opt
      .then ([satori, f]) ->
        fonts := f
        jobs = []
        for rec in recs when !rec.kind => for va, k in rec.variants => jobs.push [rec, k, va]
        # 依序畫, 讓進度可見
        step = (i) ->
          if i >= jobs.length => return
          [rec, k, va] = jobs[i]
          for f in va.laters => f fonts
          draw(satori, fonts, rec, k, va).then (svg) ->
            va.svg = svg
            if opt.progress => opt.progress 0.5 + 0.5 * (i + 1) / jobs.length
            step i + 1
        step 0
      .then ->
        svg = compose recs, {n, fps, repeat: opt.loop ? true, width: opt.width or el.offsetWidth, height: opt.height or el.offsetHeight}, fonts
        count = (k) -> recs.filter((r) -> (r.kind or \html) == k).reduce(((a, r) -> a + r.variants.length), 0)
        stats =
          frames: n, elements: recs.length
          variants: {html: count(\html), svg: count(\leaf)}
          sample-ms: Math.round(t1 - t0), total-ms: Math.round(performance.now! - t0), bytes: svg.length
        {svg, warnings: ctx.warnings!, stats}

  lotion.animate = animate
  # 播放器: 轉換整段 ( 或 from / to ) 動畫. 期間暫停, 結束後回到原本的時間.
  lotion.player.prototype.animate = (opt = {}) ->
    @pause!
    t0 = @t
    p = Promise.resolve!then ~> animate({el: @stage, seek: @opt.seek, duration: @duration, width: @width, height: @height} <<< opt)
    p.finally ~> @opt.seek t0

  lotion.vector = vector
  # 播放器: 轉換時間 t ( 預設目前時間 ) 的畫面. 只呼叫 opt.seek, 不更新控制列; 轉完回到目前時間.
  lotion.player.prototype.vector = (t, opt = {}) ->
    if t? => @opt.seek t
    vector @stage, opt
      .then (r) ~> (if t? => @opt.seek @t); r
