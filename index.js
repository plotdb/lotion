(function(){
  var PI, sin, cos, exp, sqrt, round, clamp, lerp, ss, spring, presets, track, vis, bump, typing, hex, mixc, rgb, mk, put, txt, NS, svg, langState, matchLang, urlLang, decideLang, pick, MAX_STEP, cloneState, hit, player, ref$, libs, libCache, lib, encode, vttTime, vttParseTime, vtt, doc, lotion;
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
  langState = {
    lang: null,
    langs: []
  };
  matchLang = function(want, list){
    var w, r, p, ref$;
    list == null && (list = []);
    if (!want) {
      return null;
    }
    w = (want + "").toLowerCase();
    if ((r = list.find(function(l){
      return (l + "").toLowerCase() === w;
    })) != null) {
      return r;
    }
    p = w.split(/[-_]/)[0];
    return (ref$ = list.find(function(l){
      return (l + "").toLowerCase().split(/[-_]/)[0] === p;
    })) != null ? ref$ : null;
  };
  urlLang = function(){
    var m;
    if (typeof location === 'undefined') {
      return null;
    }
    m = /[?&]lang=([^&#]*)/.exec(location.search);
    if (m) {
      return decodeURIComponent(m[1]);
    } else {
      return null;
    }
  };
  decideLang = function(langs, prefer){
    var ref$;
    if (langs != null && langs.length) {
      langState.langs = langs.slice();
      langState.lang = (ref$ = matchLang(urlLang(), langs)) != null
        ? ref$
        : (ref$ = matchLang(prefer, langs)) != null
          ? ref$
          : langs[0];
    }
    return langState.lang;
  };
  pick = function(v){
    var keys, cur, langs, k, ref$;
    if (!v || typeof v !== 'object' || Array.isArray(v)) {
      return v;
    }
    keys = Object.keys(v);
    cur = langState.lang, langs = langState.langs;
    k = cur != null
      ? (ref$ = matchLang(cur, keys)) != null
        ? ref$
        : matchLang(langs[0], keys)
      : matchLang(urlLang(), keys);
    return v[k != null
      ? k
      : keys[0]];
  };
  MAX_STEP = 1;
  cloneState = function(s){
    if (s) {
      return JSON.parse(JSON.stringify(s));
    } else {
      return {};
    }
  };
  hit = function(el){
    el.classList.add('lotion-hit');
    return el;
  };
  player = function(opt){
    var m, e, c, tracks, k, v, ref$, this$ = this;
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
    this.chapter = null;
    this.caption = null;
    this.handlers = {};
    this.playing = false;
    this.last = null;
    this.started = false;
    this.speed = 1;
    this.span = null;
    this.marks = [];
    this.host = null;
    this.interactive = !!opt.interactive;
    this.state = cloneState(opt.state);
    if (m = /[?&]state=([^&#]*)/.exec(location.search)) {
      try {
        import$(this.state, JSON.parse(decodeURIComponent(m[1])));
      } catch (e$) {
        e = e$;
        console.warn("[lotion] ?state is not valid JSON: " + e.message);
      }
    }
    this.drive = {
      play: function(go){
        go == null && (go = true);
        return this$._play(go);
      },
      pause: function(){
        return this$._play(false);
      },
      seek: function(t, o){
        return this$._seek(t, o);
      },
      rate: function(r){
        return this$._rate(r);
      },
      loop: function(v){
        return this$._loop(v);
      }
    };
    this.ready = new Promise(function(res){
      return this$.readyRes = res;
    });
    this.renderMode = /[?&]render\b/.test(location.search);
    c = opt.captions;
    tracks = !c
      ? {}
      : Array.isArray(c) ? {
        '': c
      } : c;
    this.captionTracks = {};
    for (k in tracks) {
      v = tracks[k];
      this.captionTracks[k] = v.slice().sort(fn$);
    }
    this.lang = opt.langs && opt.langs.length
      ? decideLang(opt.langs, opt.lang)
      : langState.lang;
    this.langs = this.lang != null
      ? langState.langs.slice()
      : [];
    this.captionLangs = Object.keys(this.captionTracks);
    this.captionLang = in$(opt.captionLang, this.captionLangs)
      ? opt.captionLang
      : (ref$ = matchLang(this.lang, this.captionLangs)) != null
        ? ref$
        : (ref$ = this.captionLangs[0]) != null ? ref$ : null;
    this.captionsOn = this.renderMode
      ? !!(opt.burnCaptions || /[?&]captions\b/.test(location.search))
      : !opt.captionsBurned;
    this.init();
    return this;
    function fn$(a, b){
      return a[0] - b[0];
    }
  };
  player.prototype = (ref$ = Object.create(Object.prototype), ref$.constructor = player, ref$.init = function(){
    var r, ref$, html, q, this$ = this;
    r = this.root;
    r.classList.add('lotion');
    if (this.interactive) {
      r.classList.add('lotion-interactive');
    }
    if (this.lang != null) {
      r.setAttribute('lang', this.lang);
    }
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
    this.bar = mk('lotion-bar', '<div class="lotion-track"><div class="lotion-rail"></div><div class="lotion-fill"></div>\n<div class="lotion-chapters"></div><div class="lotion-knob"></div></div>\n<div class="lotion-btn lotion-play"></div>\n<div class="lotion-time"></div>\n<div class="lotion-chapter"></div>\n<div class="lotion-btn lotion-cc" title="字幕 ( c )">CC</div>\n<div class="lotion-btn lotion-fs" title="全螢幕"><svg width="16" height="16" viewBox="0 0 16 16" fill="none"\nstroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M2 6V2h4M10 2h4v4M14 10v4h-4M6 14H2v-4"/></svg></div>', r);
    q = function(n){
      return this$.bar.querySelector(".lotion-" + n);
    };
    this.el = {
      play: q('play'),
      fill: q('fill'),
      knob: q('knob'),
      time: q('time'),
      chapter: q('chapter'),
      track: q('track'),
      chapters: q('chapters'),
      fs: q('fs'),
      cc: q('cc')
    };
    this.chapters.map(function(arg$){
      var t, name, meta, e;
      t = arg$[0], name = arg$[1], meta = arg$[2];
      e = mk('lotion-ch', '', this$.el.chapters);
      e.title = name + (meta && meta.description ? "\n" + meta.description : '');
      return e.style.left = 100 * t / this$.duration + "%";
    });
    this.el.captions = mk('lotion-captions', '', this.viewport);
    if (!this.captionLangs.length) {
      this.el.cc.remove();
    }
    this.root.classList.toggle('lotion-captions-on', this.captionsOn);
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
    var keys, k, ref$, m, this$ = this;
    this.started = true;
    this.docs = this.readDocs();
    keys = Object.keys(this.docs);
    k = (ref$ = matchLang(this.lang, keys)) != null
      ? ref$
      : (ref$ = matchLang(this.langs[0], keys)) != null
        ? ref$
        : keys[0];
    this.doc = k != null ? this.docs[k] : null;
    this.root.classList.remove('lotion-loading');
    if (this.loading) {
      this.loading.remove();
    }
    if (this.renderMode) {
      window.seek = function(t){
        return this$.opt.seek(t, this$.state);
      };
      if (this.interactive || this.opt.state) {
        window.STATE = this.state;
      }
      window.DURATION = this.duration;
      if (this.opt.cues) {
        window.cues = this.opt.cues;
      }
      if (this.captionLangs.length) {
        window.CAPTIONS = this.captionTracks;
      }
      if (this.doc) {
        window.DOC = this.doc;
      }
      if (Object.keys(this.docs).length > 1) {
        window.DOCS = this.docs;
      }
      if (this.lang != null) {
        window.LANG = this.lang;
        window.LANGS = this.langs;
      }
      if (this.chapters.length) {
        window.CHAPTERS = this.chapters;
      }
    }
    this.readyRes(this);
    m = /[?&]t=([\d.]+)/.exec(location.search);
    this._seek(m
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
  }, ref$.readDocs = function(){
    var d, ret, i$, ref$, len$, e, v, ref1$, k;
    d = this.opt.doc;
    if (d && typeof d === 'object') {
      return import$({}, d);
    }
    if (d) {
      return {
        '': d
      };
    }
    ret = {};
    for (i$ = 0, len$ = (ref$ = document.querySelectorAll('script#lotion-doc, script.lotion-doc')).length; i$ < len$; ++i$) {
      e = ref$[i$];
      if ((v = (ref1$ = e.textContent) != null ? ref1$.trim() : void 8) && !((k = e.getAttribute('lang') || '') in ret)) {
        ret[k] = v;
      }
    }
    return ret;
  }, ref$.bind = function(){
    var dragging, fromEvent, drag, this$ = this;
    this.el.play.addEventListener('click', function(e){
      e.stopPropagation();
      return this$.toggle();
    });
    this.el.fs.addEventListener('click', function(e){
      e.stopPropagation();
      return this$.fullscreen();
    });
    this.el.cc.addEventListener('click', function(e){
      e.stopPropagation();
      return this$.showCaptions(!this$.captionsOn);
    });
    this.viewport.addEventListener('click', function(e){
      this$.root.focus();
      if (e.target.closest && e.target.closest('.lotion-hit')) {
        return;
      }
      return this$.toggle();
    });
    dragging = false;
    fromEvent = function(e){
      var b;
      b = this$.el.track.getBoundingClientRect();
      return this$.seek(this$.duration * clamp((e.clientX - b.left) / b.width));
    };
    drag = function(v){
      dragging = v;
      return this$.root.classList.toggle('lotion-dragging', v);
    };
    this.el.track.addEventListener('pointerdown', function(e){
      drag(true);
      this$.el.track.setPointerCapture(e.pointerId);
      return fromEvent(e);
    });
    this.el.track.addEventListener('pointermove', function(e){
      if (dragging) {
        return fromEvent(e);
      }
    });
    this.el.track.addEventListener('pointerup', function(){
      return drag(false);
    });
    this.el.track.addEventListener('pointercancel', function(){
      return drag(false);
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
      } else if (e.key === 'c' && this$.captionLangs.length) {
        return this$.showCaptions(!this$.captionsOn);
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
    if (this.host) {
      this.host.seek(t);
      return this;
    }
    this._seek(t, {
      jump: true
    });
    return this;
  }, ref$._seek = function(t, o){
    var prev, p, ci, i$, ref$, len$, i, c, ch;
    o == null && (o = {});
    if (!this.started || this.encoding) {
      return;
    }
    prev = this.t;
    this.t = t = clamp(t, 0, this.duration);
    this.opt.seek(this.frameT(t), this.state);
    p = 100 * t / this.duration + "%";
    this.el.fill.style.width = p;
    this.el.knob.style.left = p;
    ci = -1;
    for (i$ = 0, len$ = (ref$ = this.chapters).length; i$ < len$; ++i$) {
      i = i$;
      c = ref$[i$];
      if (c[0] <= t) {
        ci = i;
      }
    }
    ch = this.chapters[ci];
    this.el.time.textContent = this.fmt(t) + " / " + this.fmt(this.duration);
    this.el.chapter.textContent = this.el.chapter.title = ch ? ch[1] : '';
    this.root.classList.toggle('lotion-playing', this.playing);
    if ((ch
      ? ci
      : -1) !== (this.chapter
      ? this.chapter.index
      : -1)) {
      this.chapter = ch ? {
        index: ci,
        t: ch[0],
        name: ch[1],
        meta: ch[2] || null
      } : null;
      this.fire('chapter', this.chapter);
    }
    this.updateCaption();
    this.fire('time', t);
    if (!o.jump) {
      return this.pass(prev, t);
    }
  }, ref$.pass = function(a, b){
    var d, dir, due, i$, len$, m, results$ = [];
    if (!this.playing || !this.marks.length || a === b || (this.renderMode && !this.host)) {
      return;
    }
    d = b - a;
    if (Math.abs(d) > MAX_STEP || (this.speed !== 0 && d > 0 !== this.speed > 0)) {
      return;
    }
    dir = d > 0
      ? 1
      : -1;
    due = this.marks.filter(function(m){
      if (dir > 0) {
        return a < m.t && m.t <= b;
      } else {
        return b <= m.t && m.t < a;
      }
    });
    due.sort(function(x, y){
      return dir * (x.t - y.t);
    });
    for (i$ = 0, len$ = due.length; i$ < len$; ++i$) {
      m = due[i$];
      if (in$(m.fn, this.marks.map(fn$))) {
        results$.push(m.fn({
          t: m.t,
          dir: dir
        }));
      }
    }
    return results$;
    function fn$(x){
      return x.fn;
    }
  }, ref$.at = function(t, fn){
    var m, this$ = this;
    m = {
      t: t,
      fn: fn
    };
    this.marks.push(m);
    return function(){
      return this$.marks = this$.marks.filter(function(x){
        return x !== m;
      });
    };
  }, ref$.redraw = function(){
    if (this.started && !this.encoding) {
      return this.opt.seek(this.frameT(this.t), this.state);
    }
  }, ref$.set = function(k, v){
    if (k && typeof k === 'object') {
      import$(this.state, k);
    } else {
      this.state[k] = v;
    }
    this.redraw();
    this.fire('state', this.state);
    return this;
  }, ref$.reset = function(){
    this.state = cloneState(this.opt.state);
    this.redraw();
    this.fire('state', this.state);
    return this;
  }, ref$.emit = function(name, data){
    this.fire(name, data);
    this.fire('emit', {
      name: name,
      data: data
    });
    return this;
  }, ref$.frameT = function(t){
    var c;
    c = this.opt.cover;
    if (c != null && c > 0 && !this.renderMode && !this.playing && t < 0.001) {
      return c;
    } else {
      return t;
    }
  }, ref$.updateCaption = function(){
    var t, list, act, cap, key, i$, ref$, len$, line;
    t = this.t;
    list = (this.captionLang != null && this.captionTracks[this.captionLang]) || [];
    act = list.filter(function(c){
      return c[0] <= t && t < c[1];
    });
    cap = !act.length
      ? null
      : {
        t0: act[0][0],
        t1: act[act.length - 1][1],
        text: act.map(function(c){
          return c[2];
        }).join('\n'),
        meta: act[0][3] || null,
        lang: this.captionLang
      };
    key = function(c){
      if (c) {
        return c.lang + "|" + c.t0 + "|" + c.text;
      } else {
        return '';
      }
    };
    if (key(cap) === key(this.caption)) {
      return;
    }
    this.caption = cap;
    this.el.captions.innerHTML = '';
    if (cap) {
      for (i$ = 0, len$ = (ref$ = cap.text.split('\n')).length; i$ < len$; ++i$) {
        line = ref$[i$];
        mk('lotion-caption', '', this.el.captions).textContent = line;
      }
    }
    return this.fire('caption', cap);
  }, ref$.showCaptions = function(v){
    v == null && (v = true);
    this.captionsOn = !!v;
    this.root.classList.toggle('lotion-captions-on', this.captionsOn);
    this.fire('captions', {
      on: this.captionsOn,
      lang: this.captionLang
    });
    return this;
  }, ref$.setCaptionLang = function(lang){
    if (!in$(lang, this.captionLangs)) {
      return this;
    }
    this.captionLang = lang;
    this.updateCaption();
    this.fire('captions', {
      on: this.captionsOn,
      lang: lang
    });
    return this;
  }, ref$['on'] = function(name, cb){
    var ref$, ref1$;
    ((ref1$ = (ref$ = this.handlers)[name]) != null
      ? ref1$
      : ref$[name] = []).push(cb);
    return this;
  }, ref$['off'] = function(name, cb){
    if (this.handlers[name]) {
      this.handlers[name] = this.handlers[name].filter(function(h){
        return h !== cb;
      });
    }
    return this;
  }, ref$.fire = function(name, v){
    var i$, ref$, len$, h, results$ = [];
    for (i$ = 0, len$ = (ref$ = (this.handlers[name] || []).slice()).length; i$ < len$; ++i$) {
      h = ref$[i$];
      results$.push(h(v));
    }
    return results$;
  }, ref$.tick = function(now, id){
    var wrapped, prev, nt, e, w, this$ = this;
    if (!this.playing || this.host || id !== this.clock) {
      return;
    }
    wrapped = false;
    if (this.last != null) {
      prev = this.t;
      nt = prev + this.speed * (now - this.last) / 1000;
      e = this.edge(prev, nt);
      this._seek(e != null ? e : nt);
      if (!this.playing || id !== this.clock) {
        return;
      }
      if ((w = this.wrap(prev, nt)) != null) {
        this._seek(w, {
          jump: true
        });
        wrapped = true;
      }
    }
    this.last = now;
    if (!wrapped && ((this.speed > 0 && this.t >= this.duration) || (this.speed < 0 && this.t <= 0))) {
      this._play(false);
      return;
    }
    return requestAnimationFrame(function(n){
      return this$.tick(n, id);
    });
  }, ref$.loopRange = function(){
    return this.span || (this.opt.loop && this.duration > 0 ? [0, this.duration] : null);
  }, ref$.edge = function(prev, nt){
    var r, a, b;
    if (!(r = this.loopRange())) {
      return null;
    }
    a = r[0], b = r[1];
    if (nt > prev && prev <= b && nt >= b) {
      return b;
    } else if (nt < prev && prev >= a && nt <= a) {
      return a;
    } else {
      return null;
    }
  }, ref$.wrap = function(prev, nt){
    var e, ref$, a, b, len;
    if ((e = this.edge(prev, nt)) == null) {
      return null;
    }
    ref$ = this.loopRange(), a = ref$[0], b = ref$[1];
    len = b - a;
    if (nt > prev) {
      return a + (nt - b) % len;
    } else {
      return b - (a - nt) % len;
    }
  }, ref$.play = function(go){
    go == null && (go = true);
    if (this.host) {
      if (go) {
        this.host.play();
      } else {
        this.host.pause();
      }
      return this;
    }
    this._play(go);
    return this;
  }, ref$.pause = function(){
    return this.play(false);
  }, ref$.toggle = function(){
    return this.play(!this.playing);
  }, ref$._play = function(go){
    var was, id, this$ = this;
    go == null && (go = true);
    if (!this.started || this.encoding) {
      return;
    }
    go = !!go;
    if (go && this.speed >= 0 && this.t >= this.duration) {
      this._seek(0, {
        jump: true
      });
    }
    if (go && this.speed < 0 && this.t <= 0) {
      if (this.loopRange()) {
        this._seek(this.loopRange()[1], {
          jump: true
        });
      } else {
        go = false;
      }
    }
    was = this.playing;
    this.playing = go;
    this.last = null;
    this._seek(this.t, {
      jump: true
    });
    if (go !== was) {
      this.fire(go ? 'play' : 'pause');
    }
    if (go && !was && !this.host) {
      id = this.clock = (this.clock || 0) + 1;
      return requestAnimationFrame(function(n){
        return this$.tick(n, id);
      });
    }
  }, ref$.rate = function(r){
    if (!arguments.length) {
      return this.speed;
    }
    if (this.host) {
      this.host.rate(r);
      return this;
    }
    this._rate(r);
    return this;
  }, ref$.loop = function(a, b){
    var v;
    if (!arguments.length) {
      return this.span ? this.span.slice() : null;
    }
    v = Array.isArray(a)
      ? a
      : a != null && a !== false ? [a, b] : null;
    if (this.host) {
      this.host.loop(v ? v.slice() : null);
      return this;
    }
    this._loop(v);
    return this;
  }, ref$._loop = function(v){
    v = v && v.length === 2 ? [clamp(+v[0], 0, this.duration), clamp(+v[1], 0, this.duration)] : null;
    if (v && !(v[0] < v[1])) {
      v = null;
    }
    if (this.span + "" === v + "") {
      return;
    }
    this.span = v;
    return this.fire('loop', v ? v.slice() : null);
  }, ref$._rate = function(r){
    r = +r;
    if (!isFinite(r) || r === this.speed) {
      return;
    }
    this.speed = r;
    return this.fire('rate', r);
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
      return this$._seek(t0, {
        jump: true
      });
    };
    progress = function(v){
      bar.textContent = Math.round(v * 100) + "%";
      if (opt.progress) {
        return opt.progress(v);
      }
    };
    return encode((ref$ = import$({
      el: this.stage,
      seek: function(t){
        return this$.opt.seek(t, this$.state);
      },
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
  vttTime = function(t){
    var ms, h, m, s, pad;
    ms = Math.round(t * 1000);
    h = Math.floor(ms / 3600000);
    m = Math.floor(ms / 60000) % 60;
    s = Math.floor(ms / 1000) % 60;
    pad = function(v, n){
      n == null && (n = 2);
      return (v + "").padStart(n, '0');
    };
    return pad(h) + ":" + pad(m) + ":" + pad(s) + "." + pad(ms % 1000, 3);
  };
  vttParseTime = function(s){
    var p;
    p = s.trim().split(':');
    return p.reduce(function(a, v){
      return a * 60 + parseFloat(v);
    }, 0);
  };
  vtt = {
    parse: function(text){
      var ret, blocks, i$, len$, b, lines, i, ref$, a, z, body, meta, m, cue;
      ret = [];
      blocks = text.replace(/\r\n?/g, '\n').split(/\n{2,}/);
      for (i$ = 0, len$ = blocks.length; i$ < len$; ++i$) {
        b = blocks[i$];
        lines = b.split('\n').filter(fn$);
        i = lines.findIndex(fn1$);
        if (i < 0) {
          continue;
        }
        ref$ = lines[i].split('-->'), a = ref$[0], z = ref$[1];
        body = lines.slice(i + 1).join('\n');
        meta = null;
        if (m = /^<v(?:\.[^\s>]*)?\s+([^>]+)>/.exec(body)) {
          meta = {
            speaker: m[1].trim()
          };
        }
        body = body.replace(/<\/?[^>]+>/g, '').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
        cue = [vttParseTime(a), vttParseTime(z.trim().split(/\s+/)[0]), body];
        if (meta) {
          cue.push(meta);
        }
        ret.push(cue);
      }
      return ret;
      function fn$(l){
        return l.trim();
      }
      function fn1$(l){
        return /-->/.test(l);
      }
    },
    stringify: function(captions){
      var esc, cues;
      esc = function(s){
        return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
      };
      cues = captions.map(function(arg$){
        var t0, t1, text, meta, body;
        t0 = arg$[0], t1 = arg$[1], text = arg$[2], meta = arg$[3];
        body = esc(text);
        if (meta && meta.speaker) {
          body = "<v " + esc(meta.speaker) + ">" + body;
        }
        return vttTime(t0) + " --> " + vttTime(t1) + "\n" + body;
      });
      return "WEBVTT\n\n" + cues.join('\n\n') + '\n';
    }
  };
  doc = {
    draft: function(opt){
      var c, tracks, lang, ref$, caps, dur, num, q, fm, chs, parts, out, i$, len$, p, range, says, j$, len1$;
      opt == null && (opt = {});
      c = opt.captions;
      tracks = !c
        ? {}
        : Array.isArray(c) ? {
          '': c
        } : c;
      lang = (ref$ = matchLang(opt.lang, Object.keys(tracks))) != null
        ? ref$
        : Object.keys(tracks)[0];
      caps = (lang != null
        ? tracks[lang]
        : []).slice().sort(function(a, b){
        return a[0] - b[0];
      });
      dur = opt.duration;
      num = function(v){
        return +(+v).toFixed(2);
      };
      q = function(v){
        return JSON.stringify(v + "");
      };
      fm = ['---', 'lotion: 1'];
      if (opt.title) {
        fm.push("title: " + q(opt.title));
      }
      if (opt.lang || lang) {
        fm.push("lang: " + (opt.lang || lang));
      }
      if (dur) {
        fm.push('kind: linear', "duration: " + num(dur));
      }
      fm.push('---', '');
      chs = (opt.chapters || []).slice().sort(function(a, b){
        return a[0] - b[0];
      });
      parts = chs.length
        ? chs.map(function(ch, i){
          var ref$, ref1$;
          return {
            name: ch[1],
            t0: ch[0],
            t1: (ref$ = (ref1$ = chs[i + 1]) != null ? ref1$[0] : void 8) != null ? ref$ : dur,
            meta: ch[2]
          };
        })
        : [{
          name: opt.title || 'content',
          t0: 0,
          t1: dur
        }];
      out = fm;
      for (i$ = 0, len$ = parts.length; i$ < len$; ++i$) {
        p = parts[i$];
        range = p.t1 != null
          ? " {t=" + num(p.t0) + "-" + num(p.t1) + "}"
          : " {t=" + num(p.t0) + "-}";
        out.push("## " + p.name + range, '');
        if (p.meta && p.meta.description) {
          out.push(p.meta.description, '');
        }
        says = caps.filter(fn$);
        for (j$ = 0, len1$ = says.length; j$ < len1$; ++j$) {
          c = says[j$];
          out.push("- say: " + c[2].replace(/\n/g, ' '));
        }
        if (says.length) {
          out.push('');
        }
      }
      return out.join('\n');
      function fn$(c){
        return c[0] >= p.t0 && (p.t1 == null || c[0] < p.t1);
      }
    }
  };
  lotion = {
    doc: doc,
    vtt: vtt,
    lang: decideLang,
    t: pick,
    hit: hit,
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
  function in$(x, xs){
    var i = -1, l = xs.length >>> 0;
    while (++i < l) if (x === xs[i]) return true;
    return false;
  }
}).call(this);
