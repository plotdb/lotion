# 以延遲模擬非同步準備 ( 字型載入、量測版面 ), 讓載入畫面看得見.
# 網址參數 ?loading=毫秒 可調整, 0 為不延遲.
m = /[?&]loading=(\d+)/.exec location.search
delay = if m => +m.1 else 1500
ready = new Promise (res) -> setTimeout res, delay
scene window.lotion, document.querySelector('#demo'), ready
