# 簡易背景音樂合成: 以重複的 bassline 為骨幹, 加上鼓組與和弦墊音. 只依賴 numpy.
#  python audio/bgm.py <out.wav> [--bpm 120] [--bars 16] [--key A] [--scale minor] [--prog 1,6,3,7]
#                      [--bass pulse] [--drums four] [--pad] [--intro 2] [--outro 2] [--loop] [--grid grid.json]
#
#  設計:
#  - 和弦進行以音階級數表示 ( --prog 1,6,3,7 ), 每小節一個和弦, 循環使用
#  - bassline 是一小節 16 格的樣式 ( --bass ), 每格為相對於和弦根音的半音數, '.' 為休止; 每小節重複, 隨和弦移調
#  - 鼓組樣式 ( --drums ): kick / hat / clap 各 16 格
#  - 編排: 前 --intro 小節只有 bass 與 hat, 最後 --outro 小節逐漸收掉; --loop 時不做 intro / outro,
#    並把超出尾端的音尾繞回開頭, 可無縫循環
#  - t = 0 即第一小節的第一拍, 方便與動畫時間軸對齊; --grid 會輸出節拍格線 ( 與 beats.py 格式相同 )
import numpy as np, argparse, json
from common import SR, write, normalize

NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6,
  'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}
SCALE = {
  'major': [0, 2, 4, 5, 7, 9, 11], 'minor': [0, 2, 3, 5, 7, 8, 10],
  'dorian': [0, 2, 3, 5, 7, 9, 10], 'mixolydian': [0, 2, 4, 5, 7, 9, 10]
}
# bassline 樣式: 16 格, 數字為相對和弦根音的半音數, '.' 休止, '-' 延續前一音
BASS = {
  'pulse':  '0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0',
  'octave': '0 . 12 . 0 . 12 . 0 . 12 . 0 . 12 .',
  'house':  '. . 0 . . . 0 . . . 0 . . . 0 12',
  'drive':  '0 . 0 12 . 0 7 . 0 . 0 12 . 7 5 .',
  'walk':   '0 - - - 7 - - - 12 - - - 7 - 5 -',
}
DRUMS = {
  'four':   {'kick': 'x...x...x...x...', 'hat': '..x...x...x...x.', 'clap': '....x.......x...'},
  'half':   {'kick': 'x.......x.......', 'hat': 'x.x.x.x.x.x.x.x.', 'clap': '........x.......'},
  'broken': {'kick': 'x.....x...x.....', 'hat': '..x...x...x...xx', 'clap': '....x.......x..x'},
  'none':   {'kick': '................', 'hat': '................', 'clap': '................'},
}

rng = np.random.default_rng(3)

def hz(midi): return 440 * 2 ** ((midi - 69) / 12)

def env(n, a, d, sustain=0.0, r=0.0):
  """attack / 指數衰減至 sustain; 結尾 r 秒線性釋放"""
  t = np.arange(n) / SR
  e = (1 - np.exp(-t / max(a, 1e-4))) * (sustain + (1 - sustain) * np.exp(-t / d))
  if r > 0:
    k = min(n, int(r * SR)); e[n - k:] *= np.linspace(1, 0, k)
  return e

def saw(f, n, detune=0.0):
  t = np.arange(n) / SR
  x = 2 * ((f * t) % 1) - 1
  if detune: x = 0.5 * x + 0.5 * (2 * ((f * (1 + detune) * t + 0.37) % 1) - 1)
  return x

def lowpass(x, cutoff, q=0.9):
  """時變截止頻率的 state variable filter. cutoff 可為陣列 ( 每個 sample 一個值 )"""
  cutoff = np.broadcast_to(cutoff, x.shape)
  f = 2 * np.sin(np.pi * np.clip(cutoff, 20, SR / 6) / SR)
  low = band = 0.0
  y = np.empty_like(x)
  damp = 1 / q
  for i in range(len(x)):
    low += f[i] * band
    high = x[i] - low - damp * band
    band += f[i] * high
    y[i] = low
  return y

def bass_note(midi, dur, accent=1.0):
  n = int(dur * SR)
  x = saw(hz(midi), n, detune=0.004) + 0.5 * np.sin(2 * np.pi * hz(midi - 12) * np.arange(n) / SR)
  cut = 180 + 1400 * accent * np.exp(-np.arange(n) / SR / 0.09)
  return lowpass(x, cut, q=1.4) * env(n, 0.003, 0.25, 0.55, 0.02) * 0.5

def kick():
  n = int(0.35 * SR); t = np.arange(n) / SR
  f = 48 + 110 * np.exp(-t / 0.035)
  return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.001, 0.16) * 0.95

def noise_hp(n, cut):
  X = np.fft.rfft(rng.standard_normal(n)); fq = np.fft.rfftfreq(n, 1 / SR)
  X[fq < cut] = 0
  y = np.fft.irfft(X, n); return y / (np.abs(y).max() + 1e-9)

def hat(open_=False):
  n = int((0.18 if open_ else 0.05) * SR)
  return noise_hp(n, 7000) * env(n, 0.0005, 0.06 if open_ else 0.012) * 0.22

