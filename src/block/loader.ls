# block player loader: 掛載頁面上的 [data-block] 元素. 與 @plotdb/block 及其依賴一起打包成 dist/block/player.js.
#  元素屬性:
#   - data-block: block 名稱
#   - data-version / data-path: 選用, block 的版本與檔案路徑
#   - data-bundle: 選用. 預先打包的 block 檔 ( `lotion bundle` 產出 ); 有它就不需經 registry 取 block 與依賴
#  script 屬性 ( 皆選用 ):
#   - data-block-root: block 檔的位置, 預設 `/block` -> <root>/<name>/<path>
#   - data-lib-root: 依賴函式庫的位置, 預設 `/assets/lib` -> <root>/<name>/<version>/<path>
#   - data-manual: 有此屬性時不自動掛載, 改由 lotionBlock.mount(el) 手動掛載
#  掛載的 block 若在 interface 提供 seek(t) 與 duration, 網址帶 ?render 時會設定 window.seek / window.DURATION,
#  如此即可用 lotion cli 逐格輸出. interface 可另提供 ready ( promise, 如 player.ready ): 等它完成才設定,
#  cli 以 window.seek 是否存在判斷頁面就緒.
do ->
  script = document.currentScript
  ds = (script and script.dataset) or {}
  trim = (v) -> v.replace /\/$/, ''
  block-root = trim(ds.blockRoot ? '/block')
  lib-root = trim(ds.libRoot ? '/assets/lib')
  mgr = new block.manager registry:
    lib: ({name, version, path}) -> "#lib-root/#name/#{version or \main}/#{path or 'index.min.js'}"
    block: ({name, version, path}) -> "#block-root/#name/#{path or 'index.html'}"
  mount = (el) ->
    p = mgr.init!then -> if el.dataset.bundle => mgr.debundle({url: el.dataset.bundle}) else Promise.resolve!
    p
      .then -> mgr.from {name: el.dataset.block, version: el.dataset.version, path: el.dataset.path}, {root: el}
      .then ({interface: itf}) ->
        el.block = itf
        if !(itf and itf.seek and itf.duration? and /[?&]render\b/.test(location.search)) => return itf
        Promise.resolve(itf.ready).then ->
          window.seek = (t) -> itf.seek t
          window.DURATION = itf.duration
          if itf.cues => window.cues = itf.cues
          itf
  start = ->
    if ds.manual? => return Promise.resolve []
    mgr.init!then -> Promise.all Array.from(document.querySelectorAll '[data-block]').map(mount)
  ready = new Promise (res) ->
    if document.readyState == \loading => document.addEventListener \DOMContentLoaded, -> res start!
    else res start!
  window.lotionBlock = {manager: mgr, mount, ready}
