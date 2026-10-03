# 節拍分析: 估計 BPM 與第一拍位置, 輸出節拍格線 ( 整理自 0926-motion 的 bpm / grid / refine ).
#  python audio/beats.py <music> [--start s] [--dur s] [--min 70] [--max 180] [--out grid.json]
#  - BPM: onset 包絡的自相關, 同時考慮 1 / 2 / 4 倍拍長, 再以相位一致性細調到 0.005 BPM
#  - 第一拍: 在一個週期內掃描起點, 取節拍位置上包絡總和最大者 ( 以低頻為主 ); 並補償分析窗的延遲
#  - 小節起點: 比較 4 個相位上低頻 ( kick ) 的強度, 取最強者
#  - 限制: bassline 落在反拍、kick 又是切分時, 拍點可能偏半拍; 以 --shift 0.5 ( 單位: 拍 ) 校正
#  - 輸出: {bpm, offset, beats, downbeats}; 時間皆相對於 --start
import numpy as np, argparse, json
from common import load

SR = 22050
HOP = 256
FPS = SR / HOP

def frames(x, n=1024):
  m = (len(x) - n) // HOP
  return np.lib.stride_tricks.as_strided(x, (m, n), (x.strides[0] * HOP, x.strides[0])) * np.hanning(n)

def onset_env(x):
  S = np.log1p(100 * np.abs(np.fft.rfft(frames(x), axis=1)))
  fl = np.maximum(0, np.diff(S, axis=0)).sum(1)
  fl = fl - np.convolve(fl, np.ones(32) / 32, 'same')
  return np.maximum(fl, 0)

def low_env(x, cut=150):
  S = np.abs(np.fft.rfft(frames(x), axis=1))
  f = np.fft.rfftfreq(1024, 1 / SR)
  return np.maximum(0, np.diff(np.log1p(100 * S[:, f < cut]).sum(1)))

def coarse_tempo(env, lo, hi):
  e = env - env.mean()
  ac = np.correlate(e, e, 'full')[len(e) - 1:]
  bpms = np.arange(lo, hi + 0.01, 0.1)
  def score(b):
    lag, s = 60 * FPS / b, 0
    for k in (1, 2, 4):
      L = lag * k; i = int(L); f = L - i
      if i + 1 < len(ac): s += (ac[i] * (1 - f) + ac[i + 1] * f) / k
    return s
  sc = np.array([score(b) for b in bpms])
  return bpms[sc.argmax()], sc.max() / ac[0]

def fine_tempo(env, b0):
  t = np.arange(len(env)) / FPS
  bs = np.arange(b0 - 1, b0 + 1, 0.005)
  sc = [abs(sum(np.sum(env * np.exp(-2j * np.pi * (b / 60) * k * t)) for k in (1, 2, 4))) for b in bs]
  return bs[int(np.argmax(sc))]

# 分析窗的延遲: diff 後第 i 個值反映的是第 i + 1 個窗, 窗的中心再晚半個窗長
LAG = (HOP + 512) / SR

def norm(v): return v / (v.max() + 1e-9)

def grid(x, bpm):
  env = onset_env(x); low = low_env(x)
  m = min(len(env), len(low))
  # 拍點以低頻 ( kick / bass 起音 ) 為主, 避免被反拍的 hat 或 16 分音符拉偏
  e = norm(low[:m]) * 2 + norm(env[:m])
  t = np.arange(m) / FPS
  period = 60 / bpm
  idx = np.arange(m)
  def score(o): return np.interp(np.arange(o, t[-1] - 0.1, period) * FPS, idx, e).sum()
  cands = np.arange(0, period, 0.001)
  off = cands[int(np.argmax([score(o) for o in cands]))]
  beats = np.arange(off, t[-1] - 0.1, period)
  lb = np.interp(beats * FPS, np.arange(len(low)), low)
  phase = int(np.argmax([lb[i::4].mean() for i in range(4)]))
  beats = beats + LAG
  return beats, beats[phase::4]

if __name__ == '__main__':
  ap = argparse.ArgumentParser(description='estimate bpm and beat grid of a music file')
  ap.add_argument('music')
  ap.add_argument('--start', type=float, default=0)
  ap.add_argument('--dur', type=float, default=None)
  ap.add_argument('--min', type=float, default=70)
  ap.add_argument('--max', type=float, default=180)
  ap.add_argument('--out', default=None, help='write grid json here')
  ap.add_argument('--shift', type=float, default=0, help='shift the grid by this many beats')
  a = ap.parse_args()
  x = load(a.music, sr=SR, start=a.start, dur=a.dur)
  b0, conf = coarse_tempo(onset_env(x), a.min, a.max)
  bpm = fine_tempo(onset_env(x), b0)
  beats, downbeats = grid(x, bpm)
  if a.shift:
    d = a.shift * 60 / bpm
    beats, downbeats = beats + d, downbeats + d
  print('bpm %.3f ( coarse %.1f, confidence %.2f )  first beat %.4fs  first downbeat %.4fs  beats %d'
    % (bpm, b0, conf, beats[0], downbeats[0], len(beats)))
  if a.out:
    json.dump({'bpm': round(float(bpm), 3), 'offset': round(float(beats[0]), 4),
      'beats': [round(float(v), 4) for v in beats], 'downbeats': [round(float(v), 4) for v in downbeats]},
      open(a.out, 'w'), indent=1)