def clap():
  n = int(0.22 * SR)
  x = noise_hp(n, 1200) * env(n, 0.001, 0.06)
  for d in (0.011, 0.022):  # 拍手的多重起音
    k = int(d * SR); x[k:] += noise_hp(n - k, 1200) * env(n - k, 0.001, 0.012) * 0.6
  return x * 0.28

def pad_chord(midis, dur):
  n = int(dur * SR)
  x = sum(saw(hz(m), n, detune=0.006) for m in midis) / len(midis)
  return lowpass(x, 900, q=0.7) * env(n, 0.35, 10, 0.9, 0.4) * 0.16

def parse_steps(s):
  tok = s.split() if ' ' in s.strip() else list(s)
  if len(tok) != 16: raise SystemExit('pattern must have 16 steps: %r' % s)
  return tok

if __name__ == '__main__':
  ap = argparse.ArgumentParser(description='synthesize a simple looping bassline track')
  ap.add_argument('out')
  ap.add_argument('--bpm', type=float, default=120)
  ap.add_argument('--bars', type=int, default=16)
  ap.add_argument('--key', default='A', help='tonic, e.g. A, C#, Eb')
  ap.add_argument('--octave', type=int, default=2, help='octave of the bass tonic')
  ap.add_argument('--scale', default='minor', choices=list(SCALE))
  ap.add_argument('--prog', default='1,6,3,7', help='chord degrees, one per bar, cycled')
  ap.add_argument('--bass', default='drive', help='preset (%s) or 16 custom steps' % ', '.join(BASS))
  ap.add_argument('--drums', default='four', choices=list(DRUMS))
  ap.add_argument('--pad', action='store_true', help='add sustained chord pad')
  ap.add_argument('--intro', type=int, default=2, help='bars with bass and hat only')
  ap.add_argument('--outro', type=int, default=2, help='bars fading out at the end')
  ap.add_argument('--loop', action='store_true', help='seamless loop: no intro / outro, tails wrap around')
  ap.add_argument('--swing', type=float, default=0, help='0 ~ 0.3, delays every second 16th')
  ap.add_argument('--grid', default=None, help='write beat grid json here')
  a = ap.parse_args()

  scale = SCALE[a.scale]
  tonic = 12 * (a.octave + 1) + NOTE[a.key]
  prog = [int(v) for v in a.prog.split(',')]
  bass = parse_steps(BASS.get(a.bass, a.bass))
  drums = {k: parse_steps(v) for k, v in DRUMS[a.drums].items()}
  intro, outro = (0, 0) if a.loop else (a.intro, a.outro)

  step = 60 / a.bpm / 4
  total = a.bars * 16 * step
  n = int(round(total * SR))
  out = np.zeros((n + int(SR * 2), 2), np.float32)  # 多留 2 秒放音尾

  def place(x, t, gain=1.0, pan=0.0):
    s = int(round(t * SR)); e = s + len(x)
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    out[s:e, 0] += x * gain * l * 1.414
    out[s:e, 1] += x * gain * r * 1.414

  def degree(d, shift=0):
    i = d - 1 + shift
    return scale[i % 7] + 12 * (i // 7)

  K, C = kick(), clap()
  for bar in range(a.bars):
    root = tonic + degree(prog[bar % len(prog)])
    t0 = bar * 16 * step
    # 編排: intro 只有 bass + hat; outro 逐小節降低音量
    level = 1.0 if bar < a.bars - outro else (a.bars - bar) / (outro + 1)
    full = bar >= intro
    if a.pad and full:
      d = prog[bar % len(prog)]
      chord = [tonic + 12 + degree(d), tonic + 12 + degree(d, 2), tonic + 12 + degree(d, 4)]
      place(pad_chord(chord, 16 * step), t0, level)
    for i in range(16):
      t = t0 + i * step + (a.swing * step if i % 2 else 0)
      s = bass[i]
      if s not in ('.', '-'):
        length = 1
        while i + length < 16 and bass[i + length] == '-': length += 1
        place(bass_note(root + int(s), length * step * 0.92, 1.0 if i % 4 == 0 else 0.6), t, level)
      if full and drums['kick'][i] == 'x': place(K, t, level)
      if full and drums['clap'][i] == 'x': place(C, t, level * 0.9, 0.15)
      if drums['hat'][i] == 'x': place(hat(), t, level * (1 if full else 0.7), -0.25)

  if a.loop:
    tail = out[n:].copy()
    out = out[:n]
    k = min(len(tail), n)
    out[:k] += tail[:k]
  else:
    tail = int(SR * 1.5)
    out = out[:n + tail]
    out[n:] *= np.linspace(1, 0, tail)[:, None]
  write(a.out, normalize(out * 0.9, 0.95))
  beats = [round(i * 4 * step, 4) for i in range(a.bars * 4)]
  print('%s  %.1f bpm  %d bars  %.2fs  key %s %s  prog %s' % (a.out, a.bpm, a.bars, total, a.key, a.scale, a.prog))
  if a.grid:
    json.dump({'bpm': a.bpm, 'offset': 0, 'beats': beats, 'downbeats': beats[::4]}, open(a.grid, 'w'), indent=1)
