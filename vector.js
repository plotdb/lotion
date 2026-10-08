(function(){
  (function(){
    var lotion, ref$, props, skip, i$, len$, s, c, textProps, unsupported, b64Bytes, b64, svgUri, fixUri, box, svgProps, svgSrc, bakeTransform, convert, fontCache, unquote, parseRange, parseSrc, faceOf, facesInText, facesInSheet, allFaces, getFaces, loadFont, hb, getHb, WGHT, subset, clamp, weightRank, fontsFor, render, vector;
    lotion = window.lotion;
    ref$ = lotion.libs;
    ref$.satori = 'https://cdn.jsdelivr.net/npm/satori@0.36.0/+esm';
    ref$.woff2 = 'https://cdn.jsdelivr.net/npm/woff2-encoder@2.0.0/dist/decompress.js';
    ref$.hbsubset = 'https://cdn.jsdelivr.net/npm/harfbuzzjs@1.6.3/dist/harfbuzz-subset.wasm';
    props = ['color', 'fontFamily', 'fontSize', 'fontWeight', 'fontStyle', 'lineHeight', 'letterSpacing', 'textAlign', 'whiteSpace', 'wordBreak', 'textTransform', 'textShadow', 'textIndent', 'backgroundColor', 'backgroundImage', 'backgroundPosition', 'backgroundSize', 'backgroundRepeat', 'backgroundClip', 'borderTopWidth', 'borderRightWidth', 'borderBottomWidth', 'borderLeftWidth', 'borderTopStyle', 'borderRightStyle', 'borderBottomStyle', 'borderLeftStyle', 'borderTopColor', 'borderRightColor', 'borderBottomColor', 'borderLeftColor', 'borderTopLeftRadius', 'borderTopRightRadius', 'borderBottomRightRadius', 'borderBottomLeftRadius', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft', 'boxShadow', 'opacity', 'filter', 'clipPath', 'overflow', 'zIndex', 'transform', 'transformOrigin', 'maskImage', 'maskPosition', 'maskSize', 'maskRepeat'];
    skip = {
      textShadow: 'none',
      textIndent: '0px',
      textTransform: 'none',
      backgroundColor: 'rgba(0, 0, 0, 0)',
      backgroundImage: 'none',
      backgroundPosition: '0% 0%',
      backgroundSize: 'auto',
      backgroundRepeat: 'repeat',
      backgroundClip: 'border-box',
      boxShadow: 'none',
      opacity: '1',
      filter: 'none',
      clipPath: 'none',
      overflow: 'visible',
      zIndex: 'auto',
      transform: 'none',
      maskImage: 'none',
      maskPosition: '0% 0%',
      maskSize: 'auto',
      maskRepeat: 'repeat',
      lineHeight: 'normal',
      letterSpacing: 'normal'
    };
    for (i$ = 0, len$ = (ref$ = ['Top', 'Right', 'Bottom', 'Left']).length; i$ < len$; ++i$) {
      s = ref$[i$];
      skip["border" + s + "Width"] = '0px';
      skip["border" + s + "Style"] = 'none';
      skip["padding" + s] = '0px';
    }
    for (i$ = 0, len$ = (ref$ = ['TopLeft', 'TopRight', 'BottomRight', 'BottomLeft']).length; i$ < len$; ++i$) {
      c = ref$[i$];
      skip["border" + c + "Radius"] = '0px';
    }
    textProps = ['color', 'fontFamily', 'fontSize', 'fontWeight', 'fontStyle', 'lineHeight', 'letterSpacing', 'textAlign', 'whiteSpace', 'wordBreak', 'textTransform', 'textShadow', 'textIndent'];
    unsupported = {
      backdropFilter: 'none',
      textDecorationLine: 'none'
    };
    b64Bytes = function(buf){
      var bytes, bin, i$, to$, i;
      bytes = new Uint8Array(buf);
      bin = '';
      for (i$ = 0, to$ = bytes.length; i$ < to$; i$ += 0x8000) {
        i = i$;
        bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
      }
      return btoa(bin);
    };
    b64 = function(str){
      return b64Bytes(new TextEncoder().encode(str));
    };
    svgUri = function(xml){
      return "data:image/svg+xml;base64," + b64(xml);
    };
    fixUri = function(v){
      return v.replace(/url\("data:image\/svg\+xml(?:;charset=[^,;]+)?(?:;utf8)?,([^"]*)"\)/g, function(m, d){
        var e;
        return "url(\"" + svgUri((function(){
          try {
            return decodeURIComponent(d);
          } catch (e$) {
            e = e$;
            return d;
          }
        }())) + "\")";
      });
    };
    box = function(el, parent, cs, ctx){
      var x, y, ref$, w, h;
      if (el.offsetWidth != null) {
        x = el.offsetLeft;
        y = el.offsetTop;
        if (el.offsetParent !== parent && parent.offsetParent === el.offsetParent) {
          x -= parent.offsetLeft + parent.clientLeft;
          y -= parent.offsetTop + parent.clientTop;
        }
        return [x, y, el.offsetWidth, el.offsetHeight];
      }
      ref$ = [parseFloat(cs.width) || 0, parseFloat(cs.height) || 0], w = ref$[0], h = ref$[1];
      if ((ref$ = cs.position) === 'absolute' || ref$ === 'fixed') {
        return [parseFloat(cs.left) || 0, parseFloat(cs.top) || 0, w, h];
      }
      ctx.warn("<" + el.tagName.toLowerCase() + "> not absolutely positioned: placed at its parent's origin");
      return [0, 0, w, h];
    };
    svgProps = ['font-family', 'font-size', 'font-weight', 'font-style', 'letter-spacing', 'text-anchor', 'dominant-baseline', 'fill', 'fill-opacity', 'fill-rule', 'stroke', 'stroke-width', 'stroke-opacity', 'stroke-dasharray', 'stroke-dashoffset', 'stroke-linecap', 'stroke-linejoin', 'paint-order', 'opacity', 'visibility', 'display', 'filter', 'mask', 'clip-path', 'color'];
    svgSrc = function(el, w, h, ctx, node){
      var c, srcs, dsts, texts, ids, i$, len$, d, j$, ref$, len1$, a, re, m, defs;
      c = el.cloneNode(true);
      c.setAttribute('width', w);
      c.setAttribute('height', h);
      if (!c.getAttribute('viewBox')) {
        c.setAttribute('viewBox', "0 0 " + w + " " + h);
      }
      c.removeAttribute('style');
      srcs = [el].concat(Array.from(el.querySelectorAll('*')));
      dsts = [c].concat(Array.from(c.querySelectorAll('*')));
      texts = [];
      srcs.map(function(e, i){
        var d, cs, pcs, decl, i$, ref$, len$, k, v, f;
        d = dsts[i];
        cs = getComputedStyle(e);
        pcs = i === 0
          ? null
          : getComputedStyle(e.parentNode);
        decl = [];
        for (i$ = 0, len$ = (ref$ = svgProps).length; i$ < len$; ++i$) {
          k = ref$[i$];
          v = cs.getPropertyValue(k);
          if (pcs && pcs.getPropertyValue(k) === v) {
            continue;
          }
          if (i === 0 && (k === 'opacity' || k === 'visibility' || k === 'display' || k === 'filter' || k === 'mask' || k === 'clip-path')) {
            continue;
          }
          decl.push(k + ":" + v);
        }
        if (decl.length) {
          d.setAttribute('style', decl.join(';'));
        }
        if (((ref$ = e.tagName.toLowerCase()) === 'text' || ref$ === 'tspan' || ref$ === 'textpath') && !e.querySelector('tspan, textPath')) {
          f = {};
          ctx.text(cs, e.textContent, f);
          return texts.push([d, f]);
        }
      });
      ids = new Set;
      for (i$ = 0, len$ = dsts.length; i$ < len$; ++i$) {
        d = dsts[i$];
        for (j$ = 0, len1$ = (ref$ = Array.from(d.attributes)).length; j$ < len1$; ++j$) {
          a = ref$[j$];
          re = /url\(\s*['"]?#([^'")\s]+)['"]?\s*\)|^#(.+)$/g;
          while (m = re.exec(a.value)) {
            ids.add(m[1] || m[2]);
          }
        }
      }
      defs = null;
      ids.forEach(function(id){
        var src;
        if (c.querySelector("[id=\"" + CSS.escape(id) + "\"]")) {
          return;
        }
        if (!(src = document.getElementById(id))) {
          return;
        }
        if (!defs) {
          defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
          c.insertBefore(defs, c.firstChild);
        }
        return defs.appendChild(src.cloneNode(true));
      });
      ctx.later(function(fonts){
        var names, i$, ref$, len$, ref1$, d, f, st, j$, len1$, n, faces;
        names = new Set;
        for (i$ = 0, len$ = (ref$ = texts).length; i$ < len$; ++i$) {
          ref1$ = ref$[i$], d = ref1$[0], f = ref1$[1];
          if (!f.fontFamily) {
            continue;
          }
          st = d.getAttribute('style') || '';
          d.setAttribute('style', st + ";font-family:" + f.fontFamily);
          for (j$ = 0, len1$ = (ref1$ = f.fontFamily.split(',')).length; j$ < len1$; ++j$) {
            n = ref1$[j$];
            names.add(n.trim().replace(/'/g, ''));
          }
        }
        faces = fonts.filter(function(it){
          return names.has(it.name);
        }).map(function(f){
          return ("@font-face{font-family:'" + f.name + "';font-weight:" + f.weight + ";font-style:" + f.style + ";") + ("src:url(data:font/ttf;base64," + b64Bytes(f.data) + ") format('truetype')}");
        });
        if (faces.length) {
          st = document.createElementNS('http://www.w3.org/2000/svg', 'style');
          st.textContent = faces.join('');
          c.insertBefore(st, c.firstChild);
        }
        return node.props.src = svgUri(new XMLSerializer().serializeToString(c));
      });
      return '';
    };
    bakeTransform = function(node, ctx){
      var st, m, v;
      st = node.props.style;
      if (!(st.maskImage || st.clipPath)) {
        return node;
      }
      if (!st.transform) {
        return node;
      }
      m = /^matrix\(([^)]+)\)$/.exec(st.transform);
      v = m ? m[1].split(',').map(function(it){
        return +it;
      }) : null;
      if (v && v[0] === 1 && v[1] === 0 && v[2] === 0 && v[3] === 1) {
        st.left += v[4];
        st.top += v[5];
        delete st.transform;
        delete st.transformOrigin;
      } else {
        ctx.warn("mask / clip-path with a non-translation transform: misplaced");
      }
      return node;
    };
    convert = function(el, ctx, depth){
      var root, cs, tag, ref$, x, y, w, h, hidden, k, v, blend, kids, texts, elems, style, i$, len$, s, node, children, text, jc, c, that;
      depth == null && (depth = 0);
      root = depth === 0;
      cs = getComputedStyle(el);
      if (cs.display === 'none' || +cs.opacity === 0) {
        return null;
      }
      tag = el.tagName.toLowerCase();
      ref$ = box(el, el.parentNode, cs, ctx), x = ref$[0], y = ref$[1], w = ref$[2], h = ref$[3];
      hidden = cs.visibility !== 'visible';
      for (k in ref$ = unsupported) {
        v = ref$[k];
        if (cs[k] && cs[k] !== v) {
          ctx.warn(k + ": " + cs[k]);
        }
      }
      blend = cs.mixBlendMode !== 'normal' ? cs.mixBlendMode : null;
      if (blend && depth !== 1) {
        ctx.warn("mixBlendMode on a nested element: " + blend + " ignored");
      }
      kids = Array.from(el.childNodes);
      texts = kids.filter(function(n){
        return n.nodeType === 3 && n.textContent.trim();
      });
      elems = kids.filter(function(n){
        return n.nodeType === 1;
      });
      if (texts.length && elems.length) {
        ctx.warn("mixed text and elements in <" + tag + ">");
      }
      style = {
        display: 'flex',
        boxSizing: 'border-box',
        width: w,
        height: h
      };
      if (!root) {
        style.position = 'absolute';
        style.left = x;
        style.top = y;
      }
      for (i$ = 0, len$ = (ref$ = props).length; i$ < len$; ++i$) {
        k = ref$[i$];
        if (!texts.length && in$(k, textProps)) {
          continue;
        }
        v = cs[k];
        if (!v || skip[k] === v) {
          continue;
        }
        style[k] = /data:image\/svg/.test(v) ? fixUri(v) : v;
      }
      for (i$ = 0, len$ = (ref$ = ['Top', 'Right', 'Bottom', 'Left']).length; i$ < len$; ++i$) {
        s = ref$[i$];
        if (!style["border" + s + "Width"]) {
          delete style["border" + s + "Color"];
        }
      }
      if (style.overflow) {
        style.overflow = 'hidden';
      }
      if (style.transform) {
        style.transformOrigin = cs.transformOrigin;
      } else {
        delete style.transformOrigin;
      }
      if (hidden) {
        for (i$ = 0, len$ = (ref$ = ['backgroundColor', 'backgroundImage', 'boxShadow', 'color', 'textShadow']).length; i$ < len$; ++i$) {
          k = ref$[i$];
          delete style[k];
        }
        for (i$ = 0, len$ = (ref$ = ['Top', 'Right', 'Bottom', 'Left']).length; i$ < len$; ++i$) {
          s = ref$[i$];
          delete style["border" + s + "Width"];
        }
      }
      if (tag === 'img' || tag === 'canvas' || tag === 'svg') {
        if (hidden) {
          return null;
        }
        node = {
          blend: depth === 1 ? blend : null,
          type: 'img',
          props: {
            width: w,
            height: h,
            style: style
          }
        };
        node.props.src = (function(){
          switch (tag) {
          case 'img':
            return el.currentSrc || el.src;
          case 'canvas':
            return el.toDataURL();
          case 'svg':
            return svgSrc(el, w, h, ctx, node);
          }
        }());
        return bakeTransform(node, ctx);
      }
      children = [];
      if (texts.length && !hidden) {
        text = texts.map(function(it){
          return it.textContent;
        }).join('');
        ctx.text(cs, text, style);
        children.push(text);
        jc = {
          center: 'center',
          right: 'flex-end',
          end: 'flex-end'
        }[cs.textAlign];
        if (jc && !elems.length) {
          style.justifyContent = jc;
        }
      }
      for (i$ = 0, len$ = elems.length; i$ < len$; ++i$) {
        c = elems[i$];
        if (that = convert(c, ctx, depth + 1)) {
          children.push(that);
        }
      }
      node = {
        type: 'div',
        props: {
          style: style,
          children: children
        }
      };
      if (blend && depth === 1) {
        node.blend = blend;
      }
      return bakeTransform(node, ctx);
    };
    fontCache = {};
    unquote = function(s){
      return s.trim().replace(/^["']|["']$/g, '');
    };
    parseRange = function(s){
      if (!s) {
        return [[0, 0x10FFFF]];
      }
      return s.split(',').map(function(r){
        var ref$, a, b;
        r = r.trim().replace(/^u\+/i, '');
        if (/\?/.test(r)) {
          return [parseInt(r.replace(/\?/g, '0'), 16), parseInt(r.replace(/\?/g, 'F'), 16)];
        }
        ref$ = r.split('-'), a = ref$[0], b = ref$[1];
        return [parseInt(a, 16), parseInt(b || a, 16)];
      });
    };
    parseSrc = function(s, base){
      var ret, re, m;
      ret = [];
      re = /url\(\s*(['"]?)([^'")]+)\1\s*\)\s*(?:format\(\s*['"]?([^'")]+)['"]?\s*\))?/g;
      while (m = re.exec(s)) {
        try {
          ret.push({
            url: new URL(m[2], base).href,
            format: (m[3] || m[2].split('.').pop()).toLowerCase()
          });
        } catch (e$) {}
      }
      return ret;
    };
    faceOf = function(get, base){
      return {
        family: unquote(get('font-family')),
        weight: (get('font-weight') || '400').split(/\s+/).map(function(it){
          if (it === 'normal') {
            return 400;
          } else if (it === 'bold') {
            return 700;
          } else {
            return +it;
          }
        }),
        style: get('font-style') || 'normal',
        range: parseRange(get('unicode-range')),
        src: parseSrc(get('src'), base)
      };
    };
    facesInText = function(text, base){
      return (text.match(/@font-face\s*\{[^}]*\}/g) || []).map(function(b){
        return faceOf(function(k){
          return (new RegExp("(?:^|[{;\\s])" + k + "\\s*:\\s*([^;}]+)").exec(b) || [])[1];
        }, base);
      });
    };
    facesInSheet = function(sheet){
      var base, rules, e;
      base = sheet.href || location.href;
      try {
        rules = sheet.cssRules;
      } catch (e$) {
        e = e$;
        rules = null;
      }
      if (!rules) {
        return sheet.href
          ? fetch(sheet.href).then(function(r){
            return r.text();
          }).then(function(t){
            return facesInText(t, base);
          })['catch'](function(){
            return [];
          })
          : Promise.resolve([]);
      }
      return Promise.all(Array.from(rules).map(function(r){
        if (r.styleSheet) {
          return facesInSheet(r.styleSheet);
        }
        if (r.type === 5) {
          return [faceOf(function(k){
            return r.style.getPropertyValue(k);
          }, base)];
        }
        return [];
      })).then(function(l){
        return l.flat();
      });
    };
    allFaces = null;
    getFaces = function(){
      var allFaces;
      return allFaces != null
        ? allFaces
        : allFaces = Promise.all(Array.from(document.styleSheets).map(facesInSheet)).then(function(l){
          return l.flat();
        });
    };
    loadFont = function(src){
      var pick, key$, ref$;
      pick = src.find(function(it){
        var ref$;
        return (ref$ = it.format) === 'truetype' || ref$ === 'opentype' || ref$ === 'woff' || ref$ === 'ttf' || ref$ === 'otf';
      }) || src.find(function(it){
        return it.format === 'woff2';
      });
      if (!pick) {
        return Promise.resolve(null);
      }
      return (ref$ = fontCache[key$ = pick.url]) != null
        ? ref$
        : fontCache[key$] = fetch(pick.url).then(function(r){
          return r.arrayBuffer();
        }).then(function(buf){
          if (pick.format !== 'woff2') {
            return buf;
          }
          return lotion.lib('woff2').then(function(m){
            var decompress;
            decompress = m.decompress || m['default'];
            return decompress(buf);
          }).then(function(u8){
            return u8.buffer.slice(u8.byteOffset, u8.byteOffset + u8.byteLength);
          });
        });
    };
    hb = null;
    getHb = function(){
      var hb;
      return hb != null
        ? hb
        : hb = fetch(lotion.libs.hbsubset).then(function(r){
          return r.arrayBuffer();
        }).then(function(b){
          return WebAssembly.instantiate(b, {});
        }).then(function(arg$){
          var instance, e;
          instance = arg$.instance;
          e = instance.exports;
          if (e._initialize) {
            e._initialize();
          }
          return e;
        });
    };
    WGHT = 0x77676874;
    subset = function(buf, weight, cps){
      return getHb().then(function(e){
        var n, p, blob, face, input, us, i$, ref$, len$, c, sub, ret, rb, d;
        n = buf.byteLength;
        p = e.malloc(n);
        new Uint8Array(e.memory.buffer).set(new Uint8Array(buf), p);
        blob = e.hb_blob_create(p, n, 1, 0, 0);
        face = e.hb_face_create(blob, 0);
        e.hb_blob_destroy(blob);
        input = e.hb_subset_input_create_or_fail();
        us = e.hb_subset_input_unicode_set(input);
        for (i$ = 0, len$ = (ref$ = cps).length; i$ < len$; ++i$) {
          c = ref$[i$];
          e.hb_set_add(us, c);
        }
        e.hb_subset_input_pin_axis_location(input, face, WGHT, weight);
        sub = e.hb_subset_or_fail(face, input);
        e.hb_subset_input_destroy(input);
        ret = null;
        if (sub) {
          rb = e.hb_face_reference_blob(sub);
          d = e.hb_blob_get_data(rb, 0);
          ret = new Uint8Array(e.memory.buffer).slice(d, d + e.hb_blob_get_length(rb)).buffer;
          e.hb_blob_destroy(rb);
          e.hb_face_destroy(sub);
        }
        e.hb_face_destroy(face);
        e.free(p);
        return ret;
      });
    };
    clamp = function(v, a, b){
      return Math.min(b, Math.max(a, v));
    };
    weightRank = function(f, w){
      var ref$, a, b;
      ref$ = [f.weight[0], f.weight[1] || f.weight[0]], a = ref$[0], b = ref$[1];
      if (w >= a && w <= b) {
        return 0;
      }
      if (w > 500) {
        return a > w
          ? a - w
          : 1000 + w - b;
      }
      if (w < 400) {
        return b < w
          ? w - b
          : 1000 + a - w;
      }
      if (a > w && a <= 500) {
        return a - w;
      } else if (b < w) {
        return 1000 + w - b;
      } else {
        return 2000 + a - w;
      }
    };
    fontsFor = function(used, ctx){
      return getFaces().then(function(faces){
        var groups, missing, nGroup, key, ref$, u, i$, ref1$, len$, c, cp, f, j$, ref2$, len1$, fam, cand, same, pin, gk, g, k, v;
        groups = {};
        missing = 0;
        nGroup = 0;
        for (key in ref$ = used) {
          u = ref$[key];
          u.names = [];
          for (i$ = 0, len$ = (ref1$ = Array.from(u.chars)).length; i$ < len$; ++i$) {
            c = ref1$[i$];
            cp = c.codePointAt(0);
            if (cp < 33) {
              continue;
            }
            f = null;
            for (j$ = 0, len1$ = (ref2$ = u.families).length; j$ < len1$; ++j$) {
              fam = ref2$[j$];
              cand = faces.filter(fn$);
              if (!cand.length) {
                continue;
              }
              same = cand.filter(fn1$);
              if (same.length) {
                cand = same;
              }
              f = cand.reduce(fn2$);
              break;
            }
            if (!f) {
              missing++;
              continue;
            }
            pin = clamp(u.weight, f.weight[0], f.weight[1] || f.weight[0]);
            gk = f.src[0].url + "|" + u.weight + "|" + u.style;
            g = (ref2$ = groups[gk]) != null
              ? ref2$
              : groups[gk] = {
                name: "lotion-font-" + (nGroup++),
                face: f,
                weight: u.weight,
                pin: pin,
                style: u.style,
                cps: new Set([32])
              };
            g.cps.add(cp);
            if (!in$(g.name, u.names)) {
              u.names.push(g.name);
            }
          }
        }
        if (missing) {
          ctx.warn(missing + " characters have no web font ( system fonts are not available to satori )");
        }
        return Promise.all((function(){
          var ref$, results$ = [];
          for (k in ref$ = groups) {
            v = ref$[k];
            results$.push(v);
          }
          return results$;
        }()).map(function(g){
          return loadFont(g.face.src).then(function(buf){
            if (!buf) {
              return null;
            }
            return subset(buf, g.pin, Array.from(g.cps)).then(function(data){
              if (!data) {
                ctx.warn("font " + g.face.family + ": subset failed");
                return null;
              }
              return {
                name: g.name,
                data: data,
                weight: g.weight,
                style: g.style
              };
            });
          });
        })).then(function(l){
          return l.filter(function(it){
            return it;
          });
        });
        function fn$(f){
          return f.family === fam && f.src.length && f.range.some(function(r){
            return cp >= r[0] && cp <= r[1];
          });
        }
        function fn1$(f){
          return f.style === u.style;
        }
        function fn2$(a, b){
          if (weightRank(b, u.weight) < weightRank(a, u.weight)) {
            return b;
          } else {
            return a;
          }
        }
      });
    };
    render = function(satori, tree, o){
      var kids, segs, i$, len$, k, bare;
      kids = tree.props.children;
      if (!kids.some(function(it){
        return it.blend;
      })) {
        return satori(tree, o);
      }
      segs = [{
        kids: []
      }];
      for (i$ = 0, len$ = kids.length; i$ < len$; ++i$) {
        k = kids[i$];
        if (k.blend) {
          segs.push({
            blend: k.blend,
            kids: [k]
          });
        } else if (segs[segs.length - 1].blend) {
          segs.push({
            kids: [k]
          });
        } else {
          segs[segs.length - 1].kids.push(k);
        }
      }
      bare = {
        display: 'flex',
        width: o.width,
        height: o.height,
        overflow: 'hidden'
      };
      return Promise.all(segs.map(function(g, i){
        return satori({
          type: 'div',
          props: {
            style: i === 0 ? tree.props.style : bare,
            children: g.kids
          }
        }, o).then(function(svg){
          var inner;
          inner = svg.replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '').replace(/satori_/g, "satori_" + i + "_");
          if (g.blend) {
            return "<g style=\"mix-blend-mode:" + g.blend + "\">" + inner + "</g>";
          } else {
            return "<g>" + inner + "</g>";
          }
        });
      })).then(function(layers){
        return "<svg width=\"" + o.width + "\" height=\"" + o.height + "\" viewBox=\"0 0 " + o.width + " " + o.height + "\" xmlns=\"http://www.w3.org/2000/svg\">" + layers.join('') + "</svg>";
      });
    };
    vector = function(el, opt){
      var warns, used, laters, ctx, tree, w, h, ref$, that;
      opt == null && (opt = {});
      warns = {};
      used = {};
      laters = [];
      ctx = {
        warn: function(m){
          return warns[m] = (warns[m] || 0) + 1;
        },
        later: function(f){
          return laters.push(f);
        },
        text: function(cs, text, style){
          var weight, key, u, ref$, i$, len$, c;
          weight = +cs.fontWeight || 400;
          key = cs.fontFamily + "|" + weight + "|" + cs.fontStyle;
          u = (ref$ = used[key]) != null
            ? ref$
            : used[key] = {
              families: cs.fontFamily.split(',').map(unquote),
              weight: weight,
              style: cs.fontStyle,
              chars: new Set,
              styles: []
            };
          for (i$ = 0, len$ = (ref$ = Array.from(text)).length; i$ < len$; ++i$) {
            c = ref$[i$];
            u.chars.add(c);
          }
          return u.styles.push(style);
        }
      };
      tree = convert(el, ctx);
      w = opt.width || el.offsetWidth;
      h = opt.height || el.offsetHeight;
      ref$ = tree.props.style;
      ref$.width = w;
      ref$.height = h;
      ref$.overflow = 'hidden';
      delete tree.props.style.transform;
      delete tree.props.style.transformOrigin;
      return Promise.all([
        (that = opt.satori)
          ? Promise.resolve(that)
          : lotion.lib('satori'), (that = opt.fonts)
          ? Promise.resolve(that)
          : fontsFor(used, ctx)
      ]).then(function(arg$){
        var m, fonts, k, ref$, u, i$, ref1$, len$, s, f, satori;
        m = arg$[0], fonts = arg$[1];
        if (!opt.fonts) {
          for (k in ref$ = used) {
            u = ref$[k];
            for (i$ = 0, len$ = (ref1$ = u.styles).length; i$ < len$; ++i$) {
              s = ref1$[i$];
              s.fontFamily = u.names.map(fn$).join(', ');
            }
          }
        }
        for (i$ = 0, len$ = (ref$ = laters).length; i$ < len$; ++i$) {
          f = ref$[i$];
          f(fonts);
        }
        satori = m['default'] || m.satori || m;
        return render(satori, tree, {
          width: w,
          height: h,
          fonts: fonts
        });
        function fn$(it){
          return "'" + it + "'";
        }
      }).then(function(svg){
        var k, v;
        return {
          svg: svg,
          warnings: (function(){
            var ref$, results$ = [];
            for (k in ref$ = warns) {
              v = ref$[k];
              results$.push(k + (v > 1 ? " ( x" + v + " )" : ''));
            }
            return results$;
          }())
        };
      });
    };
    lotion.vector = vector;
    return lotion.player.prototype.vector = function(t, opt){
      var this$ = this;
      opt == null && (opt = {});
      if (t != null) {
        this.opt.seek(t);
      }
      return vector(this.stage, opt).then(function(r){
        if (t != null) {
          this$.opt.seek(this$.t);
        }
        return r;
      });
    };
  })();
  function in$(x, xs){
    var i = -1, l = xs.length >>> 0;
    while (++i < l) if (x === xs[i]) return true;
    return false;
  }
}).call(this);
