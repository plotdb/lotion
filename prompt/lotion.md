# 寫 lotion 動畫

所有 lotion 動畫都適用的寫法與陷阱，與動畫的形式、風格無關。
寫 lotion 動畫只需要這份文件。特定形式 ( 解說片、UI loop ) 的做法、風格庫、素材與音訊生成，
另有製作工具 `@plotdb/lotitor` ( 目前未公開 )；沒有它不影響這裡的任何內容。


## 原則

 - 畫面是時間的純函數：`seek(t)` 只依 `t` 計算，不保留跨影格狀態。
   播放、拖曳、跳段與逐格輸出都只是用不同的 `t` 呼叫它。
 - `seek` 必須對任何 `t` 都成立，包含 0 與總長之後。
 - 寫完先用 `lotion sheet` 輸出各段頭、尾、交界與轉場中間點的畫面檢查，再輸出影片。
 - 音效時間點由頁面的 `cues()` 提供，與畫面共用同一組時間函數，`lotion cues` 可匯出。


## 嵌入網頁時

 - 舞台用固定的設計尺寸 ( 如 1920×1080 )，依容器等比縮放；不要對被縮放的元素用 `will-change`，文字會糊。
 - 網頁裡常有 bootstrap 等全域樣式：class 加前綴 ( 或用 `@plotdb/block` 讓 csscope 處理 )，
   並把 css 限定在播放器根元素下。
 - 以 pug 的 `:lsc` filter 內嵌時會以 bare 模式編譯，頂層變數會變成全域：整段包進函式。
   若依賴以 defer 載入，inline script 要等到 `DOMContentLoaded` 才能使用它們。
 - 鍵盤操作只在播放器取得焦點時作用，避免空白鍵捲動頁面時誤觸。
 - 預設不要自動播放；打開時要看到有內容的畫面 ( 例如開場標題 )：用 player 選項 `cover: <標題畫面的秒數>`。
   不要用 `start` 跳過去 —— `start` 會改變播放時間 ( 時間軸從那裡開始 )，`cover` 只換顯示的畫面，時間仍是 0。
 - 內容需要非同步準備時 ( 字型載入、依版面量測元素位置 )，準備完成後才呼叫 `player.start()`。
   在那之前播放器會顯示載入畫面、隱藏舞台並停用控制列，避免讀者看到尚未就緒的錯亂畫面。
   以 block 封裝時，interface 要帶上 `ready: player.ready`，render 協定才會等它就緒。


## 互動作品

畫面仍是時間的函式，只是多一份狀態：`seek(t, state)`。

 - player 選項 `interactive: true` 宣告有互動，`state: {…}` 給狀態初始值。初始值就是逐格輸出、
   書架審查與預覽看到的畫面，要讓它自己就是一支完整、看得懂的動畫。狀態要能 JSON 序列化。
 - 可互動的元素加 class `lotion-hit` ( 或 `lotion.hit(el)` )，用一般 DOM 事件 ( click、pointerdown / move / up )。
   點在它們上不會切換播放；點在其他地方照舊播放 / 暫停。元素何時出現照樣在 `seek` 裡依 t 決定。
 - 讀者的操作改變狀態用 `p.set(key, value)` 或 `p.set({…})`：立刻以目前的 t 重畫 ( 暫停中也會 )。
   不要在事件處理裡直接改畫面，畫面一律由 `seek(t, state)` 算出，否則拖時間軸或重畫就會不一致。
   只發聲、不影響畫面的操作 ( 按鈕發出提示音 ) 不需要狀態。
 - 程式控制播放：`p.play()`、`p.pause()`、`p.seek(t)`、`p.rate(r)` ( 小數為慢動作，負數倒播，倒到 0 自動停 )。
 - 「播到某處停下來等讀者」：`p.at(12, ({dir}) -> if dir > 0 and !p.state.answered => p.pause!)`。
   `at` 只在播放經過時觸發，拖時間軸跳過去不算；倒播經過時 `dir` 是 -1，通常要忽略。
   讀者完成操作後 `p.set(…)` 再 `p.play()` 繼續。
 - 拖動元素時把指標座標換算成舞台座標：舞台會縮放，`(e.clientX - stage.getBoundingClientRect().left) * p.width / 舞台的顯示寬度`。
 - 在書架等外層播放時，播放要求會交給外層處理 ( `p.host` )，作品寫法不變，照樣呼叫 `p.play()` 等。
 - 文稿要寫出每個互動：在哪裡、讀者能做什麼、各種結果。書架的搜尋、簡介與審查只看得到文稿與預設狀態的畫面。
 - 用 `lotion sheet … --state '{"crossed":true}'` 檢查其他狀態的畫面。


## 循環

 - 整支無接縫循環的作品 ( 氛圍、背景、可以一直播的內容 ) 用 player 選項 `loop: true`，文稿的 `kind` 寫 `loop`。
   最後一格要能接回第一格。
 - 等讀者互動時重播一小段，用 `p.loop(a, b)`：
   `p.at(84, ({dir}) -> if dir > 0 and !p.state.done => p.loop(83, 84))`，讀者完成操作後 `p.loop(false)`
   ( 需要時再 `p.seek(84)` ) 繼續播放。比起暫停，畫面不會凍住。
 - 循環段落的頭尾畫面要能無接縫銜接：位置相同、顫動或擺動用整數個週期 ( 如 `sin(2π·n·(t - a) / (b - a))` )。
   聲音建議用同長度的循環音。
 - 接回會帶上溢出量，算是跳轉：在 `b` 的 `at` 先觸發再接回，每一圈經過的 `at` 都會再觸發；
   落點 ( 正向的 `a` ) 的 `at` 不會因接回而觸發。逐格輸出 ( `?render` ) 不循環。


