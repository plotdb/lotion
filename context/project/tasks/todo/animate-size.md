# 動畫 svg 再縮小的可能性

`lotion.animate` ( `src/vector.ls` ) 的輸出還可以再壓。已做的見 CHANGELOG 的 master ( v0.4.0 ):
軌道每元素只寫一次、漸層 mask 擦入改成移動的 svg mask、逐漸畫出的 path 改成 dash 動畫、數值精度。


## 現況 ( 2026-10-08 量測 )

lotitor 的焚風純程式版 ( `trial/sumi-ink/code.html`, 44 秒, 10 fps, 440 格 ):

 - 原始 1484 KB, gzip 365 KB, brotli 230 KB
 - 組成: css keyframes 約 214 KB ( visibility 82 / opacity 81 / transform 45 ), 嵌入字型 101 KB,
   smil 167 KB, 其餘多為 satori 畫的文字 glyph path ( 每段字幕 45 - 70 KB )
 - 變體: html 68, svg 葉節點 258

注意: 前一輪縮小把原始大小減半以上, brotli 後只從 234 KB 到 230 KB —— 被刪掉的多是重複內容, 壓縮本來就處理掉了.
之後的項目也要以壓縮後的大小評估, 原始大小的改善主要影響解析與播放負擔.


## 候選

 - 共用相同的繪製結果: 不同元素 ( 或同元素的不同變體 ) 畫出相同的 glyph path 或圖形時, 放進 `<defs>` 以 `<use>` 引用.
   satori 輸出的 path 帶絕對座標, 要以字為單位比對需先正規化 ( 平移到原點 ). 效益依場景, 壓縮後可能有限.
 - 文字轉 path 的取捨: svg 葉節點的 `<text>` 目前用原生文字加嵌入字型 ( 101 KB ). 轉 lottie 本來就需要 text -> path,
   屆時再比較兩者大小 ( 字少時 path 較小, 字多或重複時字型較小 ).
 - visibility keyframes: 每個變體一條動畫. 可改成一條動畫控制「目前是第幾個變體」, 例如以 css 變數或
   單一 keyframes 切換各變體的 display; 需確認瀏覽器支援與 lottie 對應.
 - opacity keyframes: lotion 的淡入淡出多是 smoothstep / 彈簧, 線性內插需要很多點. 可改用三次貝茲 ( css
   `animation-timing-function` 可逐段指定 cubic-bezier ) 擬合, 點數可大幅減少; lottie 的 keyframe 本來就是貝茲, 可共用.
   transform 同理.
 - 外觀只差在尺寸的方塊 ( 如 lotion demo 的液態指示器, 35 個變體 ): 沒有文字、只有背景 / 邊框 / 圓角的元素,
   可改用原生 `<rect>` 並以寬高 ( 與 rx ) 的軌道表示, 而非每種寬度畫一次.
 - 形狀內插的 path ( 焚風軌跡在對照段的變形, 42 個變體 ): 指令結構相同時, 以 smil 對 `d` 內插 ( 瀏覽器支援同結構
   path 的內插 ), 不必每格一個變體.
 - canvas ( 水墨版的墨暈 ): 每格一張點陣圖, 是水墨版 8 MB 的主因之一. 可降低 canvas 的取樣率 ( 只在內容變化時取樣
   已是如此, 但墨暈每格都變 ), 或允許指定某些元素以較低 fps 取樣.
 - 點陣素材: 水墨版的山、雲等 png 以 data uri 內嵌. 可選擇轉成 webp / 降解析度, 或改為外部連結 ( 不再是單一檔案 ).
 - ~~只差 clip-path 的變體~~: 已做 ( 2026-10-09 ). `clip-path: inset()` 改成一個 clipPath, 矩形以 smil 移動;
   焚風的 html 變體 68 -> 35. 動畫 svg 的 brotli 大小幾乎不變 ( 重複內容本來就被壓掉 ), lottie 4.88 -> 4.66 MB.
   其他形狀 ( circle / polygon / 圓角 inset ) 仍逐變體畫.
