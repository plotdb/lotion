# 向量轉換對照: 左邊是播放器 ( DOM ), 右邊是同一格以 lotion.vector 轉出的 svg.
# 畫面時間改變 ( 拖曳、跳段、播放 ) 就重新轉換; 轉換中又改變時, 等這次完成再轉最新的一格.
#  - p: lotion.player
#  - root: 放 svg 與資訊的容器, 內含 .v-img / .v-stat / .v-warn / .v-dl / .v-open / .v-auto
viewer = (p, root) ->
  q = (n) -> root.querySelector ".v-#n"
  img = q \img
  last = null
  busy = false
  url = null
  svg = null
  run = ->
    busy := true
    t = p.t
    last := t
    t0 = performance.now!
    lotion.vector p.stage
      .then (r) ->
        ms = performance.now! - t0
        svg := r.svg
        if url => URL.revokeObjectURL url
        url := URL.createObjectURL new Blob([svg], type: 'image/svg+xml')
        img.src = url
        q(\stat).textContent = "t = #{t.toFixed(2)}s · #{Math.round ms} ms · #{(svg.length / 1024).toFixed(0)} KB"
        q(\warn).innerHTML = if r.warnings.length
          r.warnings.map(-> "<li>#{it.replace(/</g, '&lt;')}</li>").join('')
        else '<li class="ok">無警告</li>'
      .catch (e) ->
        q(\stat).textContent = "轉換失敗：#{e.message}"
        console.error e
      .then -> busy := false
  tick = ->
    if p.started and !busy and q(\auto).checked and p.t != last => run!
    requestAnimationFrame tick
  p.ready.then -> run!; tick!
  q(\dl).addEventListener \click, ->
    if !url => return
    a = document.createElement \a
    a <<< {href: url, download: "lotion-#{last.toFixed(2)}s.svg"}
    a.click!
  q(\open).addEventListener \click, -> if url => window.open url

# 動畫 svg: 把整段動畫轉成一個 svg ( lotion.animate ), 以 <img> 播放.
#  - root 內含 .a-go / .a-fps / .a-img / .a-stat / .a-warn / .a-dl / .a-open
anim-viewer = (p, root) ->
  q = (n) -> root.querySelector ".a-#n"
  url = null
  q(\go).addEventListener \click, ->
    q(\go).disabled = true
    q(\stat).textContent = '轉換中…'
    p.animate do
      fps: +q(\fps).value
      progress: (v) -> q(\stat).textContent = "轉換中… #{Math.round v * 100}%"
    .then ({svg, warnings, stats}) ->
      if url => URL.revokeObjectURL url
      url := URL.createObjectURL new Blob([svg], type: 'image/svg+xml')
      q(\img).src = url
      v = stats.variants
      q(\stat).textContent = "#{stats.frames} 格 · #{stats.elements} 個元素 · 變體 #{v.html} ( html ) + #{v.svg} ( svg ) · " +
        "#{(stats.total-ms / 1000).toFixed(1)} 秒 · #{(stats.bytes / 1024).toFixed(0)} KB"
      q(\warn).innerHTML = if warnings.length
        warnings.map(-> "<li>#{it.replace(/</g, '&lt;')}</li>").join('')
      else '<li class="ok">無警告</li>'
    .catch (e) ->
      q(\stat).textContent = "轉換失敗：#{e.message}"
      console.error e
    .then -> q(\go).disabled = false
  q(\dl).addEventListener \click, ->
    if !url => return
    a = document.createElement \a
    a <<< {href: url, download: 'lotion-animated.svg'}
    a.click!
  q(\open).addEventListener \click, -> if url => window.open url
