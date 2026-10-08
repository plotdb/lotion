module.exports =
  pkg:
    name: 'lotion-demo'
    version: '0.0.1'
    dependencies: [
      {name: 'lotion', version: 'dev', path: 'index.min.js'}
      {name: 'lotion', version: 'dev', path: 'index.min.css'}
      # 實驗性: 向量轉換, 在 lotion 之後載入, 擴充同一個 lotion 物件
      {name: 'lotion', version: 'dev', path: 'vector.min.js'}
    ]
  init: ({root, ctx}) ->
    @player = scene ctx.lotion, root.querySelector('.demo')
  # 提供 seek / duration 讓 block player 在 ?render 時開放給 lotion cli
  # ready: 內容就緒 ( player.start() ) 後才開放 seek
  interface: -> {seek: ((t) ~> @player.seek t), duration: @player.duration, ready: @player.ready, player: @player}