## 多語作品

語系在頁面載入時決定 ( 網址 `?lang=xx`，換語言就是重新載入 )，腳本只要知道目前語系，自己挑文字與素材。

 - 一開始先宣告支援的語言，第一個是預設：`lotion.lang(['zh', 'en'])`，回傳目前語系。
   它不需要 player，建 DOM 文字之前就要先呼叫。`zh-TW`、`zh-Hant` 會對到 `zh`，`en-US` 對到 `en`，
   對不到就用預設。
 - 所有依語言而不同的東西都寫成 `{zh: …, en: …}`，用 `lotion.t(…)` 取出目前語系的值；缺的語言退回預設。
   值不限字串，素材路徑、數字、陣列都可以：
   - 舞台上所有看得到的文字 ( 標題、標籤、數字的單位、圖例 )。
   - 章節名稱：`chapters: [[0, lotion.t({zh: '開場', en: 'Intro'})], …]`。
   - 配音與其他依語言而不同的素材：`lotion.t({zh: 'assets/vo-1.zh.mp3', en: 'assets/vo-1.en.mp3'})`。
 - 字幕直接給各語言：`captions: {zh: […], en: […]}`，播放器會從目前語系開始。
 - 文稿每個語言一份完整的文稿，各自的 `lang` 欄位寫該語言：player 選項 `doc: {zh: …, en: …}`，
   或頁面中每個語言一個 `<script type="text/markdown" class="lotion-doc" lang="en">`。
 - 不同語言的文字長度差很多 ( 英文常比中文長一倍 )：版面要容得下最長的那個，或依語言調整字級；
   配音長度不同時，時間軸也要依語言調整 ( 時間點同樣可以用 `lotion.t` 取 )。
 - 每個語言都要用 `lotion sheet <src> <out.png> <t…> --lang all` 檢查，輸出成 `out.zh.png`、`out.en.png`。


## 兩套版面 ( 橫式與直式 )

手機直拿時，16:9 的作品只剩中間一條。要給手機讀者，就同時做一套直式版面。
方向在頁面載入時決定 ( 網址 `?aspect=portrait`，換方向就是重新載入 )，腳本只要依目前方向排版。

 - 一開始先宣告方向與尺寸，第一個是預設：
   `lotion.aspect({landscape: [1920, 1080], portrait: [1080, 1920]})`，回傳目前方向。
   player 會自動用目前方向的尺寸，不必再給 `width` / `height`。
 - 所有座標、尺寸、字級集中在一個版面物件，用 `lotion.byAspect` 取出目前方向的那一份。
   不要叫它 `L`，常和其他名稱衝突，用 `LY`：

       var LY = lotion.byAspect({
         landscape: {title: {x: 120, y: 160, size: 96}, body: 48, chart: {x: 1000, y: 200, w: 800}},
         portrait:  {title: {x: 80, y: 240, size: 88}, body: 48, chart: {x: 80, y: 900, w: 920}}
       })

 - 直式是重新排版，不是把橫式縮小：並排改成上下排，正文至少 44px，標題 80px 以上。
 - 時間軸不可依方向改變：時間點、章節、字幕、`at`、狀態都兩邊共用，所以不要把時間放進 `LY`。
   讀者的筆記與 `&t=` 連結在兩種方向都要對得上。
 - 文字可以同時依語言和方向不同：`lotion.t` 和 `lotion.byAspect` 可以巢狀使用。
 - 兩個方向都要檢查：`lotion sheet <src> <out.png> <t…> --aspect all`，輸出成 `out.landscape.png`、`out.portrait.png`。


## 可攜的封裝

 - 要放進其它網站時，把動畫包成 `@plotdb/block`：依賴 ( 包含 lotion ) 以 `pkg.dependencies` 宣告，
   樣式自動限定範圍。`lotion bundle` 產出單一 bundle 檔，配合 `player.js` 即可在任何網站播放。
 - csscope 限定的是 root 的子孫：樣式的目標元素要放在 root 之下 ( 或用 `:scope` )。
 - block 內不要寫 `body.xxx` 這類外層規則，會被 scope 掉；需要時改由 js 設定。


## 常見錯誤

 - 子元素設定 `visibility: visible` 會蓋過父元素的 `hidden`：只對最外層元素切換 visibility，
   子元素只調 opacity ( `lotion.put` 的 `hide: false` )。
 - 依賴「目前選中哪個」決定的樣式 ( 如分頁文字顏色 ) 在動畫過程中會出錯；
   改為依當下的幾何狀態計算 ( 文字是否被指示器蓋住 )。
 - 載入時看到錯亂的畫面：舞台內容在準備完成前就顯示了。把非同步準備 ( 字型、量測 ) 放在 `start()` 之前，
   不要先 `start()` 再補；逐格輸出也會因此在就緒前就開始錄。
 - 某個時間之前資料尚未存在 ( 例如 `filter(...).pop!` 回傳 undefined )：`seek` 必須對任何 `t` 都成立，
   包含 0 與總長之後。用 `lotion sheet` 掃過頭尾與每段交界。
 - LiveScript：`.5` 這類小數會被當成八進位錯誤，寫 `0.5`；`by`、`to`、`on` 等是保留字，不能當變數名。
