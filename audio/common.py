# 音訊工具共用: 讀檔 ( 經 ffmpeg ) 與寫 wav. 只依賴 numpy.
import numpy as np, subprocess, wave

SR = 48000

def load(path, sr=SR, start=0, dur=None, channels=1):
  """以 ffmpeg 解碼任意音訊檔, 回傳 float32 陣列 ( channels > 1 時為 (n, channels) )"""
  cmd = ['ffmpeg', '-v', 'quiet', '-ss', str(start)] + (['-t', str(dur)] if dur else []) + \
    ['-i', path, '-ac', str(channels), '-ar', str(sr), '-f', 'f32le', '-']
  x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, dtype=np.float32)
  return x.reshape(-1, channels).copy() if channels > 1 else x.copy()

def write(path, x, sr=SR):
  """寫入 16-bit wav. x 為 (n,) 或 (n, channels), 數值範圍 -1 ~ 1"""
  x = np.clip(np.asarray(x, dtype=np.float32), -1, 1)
  ch = 1 if x.ndim == 1 else x.shape[1]
  with wave.open(path, 'wb') as w:
    w.setnchannels(ch); w.setsampwidth(2); w.setframerate(sr)
    w.writeframes((x * 32767).astype('<i2').tobytes())

def read_wav(path):
  """讀取 16-bit wav, 回傳 (資料, sr). 多聲道時為 (n, channels)"""
  with wave.open(path) as w:
    ch, sr = w.getnchannels(), w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(np.float32) / 32767
  return (x.reshape(-1, ch) if ch > 1 else x), sr

def normalize(x, peak=0.98):
  m = np.abs(x).max()
  return x * (peak / m) if m > peak else x
