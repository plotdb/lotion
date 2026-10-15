# lotion 互動示範: 畫面 = seek(t, state). 狀態: h ( 山高, 公尺 ), crossed ( 雲已拖過山 ), drag ( 拖動中的雲 x )
do ->
  {mk, put, txt, lerp, clamp, ss, vis, t: tr, hit} = lotion
  lotion.lang <[zh en]>
  p = new lotion.player do
    root: '#demo'
    duration: 12
    interactive: true
    state: {h: 2000, crossed: false, drag: null}
    chapters: [[0, tr({zh: '推雲', en: 'Push'})], [5, tr({zh: '下沉', en: 'Descend'})]]
    seek: (t, s) -> seek t, s
  st = p.stage
  sky = mk \ix-sky, '', st
  sky.style.background = 'linear-gradient(#cfe0ea, #ecf1ee)'
  mtn = mk \ix-mtn, '', st
  cloud = hit mk(\ix-cloud, '', st)
  ding = hit mk(\ix-btn, tr({zh: '叮', en: 'Ding'}), st)
  hint = mk \ix-hint, tr({zh: '把雲拖過山頂 →', en: 'Drag the cloud over the peak →'}), st
  temp = mk \ix-temp, '', st
  tip = mk \ix-tip, tr({zh: '山越高，空氣上升時降溫越多，凝結放熱也越多，下沉到山後就越熱。', en: 'The higher the mountain, the more heat the rising air releases as it condenses, so it lands warmer.'}), st
  ctl = mk \ix-ctl, '', st
  ctl.innerHTML = "<span>#{tr {zh: '山高', en: 'Height'}}</span><input type='range' min='1000' max='3000' step='100'>"
  slider = hit ctl.querySelector('input')
  rew = hit mk(\ix-btn, tr({zh: '倒轉', en: 'Rewind'}), ctl)
  slow = hit mk(\ix-btn, tr({zh: '慢動作', en: 'Slow'}), ctl)

  # 山: 底寬固定, 高度依狀態
  peak = (s) -> 980 - s.h * 0.25
  # 雲的 x: 5 秒前自己飄; 之後拖過山才往右下沉, 沒拖過就停在讀者拖到的位置
  cloud-x = (t, s) ->
    if t < 5 => lerp 160, 520, ss(t / 5)
    else if s.crossed => lerp 1040, 1560, ss((t - 5) / 6)
    else (s.drag ? 520)
  seek = (t, s) ->
    h = s.h * 0.25
    mtn.style.borderWidth = "0 420px #{h}px 420px"
    put mtn, 540, 980 - h
    x = cloud-x t, s
    y = if t >= 5 and s.crossed => lerp(peak(s) - 140, 760, ss((t - 5) / 6)) else peak(s) - 140
    put cloud, x, y
    put ding, 160, 140, 1, vis(t, 1, 4, 0.2, 0.2)
    put hint, 620, 160, 1, (if t >= 4.99 and !s.crossed => 1 else 0)
    put temp, 1440, 860, 1, vis(t, 7)
    txt temp, "#{(20 + s.h * 0.004).toFixed(1)} °C"
    put ctl, 1060, 50
    if slider.value != "#{s.h}" => slider.value = s.h
    txt slow, (if p.rate! == 0.5 => tr({zh: '正常速度', en: 'Normal'}) else tr({zh: '慢動作', en: 'Slow'}))

  # 播到 5 秒停下等讀者 ( 倒播經過不停 )
  p.at 5, ({dir}) -> if dir > 0 and !p.state.crossed => p.pause!

  # 叮: 只發聲, 不碰時間軸
  ac = null
  ding.addEventListener \click, ->
    ac ?:= new AudioContext!
    o = ac.createOscillator!; g = ac.createGain!
    o.frequency.value = 880; g.gain.setValueAtTime 0.3, ac.currentTime
    g.gain.exponentialRampToValueAtTime 0.001, ac.currentTime + 0.6
    o.connect(g).connect(ac.destination); o.start!; o.stop ac.currentTime + 0.6

  # 拖雲: 只在停在 5 秒、還沒拖過時有效. 拖過山頂 ( x > 1000 ) 就繼續播放
  drag = null
  to-stage = (e) -> (e.clientX - st.getBoundingClientRect!left) * p.width / st.getBoundingClientRect!width
  cloud.addEventListener \pointerdown, (e) ->
    if p.t < 4.99 or p.state.crossed => return
    cloud.setPointerCapture e.pointerId
    drag := {x0: to-stage(e), c0: cloud-x(p.t, p.state)}
  cloud.addEventListener \pointermove, (e) ->
    if !drag => return
    x = clamp drag.c0 + to-stage(e) - drag.x0, 160, 1100
    if x > 1000 => drag := null; p.set {crossed: true, drag: null}; p.play!
    else p.set \drag, x
  cloud.addEventListener \pointerup, -> drag := null

  slider.addEventListener \input, -> p.set \h, +slider.value
  rew.addEventListener \click, -> p.rate -Math.abs(p.rate!); p.play!
  slow.addEventListener \click, -> p.rate(if Math.abs(p.rate!) == 0.5 => 1 else 0.5)
  p.on \rate, -> p.redraw!
  # 正向播放時速率回到正數 ( 倒轉停在 0 之後 )
  p.on \pause, -> if p.t <= 0 and p.rate! < 0 => p.rate 1
  # 長按山顯示說明
  hit mtn
  press = null
  put tip, 1060, 300, 1, 0
  mtn.addEventListener \pointerdown, -> press := setTimeout (-> put tip, 1060, 300, 1, 1), 500
  for n in <[pointerup pointerleave pointercancel]> => mtn.addEventListener n, -> clearTimeout press; put tip, 1060, 300, 1, 0

  log = document.querySelector \.log
  for n in <[state rate play pause]> => let n = n
    p.on n, (v) -> if log => log.textContent = "#n #{if n == \state => JSON.stringify(v) else (v ? '')}"
  document.fonts.ready.then -> p.start!
