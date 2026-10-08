# lotion vector ( 驗證中 ): 把目前的畫面 ( DOM ) 轉成向量 SVG.
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

  # el 相對於 DOM 父元素的位置 ( 未經 transform 的版面座標 )
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
    ''

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

  # depth: 0 為根元素
  convert = (el, ctx, depth = 0) ->
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
      return bake-transform node, ctx
    children = []
    if texts.length and !hidden
      text = texts.map(-> it.textContent).join ''
      ctx.text cs, text, style
      children.push text
      # satori 的文字盒子縮到內容寬度, 單行時 textAlign 沒有作用; 以 justifyContent 對齊
      jc = {center: \center, right: \flex-end, end: \flex-end}[cs.textAlign]
      if jc and !elems.length => style.justifyContent = jc
    for c in elems => if convert(c, ctx, depth + 1) => children.push that
    node = {type: \div, props: {style, children}}
    if blend and depth == 1 => node.blend = blend
    bake-transform node, ctx

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
  vector = (el, opt = {}) ->
    warns = {}
    used = {}
    laters = []
    ctx =
      warn: (m) -> warns[m] = (warns[m] or 0) + 1
      # 字型就緒後才能完成的工作 ( 如 svg 圖片 )
      later: (f) -> laters.push f
      text: (cs, text, style) ->
        weight = +cs.fontWeight or 400
        key = "#{cs.fontFamily}|#weight|#{cs.fontStyle}"
        u = used[key] ?= {families: cs.fontFamily.split(',').map(unquote), weight, style: cs.fontStyle, chars: new Set, styles: []}
        for c in Array.from(text) => u.chars.add c
        u.styles.push style
    tree = convert el, ctx
    w = opt.width or el.offsetWidth; h = opt.height or el.offsetHeight
    # 根元素輸出原尺寸: 去掉它本身的 transform ( 如播放器為了填入容器的縮放 )
    tree.props.style <<< {width: w, height: h, overflow: \hidden}
    delete tree.props.style.transform
    delete tree.props.style.transformOrigin
    Promise.all [
      if opt.satori => Promise.resolve that else lotion.lib(\satori)
      if opt.fonts => Promise.resolve that else fonts-for used, ctx
    ]
      .then ([m, fonts]) ->
        if !opt.fonts => for k, u of used => for s in u.styles => s.fontFamily = u.names.map(-> "'#it'").join(', ')
        for f in laters => f fonts
        satori = m.default or m.satori or m
        render satori, tree, {width: w, height: h, fonts}
      .then (svg) -> {svg, warnings: [k + (if v > 1 => " ( x#v )" else '') for k, v of warns]}

  lotion.vector = vector
  # 播放器: 轉換時間 t ( 預設目前時間 ) 的畫面. 只呼叫 opt.seek, 不更新控制列; 轉完回到目前時間.
  lotion.player.prototype.vector = (t, opt = {}) ->
    if t? => @opt.seek t
    vector @stage, opt
      .then (r) ~> (if t? => @opt.seek @t); r
