# 混音: 背景音樂 + 依 cue 放置的音效 ( 整理自 0926-motion ).
#  python audio/mix.py <cues.json> <out.wav> --dur s [--music f] [--start s] [--sfx dir] [--fade s] [--loop]
#  - cues.json: [{t, sfx, gain?}, ...], 通常由 `lotion cues` 從頁面匯出
#  - 音效以 sfx 目錄裡 peaks.json 量到的 transient peak 對齊 cue 時間, 而非檔案開頭 ( 見 sfx.py )
#  - --music: 任意音訊檔 ( 例如 bgm.py 的輸出 ); --start 為音樂中對齊 t = 0 的位置
#  - --loop: 超出尾端的音效回繞到開頭, 音訊可無縫循環; 否則尾端以 --fade 秒淡出
import numpy as np, json, os, argparse
from common import SR, load, read_wav, write, normalize

ap = argparse.ArgumentParser(description='mix background music and cue-aligned sound effects')
ap.add_argument('cues')
ap.add_argument('out')
ap.add_argument('--dur', type=float, required=True, help='length of the output in seconds')
ap.add_argument('--music', default=None)
ap.add_argument('--start', type=float, default=0, help='position in music aligned to t = 0')
ap.add_argument('--sfx', default='sfx', help='directory of sfx wav files and peaks.json')
ap.add_argument('--fade', type=float, default=0)
ap.add_argument('--loop', action='store_true')
ap.add_argument('--sfx-gain', type=float, default=0.55)
ap.add_argument('--music-gain', type=float, default=0.8)
a = ap.parse_args()

n = int(SR * a.dur)
mix = np.zeros((n, 2), np.float32)
if a.music:
  music = load(a.music, start=a.start, dur=a.dur, channels=2)[:n]
  mix[:len(music)] = music * a.music_gain

cues = json.load(open(a.cues))
peaks = json.load(open(os.path.join(a.sfx, 'peaks.json'))) if cues else {}
cache = {}
for c in cues:
  name = c['sfx']
  if name not in cache:
    x, _ = read_wav(os.path.join(a.sfx, name + '.wav'))
    cache[name] = x if x.ndim == 1 else x.mean(1)
  x = cache[name] * c.get('gain', 1) * a.sfx_gain
  s = int(round((c['t'] - peaks.get(name, 0)) * SR))
  idx = s + np.arange(len(x))
  if a.loop: idx %= n
  else:
    m = (idx >= 0) & (idx < n); idx, x = idx[m], x[m]
  np.add.at(mix[:, 0], idx, x)
  np.add.at(mix[:, 1], idx, x)

if a.fade > 0 and not a.loop:
  f = int(SR * a.fade)
  mix[n - f:] *= np.linspace(1, 0, f)[:, None]
pk = float(np.abs(mix).max())
write(a.out, normalize(mix))
print('%s  cues %d  peak %.3f' % (a.out, len(cues), pk))
