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
