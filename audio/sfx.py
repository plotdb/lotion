# UI 音效合成 ( 整理自 0926-motion ). 輸出 <outdir>/*.wav, 並量測每個檔的 transient peak 寫入 <outdir>/peaks.json
#  python audio/sfx.py <outdir> [--list]
#  peak 定義: 3ms RMS 包絡第一次達到全域最大 80% 的位置
#   - 多音符音效 ( chime / toggle ) 取第一個音的擊點, 而非較晚但較響的音
#   - 混音時以 peak 而非檔案開頭對齊 cue 時間 ( 見 mix.py )
import numpy as np, json, os, argparse
from common import SR, write

rng = np.random.default_rng(7)

def t_(dur): return np.arange(int(SR * dur)) / SR
def env(t, a, d): return (1 - np.exp(-t / max(a, 1e-4))) * np.exp(-t / d)
def bandnoise(n, lo, hi):
  x = rng.standard_normal(n)
  X = np.fft.rfft(x); f = np.fft.rfftfreq(n, 1 / SR)
  X[(f < lo) | (f > hi)] = 0
  y = np.fft.irfft(X, n); return y / (np.abs(y).max() + 1e-9)
def sine(t, f, ph=0): return np.sin(2 * np.pi * f * t + ph)
def pad(x, pre=0.0, post=0.0): return np.concatenate([np.zeros(int(SR * pre)), x, np.zeros(int(SR * post))])

def click():
  t = t_(0.06)
  body = sine(t, 1850) * env(t, 0.0004, 0.006) * 0.7 + sine(t, 520) * env(t, 0.0008, 0.012) * 0.5
  return body + bandnoise(len(t), 2500, 9000) * env(t, 0.0002, 0.003) * 0.5

def tick():
  t = t_(0.03)
  return sine(t, 3400) * env(t, 0.0003, 0.004) * 0.6 + bandnoise(len(t), 4000, 12000) * env(t, 0.0002, 0.0015) * 0.3

def scrub():
  t = t_(0.015)
  return bandnoise(len(t), 5000, 12000) * env(t, 0.0002, 0.0012) * 0.5

def pop():
  t = t_(0.14)
  f = 380 + 520 * np.exp(-t / 0.018)
  return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(t, 0.001, 0.035) * 0.9

def toggle():
  a = click() * 0.6
  t = t_(0.05)
  b = sine(t, 2600) * env(t, 0.0004, 0.005) * 0.6 + sine(t, 780) * env(t, 0.0006, 0.01) * 0.4
  out = np.zeros(int(SR * 0.12)); out[:len(a)] += a
  o = int(SR * 0.028); out[o:o + len(b)] += b
  return out

def chime(notes, gap, dur=0.5):
  out = np.zeros(int(SR * (gap * len(notes) + dur)))
  for i, f in enumerate(notes):
    t = t_(dur)
    x = (sine(t, f) + 0.25 * sine(t, f * 2.01) + 0.08 * sine(t, f * 3.02)) * env(t, 0.002, 0.16)
    o = int(SR * gap * i); out[o:o + len(x)] += x * (0.8 if i == 0 else 0.65)
  return out * 0.45

def success(): return chime([1318.5, 1975.5], 0.07)
def notify(): return chime([1567.98, 2093.0, 2637.0], 0.06, 0.45)

def typing():
  t = t_(0.05)
  return bandnoise(len(t), 1200, 6000) * env(t, 0.0003, 0.005) * 0.55 + sine(t, 210) * env(t, 0.001, 0.01) * 0.35

def whoosh():
  t = t_(0.32)
  n = bandnoise(len(t), 300, 4000)
  e = np.sin(np.pi * np.clip(t / 0.32, 0, 1)) ** 2.5
  return n * e * 0.18

SFX = dict(click=click, tick=tick, scrub=scrub, pop=pop, toggle=toggle, success=success, notify=notify,
  type=typing, whoosh=whoosh)

def peak(x):
  win = int(SR * 0.003)
  e = np.sqrt(np.convolve(x * x, np.ones(win) / win, 'same'))
  i = int(np.argmax(e >= 0.8 * e.max()))
  # 往後找到該段的局部最大
  while i + 1 < len(e) and e[i + 1] >= e[i]: i += 1
  return i

if __name__ == '__main__':
  ap = argparse.ArgumentParser(description='synthesize ui sound effects')
  ap.add_argument('outdir')
  ap.add_argument('--list', action='store_true', help='only list available effects')
  a = ap.parse_args()
  if a.list:
    print(' '.join(SFX)); raise SystemExit
  os.makedirs(a.outdir, exist_ok=True)
  peaks = {}
  for name, fn in SFX.items():
    x = pad(fn(), 0.005, 0.02)
    write(os.path.join(a.outdir, name + '.wav'), x)
    peaks[name] = round(peak(x) / SR, 5)
  json.dump(peaks, open(os.path.join(a.outdir, 'peaks.json'), 'w'), indent=1)
  print(json.dumps(peaks, indent=1))
