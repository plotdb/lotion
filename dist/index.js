(function(){
  var PI, sin, cos, exp, sqrt, round, clamp, lerp, ss, spring, presets, track, vis, bump, typing, hex, mixc, rgb, mk, put, txt, NS, svg, player, ref$, libs, libCache, lib, encode, lotion;
  PI = Math.PI, sin = Math.sin, cos = Math.cos, exp = Math.exp, sqrt = Math.sqrt, round = Math.round;
  clamp = function(v, a, b){
    a == null && (a = 0);
    b == null && (b = 1);
    if (v < a) {
      return a;
    } else if (v > b) {
      return b;
    } else {
      return v;
    }
  };
  lerp = function(a, b, f){
    return a + (b - a) * f;
  };
  ss = function(x){
    x = clamp(x);
    return x * x * (3 - 2 * x);
  };
  spring = function(t, w, z){
    var wd;
    w == null && (w = 14);
    z == null && (z = 0.8);
    if (t <= 0) {
      return 0;
    }
    if (z >= 1) {
      return 1 - exp(-w * t) * (1 + w * t);
    }
    wd = w * sqrt(1 - z * z);
    return 1 - exp(-z * w * t) * (cos(wd * t) + (z * w / wd) * sin(wd * t));
  };
  presets = {
    fast: {
      w: 22,
      z: 0.86
    },
    std: {
      w: 14,
      z: 0.8
    },
    soft: {
      w: 9,
      z: 0.9
    },
    move: {
      w: 11,
      z: 0.85
    },
    ease: {
      w: 10,
      z: 1
    }
  };
  track = function(keys, opt){
    var p, def;
    opt == null && (opt = 'std');
    p = function(o){
      if (typeof o === 'string') {
        return presets[o];
      } else {
        return o;
      }
    };
    def = p(opt);
    return function(t){
      var v, i$, to$, i, k, c;
      v = keys[0][1];
      for (i$ = 1, to$ = keys.length; i$ < to$; ++i$) {
        i = i$;
        k = keys[i];
        c = k[2] ? p(k[2]) : def;
        v += (k[1] - keys[i - 1][1]) * spring(t - k[0], c.w, c.z);
      }
      return v;
    };
  };
  vis = function(t, t0, t1, din, dout){
    t1 == null && (t1 = 1e9);
    din == null && (din = 0.4);
    dout == null && (dout = 0.35);
    return ss((t - t0) / din) * (1 - ss((t - t1) / dout));
  };
  bump = function(t, t0, d){
    d == null && (d = 0.6);
    if (t < t0 || t > t0 + d) {
      return 0;
    } else {
      return Math.pow(sin(PI * (t - t0) / d), 2);
    }
  };
  typing = function(t, t0, text, dt){
    var chars;
    dt == null && (dt = 0.06);
    chars = Array.from(text);
    return chars.slice(0, clamp(Math.floor((t - t0) / dt) + 1, 0, chars.length)).join('');
  };
  hex = function(h){
    return [1, 3, 5].map(function(i){
      return parseInt(h.slice(i, i + 2), 16);
    });
  };
  mixc = function(a, b, f){
    return [0, 1, 2].map(function(i){
      return lerp(a[i], b[i], f);
    });
  };
  rgb = function(c, a){
    if (a != null) {
      return "rgba(" + c.map(function(it){
        return round(it);
      }).join(',') + "," + a + ")";
    } else {
      return "rgb(" + c.map(function(it){
        return round(it);
      }).join(',') + ")";
    }
  };
  mk = function(cls, html, parent, prefix){
    var e;
    cls == null && (cls = '');
    html == null && (html = '');
    prefix == null && (prefix = '');
    e = document.createElement('div');
    e.className = cls.split(' ').filter(function(it){
      return it;
    }).map(function(it){
      return prefix + it;
    }).join(' ');
    e.innerHTML = html;
    if (parent) {
      parent.appendChild(e);
    }
    return e;
  };
  put = function(e, x, y, s, o, opt){
    var hide, ref$;
    s == null && (s = 1);
    o == null && (o = 1);
    opt == null && (opt = {});
    hide = (ref$ = opt.hide) != null ? ref$ : true;
    if (hide && o <= 0.002) {
      if (e._lv !== false) {
        e.style.visibility = 'hidden';
        e._lv = false;
      }
      return;
    }
    if (hide && e._lv !== true) {
      e.style.visibility = 'visible';
      e._lv = true;
    }
    e.style.transform = "translate(" + x.toFixed(2) + "px," + y.toFixed(2) + "px) scale(" + s.toFixed(4) + ")";
    e.style.opacity = o.toFixed(3);
    if (opt.blur != null) {
      return e.style.filter = opt.blur > 0.05 ? "blur(" + opt.blur.toFixed(2) + "px)" : '';
    }
  };
  txt = function(e, v){
    if (e._lt !== v) {
      e.innerHTML = v;
      return e._lt = v;
    }
  };
  NS = 'http://www.w3.org/2000/svg';
  svg = function(tag, attrs, parent){
    var e, k, v;
    attrs == null && (attrs = {});
    e = document.createElementNS(NS, tag);
    for (k in attrs) {
      v = attrs[k];
      e.setAttribute(k, v);
    }
    if (parent) {
      parent.appendChild(e);
    }
    return e;
  };
  player = function(opt){
    var this$ = this;
    opt == null && (opt = {});
    this.opt = opt;
    this.root = typeof opt.root === 'string'
      ? document.querySelector(opt.root)
      : opt.root;
    this.width = opt.width || 1920;
    this.height = opt.height || 1080;
    this.duration = opt.duration || 0;
    this.chapters = opt.chapters || [];
    this.t = 0;
    this.playing = false;
    this.last = null;
    this.started = false;
    this.ready = new Promise(function(res){
      return this$.readyRes = res;
    });
    this.renderMode = /[?&]render\b/.test(location.search);
    this.init();
    return this;
  };
  player.prototype = (ref$ = Object.create(Object.prototype), ref$.constructor = player, ref$.init = function(){
    var r, ref$, html, q, this$ = this;
    r = this.root;
    r.classList.add('lotion');
    if (!r.hasAttribute('tabindex')) {
      r.setAttribute('tabindex', 0);
    }
    this.viewport = mk('lotion-viewport', '', r);
    this.stage = mk('lotion-stage', '', this.viewport);
    ref$ = this.stage.style;
    ref$.width = this.width + "px";
    ref$.height = this.height + "px";
    this.viewport.style.aspectRatio = this.width + " / " + this.height;
    r.classList.add('lotion-loading');
    if (this.opt.loading !== false) {
      html = typeof this.opt.loading === 'string' ? this.opt.loading : '<div class="lotion-spinner"></div>';
      this.loading = mk('lotion-loading-screen', html, this.viewport);
    }
    this.bar = mk('lotion-bar', '<div class="lotion-btn lotion-play"></div>\n<div class="lotion-track"><div class="lotion-rail"></div><div class="lotion-fill"></div>\n<div class="lotion-chapters"></div><div class="lotion-knob"></div></div>\n<div class="lotion-time"></div>\n<div class="lotion-btn lotion-fs" title="全螢幕"><svg width="16" height="16" viewBox="0 0 16 16" fill="none"\nstroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M2 6V2h4M10 2h4v4M14 10v4h-4M6 14H2v-4"/></svg></div>', r);
    q = function(n){
      return this$.bar.querySelector(".lotion-" + n);
    };
    this.el = {
      play: q('play'),
      fill: q('fill'),
      knob: q('knob'),
      time: q('time'),
      track: q('track'),
      chapters: q('chapters'),
      fs: q('fs')
    };
    this.chapters.map(function(arg$){
      var t, name, e;
      t = arg$[0], name = arg$[1];
      e = mk('lotion-ch', '', this$.el.chapters);
      e.title = name;
      return e.style.left = 100 * t / this$.duration + "%";
    });
    this.bind();
    if (this.renderMode) {
      r.classList.add('lotion-render');
    }
    this.fit();
    if (typeof ResizeObserver !== 'undefined') {
      return new ResizeObserver(function(){
        return this$.fit();
      }).observe(this.viewport);
    } else {
      return window.addEventListener('resize', function(){
        return this$.fit();
      });
    }
  }, ref$.start = function(){
    var m, this$ = this;
    this.started = true;
    this.root.classList.remove('lotion-loading');
    if (this.loading) {
      this.loading.remove();
    }
    if (this.renderMode) {
      window.seek = function(t){
        return this$.opt.seek(t);
      };
      window.DURATION = this.duration;
      if (this.opt.cues) {
        window.cues = this.opt.cues;
      }
    }
    this.readyRes(this);
    m = /[?&]t=([\d.]+)/.exec(location.search);
    this.seek(m
      ? +m[1]
      : this.renderMode
        ? 0
        : this.opt.start || 0);
    if (this.opt.autoplay && !this.renderMode) {
      document.fonts.ready.then(function(){
        return this$.play(true);
      });
    }
    return this;
  }, ref$.bind = function(){
    var dragging, fromEvent, this$ = this;
    this.el.play.addEventListener('click', function(e){
      e.stopPropagation();
      return this$.toggle();
    });
    this.el.fs.addEventListener('click', function(e){
      e.stopPropagation();
      return this$.fullscreen();
    });
    this.viewport.addEventListener('click', function(){
      this$.root.focus();
      return this$.toggle();
    });
    dragging = false;
    fromEvent = function(e){
      var b;
      b = this$.el.track.getBoundingClientRect();
      return this$.seek(this$.duration * clamp((e.clientX - b.left) / b.width));
    };
    this.el.track.addEventListener('pointerdown', function(e){
      dragging = true;
      this$.el.track.setPointerCapture(e.pointerId);
      return fromEvent(e);
    });
    this.el.track.addEventListener('pointermove', function(e){
      if (dragging) {
        return fromEvent(e);
      }
    });
    this.el.track.addEventListener('pointerup', function(){
      return dragging = false;
    });
    return this.root.addEventListener('keydown', function(e){
      var starts, ref$;
      starts = this$.chapters.map(function(c){
        return c[0];
      });
      if (e.code === 'Space') {
        e.preventDefault();
        return this$.toggle();
      } else if (e.key === 'f') {
        return this$.fullscreen();
      } else if (e.key === 'ArrowRight') {
        return this$.seek((ref$ = starts.find(function(s){
          return s > this$.t + 0.05;
        })) != null
          ? ref$
          : this$.duration);
      } else if (e.key === 'ArrowLeft') {
        return this$.seek((ref$ = starts.filter(function(s){
          return s < this$.t - 0.5;
        }).pop()) != null ? ref$ : 0);
      }
    });
  }, ref$.fit = function(){
    var w, h, s;
    if (this.encoding) {
      return;
    }
    w = this.viewport.clientWidth;
    h = this.viewport.clientHeight;
    if (!w || !h) {
      return;
    }
    s = Math.min(w / this.width, h / this.height);
    return this.stage.style.transform = "translate(" + (w - this.width * s) / 2 + "px," + (h - this.height * s) / 2 + "px) scale(" + s + ")";
  }, ref$.fmt = function(t){
    return Math.floor(t / 60) + ":" + ("0" + Math.floor(t % 60)).slice(-2);
  }, ref$.seek = function(t){
    var p, ch;
    if (!this.started || this.encoding) {
      return;
    }
    this.t = t = clamp(t, 0, this.duration);
    this.opt.seek(t);
    p = 100 * t / this.duration + "%";
    this.el.fill.style.width = p;
    this.el.knob.style.left = p;
    ch = this.chapters.filter(function(c){
      return c[0] <= t;
    }).pop();
    this.el.time.textContent = (ch ? ch[1] + " · " : '') + (this.fmt(t) + " / " + this.fmt(this.duration));
    return this.root.classList.toggle('lotion-playing', this.playing);
  }, ref$.tick = function(now){
    var this$ = this;
    if (!this.playing) {
      return;
    }
    if (this.last != null) {
      this.seek(this.t + (now - this.last) / 1000);
    }
    this.last = now;
    if (this.t >= this.duration) {
      this.playing = false;
      this.seek(this.t);
      return;
    }
    return requestAnimationFrame(function(n){
      return this$.tick(n);
    });
  }, ref$.play = function(go){
    var this$ = this;
    go == null && (go = true);
    if (!this.started || this.encoding) {
      return;
    }
    if (go && this.t >= this.duration) {
      this.t = 0;
    }
    this.playing = go;
    this.last = null;
    this.seek(this.t);
    if (go) {
      return requestAnimationFrame(function(n){
        return this$.tick(n);
      });
    }
  }, ref$.pause = function(){
    return this.play(false);
  }, ref$.toggle = function(){
    return this.play(!this.playing);
  }, ref$.fullscreen = function(){
    var d;
    d = document;
    if (d.fullscreenElement || d.webkitFullscreenElement) {
      (d.exitFullscreen || d.webkitExitFullscreen).call(d);
    } else {
      (this.root.requestFullscreen || this.root.webkitRequestFullscreen).call(this.root);
    }
    return this.root.focus();
  }, ref$.encode = function(opt){
    var t0, tf, cover, bar, done, progress, ref$, this$ = this;
    opt == null && (opt = {});
    if (!this.started) {
      return Promise.reject(new Error('[lotion] encode() before start()'));
    }
    if (this.encoding) {
      return Promise.reject(new Error('[lotion] already encoding'));
    }
    this.pause();
    t0 = this.t;
    this.encoding = true;
    this.root.classList.add('lotion-encoding');
    tf = this.stage.style.transform;
    this.stage.style.transform = 'none';
    cover = mk('lotion-encoding-screen', '<div class="lotion-spinner"></div><div class="lotion-progress"></div>', this.viewport);
    bar = cover.querySelector('.lotion-progress');
    done = function(){
      cover.remove();
      this$.stage.style.transform = tf;
      this$.encoding = false;
      this$.root.classList.remove('lotion-encoding');
      this$.fit();
      return this$.seek(t0);
    };
    progress = function(v){
      bar.textContent = Math.round(v * 100) + "%";
      if (opt.progress) {
        return opt.progress(v);
      }
    };
    return encode((ref$ = import$({
      el: this.stage,
      seek: this.opt.seek,
      duration: this.duration,
      width: this.width,
      height: this.height
    }, opt), ref$.progress = progress, ref$)).then(function(b){
      done();
      return b;
    })['catch'](function(e){
      done();
      throw e;
    });
  }, ref$);
  libs = {
    snapdom: 'https://cdn.jsdelivr.net/npm/@zumer/snapdom@3.3.0/dist/snapdom.mjs',
    mediabunny: 'https://cdn.jsdelivr.net/npm/mediabunny@1.61.3/dist/bundles/mediabunny.min.mjs'
  };
  libCache = {};
  lib = function(name){
    var ref$;
    return (ref$ = libCache[name]) != null
      ? ref$
      : libCache[name] = import(libs[name]);
  };
  encode = function(opt){
    var even, w, h, fps, sub, d, ref$, from, to, n, bg, abort, output, that;
    opt == null && (opt = {});
    if (typeof VideoEncoder === 'undefined') {
      return Promise.reject(new Error('[lotion] WebCodecs ( VideoEncoder ) is not supported in this browser'));
    }
    even = function(v){
      return 2 * Math.round(v / 2);
    };
    w = even(opt.width || 1920);
    h = even(opt.height || 1080);
    fps = opt.fps || 30;
    sub = Math.max(1, Math.round(opt.sub || 1));
    d = ((ref$ = opt.shutter) != null ? ref$ : 0.5) / fps / sub;
    from = opt.from || 0;
    to = (ref$ = opt.to) != null
      ? ref$
      : opt.duration;
    n = Math.max(1, Math.round((to - from) * fps));
    bg = opt.background || getComputedStyle(opt.el).backgroundColor;
    if (!bg || bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') {
      bg = '#000';
    }
    abort = function(){
      if (opt.signal && opt.signal.aborted) {
        throw new DOMException('export aborted', 'AbortError');
      }
    };
    output = null;
    return Promise.all([
      (that = opt.snapdom)
        ? Promise.resolve(that)
        : lib('snapdom'), (that = opt.mediabunny)
        ? Promise.resolve(that)
        : lib('mediabunny')
    ]).then(function(arg$){
      var sd, mb, snap, canvas, ctx;
      sd = arg$[0], mb = arg$[1];
      snap = sd.snapdom || sd;
      canvas = document.createElement('canvas');
      canvas.width = w;
      canvas.height = h;
      ctx = canvas.getContext('2d');
      return mb.getFirstEncodableVideoCodec(['avc', 'vp9', 'av1'], {
        width: w,
        height: h
      }).then(function(codec){
        var src;
        if (!codec) {
          throw new Error("[lotion] no encodable video codec for " + w + "x" + h);
        }
        output = new mb.Output({
          format: new mb.Mp4OutputFormat({
            fastStart: 'in-memory'
          }),
          target: new mb.BufferTarget()
        });
        src = new mb.CanvasSource(canvas, {
          codec: codec,
          bitrate: opt.bitrate || mb.QUALITY_HIGH
        });
        output.addVideoTrack(src, {
          frameRate: fps
        });
        return output.start().then(function(){
          return src;
        });
      }).then(function(src){
        var pending, step;
        pending = Promise.resolve();
        step = function(i, j){
          var t;
          abort();
          if (i >= n) {
            return pending;
          }
          if (j >= sub) {
            return pending.then(function(){
              abort();
              pending = src.add(i / fps, 1 / fps);
              if (opt.progress) {
                opt.progress((i + 1) / n);
              }
              return step(i + 1, 0);
            });
          }
          t = clamp(from + i / fps + (sub > 1 ? (j - (sub - 1) / 2) * d : 0), 0, opt.duration);
          opt.seek(t);
          return snap.toCanvas(opt.el, {
            width: w,
            height: h,
            dpr: 1,
            backgroundColor: bg
          }).then(function(c){
            ctx.globalAlpha = 1 / (j + 1);
            ctx.drawImage(c, 0, 0, w, h);
            return step(i, j + 1);
          });
        };
        return step(0, 0);
      });
    }).then(function(){
      return output.finalize();
    }).then(function(){
      return new Blob([output.target.buffer], {
        type: 'video/mp4'
      });
    })['catch'](function(e){
      var ref$;
      if (output && ((ref$ = output.state) === 'started' || ref$ === 'pending')) {
        output.cancel();
      }
      throw e;
    });
  };
  lotion = {
    clamp: clamp,
    lerp: lerp,
    ss: ss,
    spring: spring,
    presets: presets,
    track: track,
    vis: vis,
    bump: bump,
    typing: typing,
    hex: hex,
    mixc: mixc,
    rgb: rgb,
    mk: mk,
    put: put,
    txt: txt,
    svg: svg,
    player: player,
    encode: encode,
    libs: libs,
    lib: lib
  };
  if (typeof module != 'undefined' && module !== null) {
    module.exports = lotion;
  } else if (typeof window != 'undefined' && window !== null) {
    window.lotion = lotion;
  }
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
}).call(this);
