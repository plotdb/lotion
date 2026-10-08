# 以延遲模擬非同步準備 ( 字型載入、量測版面 ), 讓載入畫面看得見.
# 網址參數 ?loading=毫秒 可調整, 0 為不延遲.
m = /[?&]loading=(\d+)/.exec location.search
delay = if m => +m.1 else 1500
ready = new Promise (res) -> setTimeout res, delay
p = scene window.lotion, document.querySelector('#demo'), ready

# 線上匯出: demo 改用 fedep 複製到本站的函式庫, 不經 cdn
lotion.libs <<<
  snapdom: '/assets/lib/@zumer/snapdom/main/dist/snapdom.mjs'
  mediabunny: '/assets/lib/mediabunny/main/dist/bundles/mediabunny.min.mjs'
q = (n) -> document.querySelector ".export-#n"
ctrl = null
q(\go).addEventListener \click, ->
  s = +q(\size).value
  ctrl := new AbortController!
  q(\go).hidden = true; q(\stop).hidden = false
  t0 = performance.now!
  p.encode do
    fps: +q(\fps).value
    width: 1920 * s, height: 1080 * s
    signal: ctrl.signal
    progress: (v) -> q(\msg).textContent = "#{Math.round(v * 100)}%"
  .then (blob) ->
    sec = ((performance.now! - t0) / 1000).toFixed(1)
    q(\msg).textContent = "完成：#{(blob.size / 1e6).toFixed(1)} MB，#{sec} 秒"
    a = document.createElement \a
    a <<< {href: URL.createObjectURL(blob), download: 'lotion.mp4'}
    a.click!
  .catch (e) -> q(\msg).textContent = if e.name == \AbortError => '已取消' else "失敗：#{e.message}"
  .then -> q(\go).hidden = false; q(\stop).hidden = true
q(\stop).addEventListener \click, -> if ctrl => ctrl.abort!
