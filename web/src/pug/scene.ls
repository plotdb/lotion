# lotion demo 場景: 三段小動畫, 全部由 seek(t) 決定. 一般頁面與 block 版共用.
#  - lotion: runtime ( 頁面上為全域的 lotion, block 中為 ctx.lotion )
#  - root: 播放器的容器元素
#  - ready: 選用的 promise. 實際頁面常需非同步準備 ( 字型、依版面量測 ), 完成前播放器顯示載入畫面
#  回傳 lotion.player
scene = (lotion, root, ready) ->
  {track, vis, bump, put, mk, txt, typing} = lotion
  T = {spring: 0, liquid: 5.5, text: 11, end: 17}

  p = new lotion.player do
    root: root
    duration: T.end
    chapters: [[T.spring, '彈簧'] [T.liquid, '液態指示器'] [T.text, '文字進出場']]
    seek: (t) -> seek t
  stage = p.stage
  el = (cls, html) -> mk "d-a #cls", html, stage

  # 旁白
  captions = [
    [T.spring, '同一個目標，不同的阻尼比']
    [T.liquid, '前緣用快的彈簧、後緣用慢的：移動時自然拉長']
    [T.text, '內容切換：舊的先模糊淡出，新的再淡入']
  ]
  cap-els = captions.map (c) -> el \d-caption, c.1

  # 1. 彈簧: 同樣的關鍵點, 三種阻尼比
  rows = [
    {z: 1, label: 'z = 1'}
    {z: 0.8, label: 'z = 0.8'}
    {z: 0.45, label: 'z = 0.45'}
  ].map (r, i) ->
    r <<<
      y: 380 + i * 170
      line: el \d-line
      label: el \d-label, r.label
      dot: el \d-dot
      x: track [[0 560] [T.spring + 1, 1460] [T.spring + 3, 560]], {w: 12, z: r.z}

  # 2. 液態指示器: 向右移時右緣快、左緣慢; 向左時相反
  TAB = {x: 520, y: 520, w: 220}
  names = <[概覽 活動 成員 設定]>
  tabs-bg = el \d-tabs
  ind = el \d-ind
  tab-els = names.map (n) -> el \d-tab, n
  stops = [[T.liquid, 0] [T.liquid + 1.2, 2] [T.liquid + 2.4, 3] [T.liquid + 3.6, 1]]
  edge-keys = (side) ->
    keys = [[0, stops.0.1]]
    for i from 1 til stops.length
      [t, dst] = stops[i]
      right = dst > stops[i - 1].1
      lead = (side == \r and right) or (side == \l and !right)
      keys.push [t, dst, if lead => {w: 20, z: 0.85} else {w: 9, z: 0.9}]
    track keys
  edge = {l: edge-keys(\l), r: edge-keys(\r)}

  # 3. 文字進出場與打字
  words = [[T.text + 0.6, 'seek(t)'] [T.text + 2.4, '純函數'] [T.text + 4.2, '逐格輸出']]
  word-els = words.map (w) -> el \d-type

  seek = (t) ->
    for c, i in captions
      o = vis t, c.0 + 0.2, (captions[i + 1] or [T.end]).0 - 0.4, 0.4, 0.3
      put cap-els[i], 0, 120 + 12 * (1 - o), 1, o, {blur: (1 - o) * 6}

    o1 = vis t, T.spring + 0.2, T.liquid - 0.4
    for r in rows
      put r.line, 560, r.y, 1, o1
      put r.label, 280, r.y - 20, 1, o1
      put r.dot, r.x(t), r.y, 1 + 0.12 * bump(t, T.spring + 1, 0.3), o1

    o2 = vis t, T.liquid + 0.2, T.text - 0.4
    put tabs-bg, TAB.x, TAB.y, 1, o2
    l = TAB.x + 10 + edge.l(t) * TAB.w
    w = (edge.r(t) - edge.l(t)) * TAB.w + TAB.w - 20
    ind.style.width = "#{w.toFixed(2)}px"
    put ind, l, TAB.y + 10, 1, o2
    # 文字顏色依「是否被指示器蓋住」決定, 指示器拉長經過時也讀得到
    for e, i in tab-els
      cx = TAB.x + (i + 0.5) * TAB.w
      e.style.color = if cx > l and cx < l + w => '#fff' else '#18181A'
      put e, TAB.x + i * TAB.w, TAB.y, 1, o2

    for w, i in words
      t1 = (words[i + 1] or [T.end - 0.4]).0 - 0.3
      o = vis t, w.0, t1, 0.35, 0.25
      txt word-els[i], typing(t, w.0, w.1, 0.07)
      # 離場時往上, 進場時由下而上
      dy = if t > t1 => -16 * (1 - o) else 16 * (1 - o)
      put word-els[i], 0, 480 + dy, 1, o * vis(t, T.text, T.end - 0.4), {blur: (1 - o) * 8}

  Promise.resolve(ready).then -> p.start!
  p
