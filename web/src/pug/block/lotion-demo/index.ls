module.exports =
  pkg:
    name: 'lotion-demo'
    version: '0.0.1'
    dependencies: [
      {name: 'lotion', version: 'dev', path: 'index.min.js'}
      {name: 'lotion', version: 'dev', path: 'index.min.css'}
    ]
  init: ({root, ctx}) ->
    @player = scene ctx.lotion, root.querySelector('.demo')
  # 提供 seek / duration 讓 block player 在 ?render 時開放給 lotion cli
  interface: -> {seek: ((t) ~> @player.seek t), duration: @player.duration, player: @player}
