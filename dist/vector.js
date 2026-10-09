(function(){
  (function(){
    var lotion, ref$, props, skip, i$, len$, s, c, textProps, unsupported, b64Bytes, b64, svgUri, fixShadow, fixUri, box, svgProps, svgSrc, bakeTransform, convert, fontCache, unquote, parseRange, parseSrc, faceOf, facesInText, facesInSheet, allFaces, getFaces, loadFont, hb, getHb, WGHT, subset, clamp, weightRank, fontsFor, render, makeCtx, prepare, vector, IDENT, mul, parseMatrix, motionMatrix, svgMatrix, viewboxMatrix, blurOf, simplify, fmt, pct, SVGGROUP, SVGSTATIC, NUMATTRS, NUMPROPS, LEAFSTYLE, POSATTRS, NUMERIC, xml, styleDiff, leaf, groupAttrs, splitTop, rgba, maskOf, clipOf, sample, drawOn, PAD, draw, attrTol, compose, animate;
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
    fixShadow = function(v){
      var parts, ref$, depth, cur, i$, len$, ch;
      parts = [];
      ref$ = [0, ''], depth = ref$[0], cur = ref$[1];
      for (i$ = 0, len$ = v.length; i$ < len$; ++i$) {
        ch = v[i$];
        if (ch === '(') {
          depth++;
        }
        if (ch === ')') {
          depth--;
        }
        if (ch === ',' && depth === 0) {
          parts.push(cur.trim());
          cur = '';
        } else {
          cur += ch;
        }
      }
      parts.push(cur.trim());
      return parts.map(function(p){
        var m;
        if (!(m = /^((?:rgba?|hsla?|color)\([^)]*\)|#[0-9a-f]+|[a-z]+)\s+(.*)$/i.exec(p)) || m[1] === 'inset') {
          return p;
        }
        return m[2] + " " + m[1];
      }).join(', ');
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
      return "pending:" + new XMLSerializer().serializeToString(c);
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
    convert = function(el, ctx, depth, o){
      var root, cs, tag, ref$, x, y, w, h, hidden, k, v, blend, kids, texts, elems, style, i$, len$, s, node, children, text, jc, c, that;
      depth == null && (depth = 0);
      o == null && (o = {});
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
        style[k] = /data:image\/svg/.test(v)
          ? fixUri(v)
          : k === 'boxShadow' || k === 'textShadow' ? fixShadow(v) : v;
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
        return o.nobake
          ? node
          : bakeTransform(node, ctx);
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
      if (!o.own) {
        for (i$ = 0, len$ = elems.length; i$ < len$; ++i$) {
          c = elems[i$];
          if (that = convert(c, ctx, depth + 1)) {
            children.push(that);
          }
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
      if (o.nobake) {
        return node;
      } else {
        return bakeTransform(node, ctx);
      }
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
    makeCtx = function(){
      var ctx;
      return ctx = {
        warns: {},
        used: {},
        laters: [],
        warn: function(m){
          return ctx.warns[m] = (ctx.warns[m] || 0) + 1;
        },
        later: function(f){
          return ctx.laters.push(f);
        },
        text: function(cs, text, style){
          var weight, key, u, ref$, ref1$, i$, len$, c;
          weight = +cs.fontWeight || 400;
          key = cs.fontFamily + "|" + weight + "|" + cs.fontStyle;
          u = (ref1$ = (ref$ = ctx.used)[key]) != null
            ? ref1$
            : ref$[key] = {
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
        },
        warnings: function(){
          var k, ref$, v, results$ = [];
          for (k in ref$ = ctx.warns) {
            v = ref$[k];
            results$.push(k + (v > 1 ? " ( x" + v + " )" : ''));
          }
          return results$;
        }
      };
    };
    prepare = function(ctx, opt){
      var that;
      return Promise.all([
        (that = opt.satori)
          ? Promise.resolve(that)
          : lotion.lib('satori'), (that = opt.fonts)
          ? Promise.resolve(that)
          : fontsFor(ctx.used, ctx)
      ]).then(function(arg$){
        var m, fonts, k, ref$, u, i$, ref1$, len$, s;
        m = arg$[0], fonts = arg$[1];
        if (!opt.fonts) {
          for (k in ref$ = ctx.used) {
            u = ref$[k];
            for (i$ = 0, len$ = (ref1$ = u.styles).length; i$ < len$; ++i$) {
              s = ref1$[i$];
              s.fontFamily = u.names.map(fn$).join(', ');
            }
          }
        }
        return [m['default'] || m.satori || m, fonts];
        function fn$(it){
          return "'" + it + "'";
        }
      });
    };
    vector = function(el, opt){
      var ctx, tree, w, h, ref$;
      opt == null && (opt = {});
      ctx = makeCtx();
      tree = convert(el, ctx);
      w = opt.width || el.offsetWidth;
      h = opt.height || el.offsetHeight;
      ref$ = tree.props.style;
      ref$.width = w;
      ref$.height = h;
      ref$.overflow = 'hidden';
      delete tree.props.style.transform;
      delete tree.props.style.transformOrigin;
      return prepare(ctx, opt).then(function(arg$){
        var satori, fonts, i$, ref$, len$, f;
        satori = arg$[0], fonts = arg$[1];
        for (i$ = 0, len$ = (ref$ = ctx.laters).length; i$ < len$; ++i$) {
          f = ref$[i$];
          f(fonts);
        }
        return render(satori, tree, {
          width: w,
          height: h,
          fonts: fonts
        });
      }).then(function(svg){
        return {
          svg: svg,
          warnings: ctx.warnings()
        };
      });
    };
    IDENT = [1, 0, 0, 1, 0, 0];
    mul = function(m, n){
      return [m[0] * n[0] + m[2] * n[1], m[1] * n[0] + m[3] * n[1], m[0] * n[2] + m[2] * n[3], m[1] * n[2] + m[3] * n[3], m[0] * n[4] + m[2] * n[5] + m[4], m[1] * n[4] + m[3] * n[5] + m[5]];
    };
    parseMatrix = function(v, ctx){
      var m, a;
      if (!v || v === 'none') {
        return IDENT;
      }
      if (m = /^matrix\(([^)]+)\)$/.exec(v)) {
        return m[1].split(',').map(function(it){
          return +it;
        });
      }
      if (m = /^matrix3d\(([^)]+)\)$/.exec(v)) {
        a = m[1].split(',').map(function(it){
          return +it;
        });
        ctx.warn("3d transform flattened to 2d");
        return [a[0], a[1], a[4], a[5], a[12], a[13]];
      }
      return IDENT;
    };
    motionMatrix = function(x, y, cs, ctx){
      var m, ref$, ox, oy;
      m = parseMatrix(cs.transform, ctx);
      if (m === IDENT) {
        return [1, 0, 0, 1, x, y];
      }
      ref$ = cs.transformOrigin.split(' ').map(function(it){
        return parseFloat(it) || 0;
      }), ox = ref$[0], oy = ref$[1];
      return mul([1, 0, 0, 1, x + ox, y + oy], mul(m, [1, 0, 0, 1, -ox, -oy]));
    };
    svgMatrix = function(e, cs, ctx){
      var l, m;
      if (cs.transform !== 'none') {
        return motionMatrix(0, 0, cs, ctx);
      }
      l = e.transform && e.transform.baseVal;
      if (!(l && l.numberOfItems)) {
        return IDENT;
      }
      m = l.consolidate().matrix;
      return [m.a, m.b, m.c, m.d, m.e, m.f];
    };
    viewboxMatrix = function(e, w, h){
      var vb, ref$, sx, sy, par, s, ax, ay, dx, dy;
      vb = e.viewBox && e.viewBox.baseVal;
      if (!(vb && vb.width && vb.height)) {
        return IDENT;
      }
      ref$ = [w / vb.width, h / vb.height], sx = ref$[0], sy = ref$[1];
      par = e.preserveAspectRatio.baseVal;
      if (par.align === 1) {
        return [sx, 0, 0, sy, -vb.x * sx, -vb.y * sy];
      }
      s = par.meetOrSlice === 2
        ? Math.max(sx, sy)
        : Math.min(sx, sy);
      ax = (par.align - 2) % 3;
      ay = Math.floor((par.align - 2) / 3);
      dx = (w - vb.width * s) * ax / 2;
      dy = (h - vb.height * s) * ay / 2;
      return [s, 0, 0, s, dx - vb.x * s, dy - vb.y * s];
    };
    blurOf = function(f){
      var m;
      if (!f || f === 'none') {
        return 0;
      } else if (m = /^blur\(([\d.]+)px\)$/.exec(f)) {
        return +m[1];
      } else {
        return null;
      }
    };
    simplify = function(vals, tol){
      var n, keep, stack, ref$, a, b, worst, at, i$, i, f, j$, to$, k, e, results$ = [];
      n = vals.length;
      if (n < 3) {
        return (function(){
          var i$, to$, results$ = [];
          for (i$ = 0, to$ = n; i$ < to$; ++i$) {
            results$.push(i$);
          }
          return results$;
        }());
      }
      keep = new Uint8Array(n);
      keep[0] = keep[n - 1] = 1;
      stack = [[0, n - 1]];
      while (stack.length) {
        ref$ = stack.pop(), a = ref$[0], b = ref$[1];
        ref$ = [1, -1], worst = ref$[0], at = ref$[1];
        for (i$ = a + 1; i$ < b; ++i$) {
          i = i$;
          f = (i - a) / (b - a);
          for (j$ = 0, to$ = vals[a].length; j$ < to$; ++j$) {
            k = j$;
            e = Math.abs(vals[a][k] + (vals[b][k] - vals[a][k]) * f - vals[i][k]) / tol[k];
            if (e > worst) {
              worst = e;
              at = i;
            }
          }
        }
        if (at >= 0) {
          keep[at] = 1;
          stack.push([a, at], [at, b]);
        }
      }
      for (i$ = 0; i$ < n; ++i$) {
        i = i$;
        if (keep[i]) {
          results$.push(i);
        }
      }
      return results$;
    };
    fmt = function(v){
      return +v.toFixed(4);
    };
    pct = function(i, n){
      return (+(100 * i / n).toFixed(3)) + "%";
    };
    SVGGROUP = ['g', 'a', 'switch'];
    SVGSTATIC = ['defs', 'clippath', 'mask', 'lineargradient', 'radialgradient', 'filter', 'pattern', 'symbol', 'style', 'marker', 'title', 'desc', 'metadata'];
    NUMATTRS = ['x', 'y', 'x1', 'y1', 'x2', 'y2', 'cx', 'cy', 'r', 'rx', 'ry', 'width', 'height'];
    NUMPROPS = ['stroke-dashoffset', 'stroke-width', 'fill-opacity', 'stroke-opacity'];
    LEAFSTYLE = svgProps.filter(function(it){
      return !in$(it, NUMPROPS) && !(it === 'opacity' || it === 'visibility' || it === 'display');
    });
    POSATTRS = {
      text: ['x', 'y'],
      rect: ['x', 'y'],
      image: ['x', 'y'],
      use: ['x', 'y'],
      foreignobject: ['x', 'y'],
      circle: ['cx', 'cy'],
      ellipse: ['cx', 'cy']
    };
    NUMERIC = /^\s*-?(\d+\.?\d*|\.\d+)(e-?\d+)?\s*$/;
    xml = function(e){
      return new XMLSerializer().serializeToString(e);
    };
    styleDiff = function(e, cs){
      var pcs, decl, i$, ref$, len$, k, v;
      pcs = getComputedStyle(e.parentNode);
      decl = [];
      for (i$ = 0, len$ = (ref$ = LEAFSTYLE).length; i$ < len$; ++i$) {
        k = ref$[i$];
        v = cs.getPropertyValue(k);
        if (pcs.getPropertyValue(k) !== v) {
          decl.push(k + ":" + v);
        }
      }
      return decl.join(';');
    };
    leaf = function(e, cs, ctx){
      var tag, c, i$, ref$, len$, k, a, v, t, pos, p, d, f;
      tag = e.tagName.toLowerCase();
      c = e.cloneNode(true);
      for (i$ = 0, len$ = (ref$ = ['transform', 'opacity', 'style', 'class']).length; i$ < len$; ++i$) {
        k = ref$[i$];
        c.removeAttribute(k);
      }
      a = {};
      for (i$ = 0, len$ = (ref$ = NUMATTRS).length; i$ < len$; ++i$) {
        k = ref$[i$];
        v = e.getAttribute(k);
        if (v != null && NUMERIC.test(v)) {
          a[k] = +v;
          c.removeAttribute(k);
        }
      }
      t = null;
      if (pos = POSATTRS[tag]) {
        t = {
          x: a[pos[0]] || 0,
          y: a[pos[1]] || 0,
          keys: pos
        };
        delete a[pos[0]];
        delete a[pos[1]];
      }
      p = {};
      for (i$ = 0, len$ = (ref$ = NUMPROPS).length; i$ < len$; ++i$) {
        k = ref$[i$];
        p[k] = parseFloat(cs.getPropertyValue(k)) || 0;
        c.removeAttribute(k);
      }
      if (d = styleDiff(e, cs)) {
        c.setAttribute('style', d);
      }
      f = null;
      if (tag === 'text') {
        f = {};
        ctx.text(cs, e.textContent, f);
      }
      return {
        c: c,
        a: a,
        t: t,
        p: p,
        f: f
      };
    };
    groupAttrs = function(e, cs){
      var ret, res$, i$, ref$, len$, at, ref1$, d;
      res$ = [];
      for (i$ = 0, len$ = (ref$ = Array.from(e.attributes)).length; i$ < len$; ++i$) {
        at = ref$[i$];
        if (!((ref1$ = at.name) === 'class' || ref1$ === 'style' || ref1$ === 'transform' || ref1$ === 'opacity')) {
          res$.push(at.name + "=\"" + at.value.replace(/"/g, '&quot;') + "\"");
        }
      }
      ret = res$;
      if (d = styleDiff(e, cs)) {
        ret.push("style=\"" + d.replace(/"/g, "'") + "\"");
      }
      return ret.join(' ');
    };
    splitTop = function(str){
      var ref$, ret, depth, cur, i$, len$, ch;
      ref$ = [[], 0, ''], ret = ref$[0], depth = ref$[1], cur = ref$[2];
      for (i$ = 0, len$ = str.length; i$ < len$; ++i$) {
        ch = str[i$];
        if (ch === '(') {
          depth++;
        }
        if (ch === ')') {
          depth--;
        }
        if (ch === ',' && depth === 0) {
          ret.push(cur.trim());
          cur = '';
        } else {
          cur += ch;
        }
      }
      ret.push(cur.trim());
      return ret;
    };
    rgba = function(c){
      var m, v, ref$;
      if (!(m = /^rgba?\(([^)]*)\)$/.exec(c))) {
        return null;
      }
      v = m[1].split(/[\s,\/]+/).filter(function(it){
        return it;
      }).map(function(it){
        return parseFloat(it);
      });
      return [v[0], v[1], v[2], (ref$ = v[3]) != null ? ref$ : 1];
    };
    maskOf = function(cs, w, h){
      var m, parts, angle, a, stops, i$, len$, p, c, col, ps, j$, len1$, q, sz, ref$, len, tw, th, pos, x, y, glen, offs, i, j, k, to$, x1, y1, x2, y2, grad;
      if (!(m = /^linear-gradient\((.*)\)$/.exec(cs.maskImage))) {
        return null;
      }
      if (!/^no-repeat( no-repeat)?$/.test(cs.maskRepeat)) {
        return null;
      }
      parts = splitTop(m[1]);
      angle = 180;
      if (a = /^(-?[\d.]+)deg$/.exec(parts[0])) {
        angle = +a[1];
        parts.shift();
      } else if (/^to /.test(parts[0])) {
        angle = {
          'to top': 0,
          'to right': 90,
          'to bottom': 180,
          'to left': 270
        }[parts[0]];
        if (angle == null) {
          return null;
        }
        parts.shift();
      }
      angle = (angle % 360 + 360) % 360;
      if (angle % 90) {
        return null;
      }
      stops = [];
      for (i$ = 0, len$ = parts.length; i$ < len$; ++i$) {
        p = parts[i$];
        if (!(c = /^(rgba?\([^)]*\))\s*(.*)$/.exec(p))) {
          return null;
        }
        col = rgba(c[1]);
        ps = c[2].split(/\s+/).filter(fn$);
        if (!ps.length) {
          stops.push({
            col: col
          });
        }
        for (j$ = 0, len1$ = ps.length; j$ < len1$; ++j$) {
          q = ps[j$];
          stops.push({
            col: col,
            q: q
          });
        }
      }
      sz = cs.maskSize.split(/\s+/);
      if ((ref$ = sz[0]) === 'cover' || ref$ === 'contain') {
        return null;
      }
      len = function(v, ref){
        if (!v || v === 'auto') {
          return ref;
        } else if (/%$/.test(v)) {
          return ref * parseFloat(v) / 100;
        } else {
          return parseFloat(v);
        }
      };
      tw = len(sz[0], w);
      th = len(sz[1], h);
      ps = cs.maskPosition.split(/\s+/);
      pos = function(v, free){
        if (/%$/.test(v)) {
          return free * parseFloat(v) / 100;
        } else {
          return parseFloat(v) || 0;
        }
      };
      x = pos(ps[0], w - tw);
      y = pos(ps[1] || '0%', h - th);
      glen = angle === 90 || angle === 270 ? tw : th;
      offs = stops.map(function(s){
        if (s.q == null) {
          return null;
        } else if (/%$/.test(s.q)) {
          return parseFloat(s.q) / 100;
        } else {
          return parseFloat(s.q) / glen;
        }
      });
      if (offs[0] == null) {
        offs[0] = 0;
      }
      if (offs[offs.length - 1] == null) {
        offs[offs.length - 1] = 1;
      }
      i = 0;
      while (i < offs.length) {
        if (offs[i] != null) {
          i++;
          continue;
        }
        j = i;
        while (offs[j] == null) {
          j++;
        }
        for (i$ = i; i$ < j; ++i$) {
          k = i$;
          offs[k] = offs[i - 1] + (offs[j] - offs[i - 1]) * (k - i + 1) / (j - i + 1);
        }
        i = j;
      }
      for (i$ = 1, to$ = offs.length; i$ < to$; ++i$) {
        i = i$;
        offs[i] = Math.max(offs[i], offs[i - 1]);
      }
      ref$ = {
        90: [0, 0, 1, 0],
        270: [1, 0, 0, 0],
        180: [0, 0, 0, 1],
        0: [0, 1, 0, 0]
      }[angle], x1 = ref$[0], y1 = ref$[1], x2 = ref$[2], y2 = ref$[3];
      grad = stops.map(function(s, i){
        return "<stop offset=\"" + fmt(offs[i]) + "\" stop-color=\"rgb(" + s.col[0] + "," + s.col[1] + "," + s.col[2] + ")\" stop-opacity=\"" + s.col[3] + "\"/>";
      }).join('');
      return {
        grad: "<linearGradient x1=\"" + x1 + "\" y1=\"" + y1 + "\" x2=\"" + x2 + "\" y2=\"" + y2 + "\">" + grad + "</linearGradient>",
        rect: [x, y, tw, th],
        key: cs.maskImage
      };
      function fn$(it){
        return it;
      }
    };
    clipOf = function(cs, w, h){
      var m, v, ref$, t, r, b, l, len;
      if (!(m = /^inset\(([^)]*)\)$/.exec(cs.clipPath)) || /round/.test(m[1])) {
        return null;
      }
      v = m[1].trim().split(/\s+/);
      if (!((ref$ = v.length) === 1 || ref$ === 2 || ref$ === 3 || ref$ === 4) || v.some(function(x){
        return !/^-?[\d.]+(px|%)$/.test(x) && x !== '0';
      })) {
        return null;
      }
      ref$ = [
        v[0], (ref$ = v[1]) != null
          ? ref$
          : v[0], (ref$ = v[2]) != null
          ? ref$
          : v[0], (ref$ = v[3]) != null
          ? ref$
          : (ref$ = v[1]) != null
            ? ref$
            : v[0]
      ], t = ref$[0], r = ref$[1], b = ref$[2], l = ref$[3];
      len = function(x, ref){
        if (/%$/.test(x)) {
          return ref * parseFloat(x) / 100;
        } else {
          return parseFloat(x) || 0;
        }
      };
      ref$ = [len(t, h), len(b, h)], t = ref$[0], b = ref$[1];
      ref$ = [len(r, w), len(l, w)], r = ref$[0], l = ref$[1];
      return [l, t, Math.max(0, w - l - r), Math.max(0, h - t - b)];
    };
    sample = function(opt, ctx){
      var el, seek, n, fps, from, recs, byEl, recOf, variant, walkSvg, walk, i$, i;
      el = opt.el, seek = opt.seek, n = opt.n, fps = opt.fps, from = opt.from;
      recs = [];
      byEl = new Map;
      recOf = function(e, parent){
        var rec;
        if (rec = byEl.get(e)) {
          return rec;
        }
        rec = {
          id: recs.length,
          el: e,
          parent: parent,
          kids: [],
          variants: [],
          keys: new Map,
          frames: []
        };
        recs.push(rec);
        byEl.set(e, rec);
        if (parent) {
          parent.kids.push(rec);
        }
        return rec;
      };
      variant = function(rec, sig, make){
        var v;
        v = rec.keys.get(sig);
        if (v == null) {
          v = rec.variants.length;
          rec.keys.set(sig, v);
          rec.variants.push(make());
        }
        return v;
      };
      walkSvg = function(e, parent, i){
        var cs, tag, rec, m, o, i$, ref$, len$, c, v, a, p, r, len, drawable;
        cs = getComputedStyle(e);
        if (cs.display === 'none') {
          return;
        }
        tag = e.tagName.toLowerCase();
        rec = recOf(e, parent);
        if (in$(tag, SVGSTATIC)) {
          if (!rec.kind) {
            rec.kind = 'static';
            rec.markup = xml(e);
          } else if (xml(e) !== rec.markup) {
            ctx.warn("<" + tag + "> changes over time: only the first frame is kept");
          }
          rec.frames[i] = {
            m: IDENT,
            o: 1,
            b: 0,
            v: -1
          };
          return;
        }
        m = svgMatrix(e, cs, ctx);
        o = +cs.opacity;
        if (cs.mixBlendMode !== 'normal') {
          rec.blend = cs.mixBlendMode;
        }
        if (in$(tag, SVGGROUP)) {
          if (!rec.kind) {
            rec.kind = 'g';
            rec.attrs = groupAttrs(e, cs);
          }
          rec.frames[i] = {
            m: m,
            o: o,
            b: 0,
            v: -1
          };
          for (i$ = 0, len$ = (ref$ = Array.from(e.children)).length; i$ < len$; ++i$) {
            c = ref$[i$];
            walkSvg(c, rec, i);
          }
          return;
        }
        rec.kind = 'leaf';
        v = -1;
        a = p = null;
        if (cs.visibility === 'visible' && o > 0) {
          r = leaf(e, cs, ctx);
          a = r.a, p = r.p;
          if (r.t) {
            rec.base == null && (rec.base = r.t);
            m = mul(m, [1, 0, 0, 1, r.t.x - rec.base.x, r.t.y - rec.base.y]);
            r.c.setAttribute(r.t.keys[0], rec.base.x);
            r.c.setAttribute(r.t.keys[1], rec.base.y);
          }
          if (e.tagName.toLowerCase() === 'path') {
            len = (function(){
              try {
                return e.getTotalLength();
              } catch (e$) {
                e = e$;
                return null;
              }
            }());
            drawable = cs.fill === 'none' && cs.strokeDasharray === 'none' && cs.markerStart === 'none' && cs.markerMid === 'none' && cs.markerEnd === 'none';
          }
          v = variant(rec, xml(r.c), function(){
            return {
              c: r.c,
              f: r.f,
              d: e.getAttribute('d'),
              len: len,
              drawable: drawable
            };
          });
        }
        return rec.frames[i] = {
          m: m,
          o: o,
          b: 0,
          v: v,
          a: a,
          p: p
        };
      };
      walk = function(e, parent, i, depth){
        var cs, tag, rec, ref$, x, y, w, h, m, gmask, gclip, masked, i$, len$, c, blur, elems, hasText, atomic, v, node, st, k, laters, results$ = [];
        cs = getComputedStyle(e);
        if (cs.display === 'none') {
          return;
        }
        tag = e.tagName.toLowerCase();
        rec = recOf(e, parent);
        ref$ = box(e, e.parentNode, cs, ctx), x = ref$[0], y = ref$[1], w = ref$[2], h = ref$[3];
        m = depth === 0
          ? IDENT
          : motionMatrix(x, y, cs, ctx);
        rec.blend = cs.mixBlendMode !== 'normal' ? cs.mixBlendMode : null;
        if (cs.zIndex !== 'auto') {
          ctx.warn("z-index ignored ( dom order is used )");
        }
        gmask = cs.maskImage !== 'none' ? maskOf(cs, w, h) : null;
        if (gmask) {
          if (!rec.mask) {
            rec.mask = gmask;
          } else if (rec.mask.key !== gmask.key) {
            ctx.warn("mask image changes over time: only the first is kept");
          }
        }
        gclip = cs.clipPath !== 'none' ? clipOf(cs, w, h) : null;
        if (gclip) {
          rec.clipped = true;
        }
        masked = (cs.maskImage !== 'none' && !gmask) || (cs.clipPath !== 'none' && !gclip);
        if (tag === 'svg' && !masked) {
          if (!rec.kind) {
            rec.kind = 'svg';
            rec.vb = viewboxMatrix(e, w, h);
            rec.clip = cs.overflow === 'visible'
              ? null
              : [w, h];
            rec.style = styleDiff(e, cs);
          }
          rec.frames[i] = {
            m: m,
            o: +cs.opacity,
            b: 0,
            v: -1,
            k: gmask && gmask.rect,
            q: gclip
          };
          if (+cs.opacity > 0) {
            for (i$ = 0, len$ = (ref$ = Array.from(e.children)).length; i$ < len$; ++i$) {
              c = ref$[i$];
              walkSvg(c, rec, i);
            }
          }
          return;
        }
        blur = blurOf(cs.filter);
        elems = Array.from(e.children);
        hasText = Array.from(e.childNodes).some(function(n){
          return n.nodeType === 3 && n.textContent.trim();
        });
        atomic = (tag === 'img' || tag === 'canvas' || tag === 'svg') || masked || !(blur != null) || (hasText && elems.length);
        rec.atomic = atomic;
        if (cs.overflow !== 'visible' && !atomic && elems.length) {
          rec.clip == null && (rec.clip = [w, h]);
        }
        v = -1;
        if (cs.visibility === 'visible' && +cs.opacity > 0) {
          ctx.laters = [];
          node = convert(e, ctx, 1, {
            own: !atomic,
            nobake: true
          });
          if (node) {
            st = node.props.style;
            for (i$ = 0, len$ = (ref$ = ['position', 'left', 'top', 'transform', 'transformOrigin', 'opacity']).length; i$ < len$; ++i$) {
              k = ref$[i$];
              delete st[k];
            }
            if (blur != null) {
              delete st.filter;
            }
            if (gmask) {
              for (i$ = 0, len$ = (ref$ = ['maskImage', 'maskPosition', 'maskSize', 'maskRepeat']).length; i$ < len$; ++i$) {
                k = ref$[i$];
                delete st[k];
              }
            }
            if (gclip) {
              delete st.clipPath;
            }
            delete node.blend;
            laters = ctx.laters;
            v = variant(rec, JSON.stringify(node), function(){
              return {
                node: node,
                w: w,
                h: h,
                laters: laters
              };
            });
          }
        }
        rec.frames[i] = {
          m: m,
          o: +cs.opacity,
          b: blur || 0,
          v: v,
          k: gmask && gmask.rect,
          q: gclip
        };
        if (!atomic && +cs.opacity > 0) {
          for (i$ = 0, len$ = elems.length; i$ < len$; ++i$) {
            c = elems[i$];
            results$.push(walk(c, rec, i, depth + 1));
          }
          return results$;
        }
      };
      for (i$ = 0; i$ < n; ++i$) {
        i = i$;
        if (opt.signal && opt.signal.aborted) {
          throw new DOMException('aborted', 'AbortError');
        }
        seek(from + i / fps);
        walk(el, null, i, 0);
        if (opt.progress) {
          opt.progress(0.5 * (i + 1) / n);
        }
      }
      return recs;
    };
    drawOn = function(rec){
      var vs, order, fams, famOf, i$, len$, k, d, f, ref$, fr, ref1$, results$ = [];
      vs = rec.variants;
      if (vs.length < 2 || !vs.every(function(v){
        return v.d != null && v.len != null && v.drawable;
      })) {
        return;
      }
      order = (function(){
        var i$, to$, results$ = [];
        for (i$ = 0, to$ = vs.length; i$ < to$; ++i$) {
          results$.push(i$);
        }
        return results$;
      }()).sort(function(a, b){
        return vs[b].d.length - vs[a].d.length;
      });
      fams = [];
      famOf = [];
      for (i$ = 0, len$ = order.length; i$ < len$; ++i$) {
        k = order[i$];
        d = vs[k].d;
        f = fams.find(fn$);
        if (!f) {
          f = {
            root: k
          };
          fams.push(f);
        }
        famOf[k] = f;
      }
      if (fams.length === vs.length) {
        return;
      }
      rec.variants = fams.map(function(f, j){
        var va;
        va = vs[f.root];
        f.j = j;
        f.L = va.len + 1;
        va.c.setAttribute('stroke-dasharray', f.L + " " + f.L);
        return va;
      });
      for (i$ = 0, len$ = (ref$ = rec.frames).length; i$ < len$; ++i$) {
        fr = ref$[i$];
        if (fr && fr.v >= 0) {
          f = famOf[fr.v];
          fr.p = (ref1$ = fr.p || {}, ref1$['stroke-dashoffset'] = f.L - vs[fr.v].len, ref1$);
          results$.push(fr.v = f.j);
        }
      }
      return results$;
      function fn$(f){
        var r;
        r = vs[f.root].d;
        return r.startsWith(d) && (r.length === d.length || /[A-Za-z]/.test(r[d.length]));
      }
    };
    PAD = 64;
    draw = function(satori, fonts, rec, k, va){
      var W, H, ref$;
      W = va.w + 2 * PAD;
      H = va.h + 2 * PAD;
      ref$ = va.node.props.style;
      ref$.position = 'absolute';
      ref$.left = PAD;
      ref$.top = PAD;
      return satori({
        type: 'div',
        props: {
          style: {
            display: 'flex',
            width: W,
            height: H
          },
          children: [va.node]
        }
      }, {
        width: W,
        height: H,
        fonts: fonts
      }).then(function(svg){
        var inner;
        inner = svg.replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '').replace(/satori_/g, "s" + rec.id + "_" + k + "_");
        return "<g transform=\"translate(" + (-PAD) + "," + (-PAD) + ")\">" + inner + "</g>";
      });
    };
    attrTol = function(k){
      if (/opacity/.test(k)) {
        return 0.008;
      } else {
        return 0.05;
      }
    };
    compose = function(recs, opt, fonts){
      var n, fps, width, height, dur, css, fontNames, tail, series, rule, track, animateEl, attrsOf, maskMarkup, withMask, NOCLIP, withClip, leafMarkup, out, body, faces, style;
      n = opt.n, fps = opt.fps, width = opt.width, height = opt.height;
      dur = n / fps;
      css = [];
      fontNames = new Set;
      tail = opt.repeat ? ' infinite' : ' forwards';
      series = function(frames){
        var last, vals;
        last = frames.find(function(it){
          return it != null;
        });
        vals = frames.map(function(f){
          return last = f != null ? f : last;
        });
        if (vals.every(function(v){
          return v.every(function(x, j){
            return x === vals[0][j];
          });
        })) {
          return [vals, false];
        } else {
          return [vals, true];
        }
      };
      rule = function(cls, base, frames, prop, tol, val, step){
        var ref$, vals, varies, idx, i, kf, name;
        ref$ = series(frames), vals = ref$[0], varies = ref$[1];
        if (!varies) {
          base.push(prop + ":" + val(vals[0]));
          return;
        }
        idx = step
          ? (function(){
            var i$, to$, results$ = [];
            for (i$ = 0, to$ = n; i$ < to$; ++i$) {
              i = i$;
              if (i === 0 || vals[i].join() !== vals[i - 1].join()) {
                results$.push(i);
              }
            }
            return results$;
          }())
          : simplify(vals, tol);
        kf = idx.map(function(i){
          return pct(i, n) + "{" + prop + ":" + val(vals[i]) + "}";
        }).join('') + ("100%{" + prop + ":" + val(vals[n - 1]) + "}");
        name = cls + "-" + prop.replace(/[^a-z]/g, '');
        css.push("@keyframes " + name + "{" + kf + "}");
        base.push(prop + ":" + val(vals[0]));
        return name;
      };
      track = function(k, frames, tol){
        var ref$, vals, varies, idx, times, vs;
        ref$ = series(frames), vals = ref$[0], varies = ref$[1];
        if (!varies) {
          return [k, fmt(vals[0][0])];
        }
        idx = simplify(vals, [tol]);
        times = idx.map(function(i){
          return i / n;
        });
        vs = idx.map(function(i){
          return fmt(vals[i][0]);
        });
        if (times[times.length - 1] < 1) {
          times.push(1);
          vs.push(fmt(vals[n - 1][0]));
        }
        return [
          k, fmt(vals[0][0]), {
            times: times,
            vs: vs
          }
        ];
      };
      animateEl = function(k, anim){
        var a;
        a = document.createElementNS('http://www.w3.org/2000/svg', 'animate');
        a.setAttribute('attributeName', k);
        a.setAttribute('dur', dur + "s");
        a.setAttribute('calcMode', 'linear');
        a.setAttribute('keyTimes', anim.times.map(function(it){
          return +it.toFixed(4);
        }).join(';'));
        a.setAttribute('values', anim.vs.join(';'));
        if (opt.repeat) {
          a.setAttribute('repeatCount', 'indefinite');
        } else {
          a.setAttribute('fill', 'freeze');
        }
        return a;
      };
      attrsOf = function(rec){
        var F, keys, i$, len$, f, k, ret;
        F = rec.frames;
        keys = new Set;
        for (i$ = 0, len$ = F.length; i$ < len$; ++i$) {
          f = F[i$];
          if (f && f.a) {
            for (k in f.a) {
              keys.add(k);
            }
          }
        }
        ret = [];
        keys.forEach(function(k){
          return ret.push(track(k, (function(){
            var i$, to$, results$ = [];
            for (i$ = 0, to$ = n; i$ < to$; ++i$) {
              results$.push(i$);
            }
            return results$;
          }()).map(function(i){
            if (F[i] && F[i].a && F[i].a[k] != null) {
              return [F[i].a[k]];
            } else {
              return null;
            }
          }), attrTol(k)));
        });
        return ret;
      };
      maskMarkup = function(rec){
        var F, r, i$, ref$, len$, j, k, ref1$, _, v, anim, grad;
        F = rec.frames;
        r = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        r.setAttribute('fill', "url(#mg" + rec.id + ")");
        for (i$ = 0, len$ = (ref$ = ['x', 'y', 'width', 'height']).length; i$ < len$; ++i$) {
          j = i$;
          k = ref$[i$];
          ref1$ = track(k, (fn$()).map(fn1$), 0.25), _ = ref1$[0], v = ref1$[1], anim = ref1$[2];
          r.setAttribute(k, v);
          if (anim) {
            r.appendChild(animateEl(k, anim));
          }
        }
        grad = rec.mask.grad.replace('<linearGradient', "<linearGradient id=\"mg" + rec.id + "\"");
        return "<mask id=\"m" + rec.id + "\" maskUnits=\"userSpaceOnUse\" x=\"-100000\" y=\"-100000\" width=\"200000\" height=\"200000\" style=\"mask-type:alpha\">" + grad + xml(r) + "</mask>";
        function fn$(){
          var i$, to$, results$ = [];
          for (i$ = 0, to$ = n; i$ < to$; ++i$) {
            results$.push(i$);
          }
          return results$;
        }
        function fn1$(i){
          if (F[i] && F[i].k) {
            return [F[i].k[j]];
          } else {
            return null;
          }
        }
      };
      withMask = function(rec, inner){
        if (!rec.mask) {
          return inner;
        }
        return maskMarkup(rec) + "<g mask=\"url(#m" + rec.id + ")\">" + inner + "</g>";
      };
      NOCLIP = [-100000, -100000, 200000, 200000];
      withClip = function(rec, inner){
        var F, r, i$, ref$, len$, j, k, ref1$, _, v, anim;
        if (!rec.clipped) {
          return inner;
        }
        F = rec.frames;
        r = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        for (i$ = 0, len$ = (ref$ = ['x', 'y', 'width', 'height']).length; i$ < len$; ++i$) {
          j = i$;
          k = ref$[i$];
          ref1$ = track(k, (fn$()).map(fn1$), 0.25), _ = ref1$[0], v = ref1$[1], anim = ref1$[2];
          r.setAttribute(k, v);
          if (anim) {
            r.appendChild(animateEl(k, anim));
          }
        }
        return "<clipPath id=\"q" + rec.id + "\">" + xml(r) + "</clipPath><g clip-path=\"url(#q" + rec.id + ")\">" + inner + "</g>";
        function fn$(){
          var i$, to$, results$ = [];
          for (i$ = 0, to$ = n; i$ < to$; ++i$) {
            results$.push(i$);
          }
          return results$;
        }
        function fn1$(i){
          if (F[i]) {
            return [(F[i].q || NOCLIP)[j]];
          } else {
            return null;
          }
        }
      };
      leafMarkup = function(rec, va){
        var c, i$, ref$, len$, ref1$, k, v, anim, f;
        c = va.c;
        for (i$ = 0, len$ = (ref$ = rec.tracks).length; i$ < len$; ++i$) {
          ref1$ = ref$[i$], k = ref1$[0], v = ref1$[1], anim = ref1$[2];
          c.setAttribute(k, v);
          if (anim) {
            c.appendChild(animateEl(k, anim));
          }
        }
        if (va.f && va.f.fontFamily) {
          c.setAttribute('style', (c.getAttribute('style') || '') + ";font-family:" + va.f.fontFamily);
          for (i$ = 0, len$ = (ref$ = va.f.fontFamily.split(',')).length; i$ < len$; ++i$) {
            f = ref$[i$];
            fontNames.add(f.trim().replace(/'/g, ''));
          }
        }
        return xml(c);
      };
      out = function(rec){
        var cls, base, anims, F, at, name, opa, pk, i$, len$, f, k, vs, kids, inner;
        if (rec.kind === 'static') {
          return rec.markup;
        }
        cls = "n" + rec.id;
        base = [];
        anims = [];
        F = rec.frames;
        at = function(f){
          return (function(){
            var i$, to$, results$ = [];
            for (i$ = 0, to$ = n; i$ < to$; ++i$) {
              results$.push(i$);
            }
            return results$;
          }()).map(function(i){
            if (F[i]) {
              return f(F[i]);
            } else {
              return null;
            }
          });
        };
        if (name = rule(cls, base, at(function(f){
          return f.m;
        }), 'transform', [0.005, 0.005, 0.005, 0.005, 0.25, 0.25], function(v){
          return "matrix(" + v.map(function(x, j){
            if (j > 3) {
              return +x.toFixed(2);
            } else {
              return fmt(x);
            }
          }).join(',') + ")";
        }, false)) {
          anims.push(name + " " + dur + "s linear");
        }
        opa = (function(){
          var i$, to$, results$ = [];
          for (i$ = 0, to$ = n; i$ < to$; ++i$) {
            results$.push(i$);
          }
          return results$;
        }()).map(function(i){
          return [F[i] ? F[i].o : 0];
        });
        if (name = rule(cls, base, opa, 'opacity', [0.008], function(v){
          return +v[0].toFixed(3);
        }, false)) {
          anims.push(name + " " + dur + "s linear");
        }
        if (name = rule(cls, base, at(function(f){
          return [f.b];
        }), 'filter', [0.05], function(v){
          if (v[0] > 0.01) {
            return "blur(" + fmt(v[0]) + "px)";
          } else {
            return 'none';
          }
        }, false)) {
          anims.push(name + " " + dur + "s linear");
        }
        if (rec.kind === 'leaf') {
          pk = new Set;
          for (i$ = 0, len$ = F.length; i$ < len$; ++i$) {
            f = F[i$];
            if (f && f.p) {
              for (k in f.p) {
                pk.add(k);
              }
            }
          }
          pk.forEach(function(k){
            var unit, name;
            unit = /opacity/.test(k) ? '' : 'px';
            if (name = rule(cls, base, at(function(f){
              if (f.p) {
                return [f.p[k]];
              } else {
                return null;
              }
            }), k, [attrTol(k)], function(v){
              return fmt(v[0]) + "" + unit;
            }, false)) {
              return anims.push(name + " " + dur + "s linear");
            }
          });
        }
        if (rec.blend) {
          base.push("mix-blend-mode:" + rec.blend);
        }
        if (anims.length) {
          base.push("animation:" + anims.map(function(it){
            return it + tail;
          }).join(','));
        }
        css.push("." + cls + "{" + base.join(';') + "}");
        if (rec.kind === 'leaf') {
          rec.tracks = attrsOf(rec);
        }
        vs = rec.variants.map(function(va, k){
          var vcls, vb, shown, name;
          vcls = cls + "v" + k;
          vb = [];
          shown = (function(){
            var i$, to$, results$ = [];
            for (i$ = 0, to$ = n; i$ < to$; ++i$) {
              results$.push(i$);
            }
            return results$;
          }()).map(function(i){
            return [F[i] && F[i].v === k ? 1 : 0];
          });
          if (name = rule(vcls, vb, shown, 'visibility', [0.5], function(v){
            if (v[0]) {
              return 'visible';
            } else {
              return 'hidden';
            }
          }, true)) {
            vb.push("animation:" + name + " " + dur + "s step-end" + tail);
          }
          css.push("." + vcls + "{" + vb.join(';') + "}");
          return "<g class=\"" + vcls + "\">" + (rec.kind === 'leaf'
            ? leafMarkup(rec, va)
            : va.svg) + "</g>";
        });
        kids = rec.kids.map(out).join('');
        if (rec.kind === 'svg') {
          inner = "<g transform=\"matrix(" + rec.vb.map(fmt).join(',') + ")\" style=\"" + rec.style.replace(/"/g, "'") + "\">" + kids + "</g>";
          if (rec.clip) {
            inner = "<clipPath id=\"c" + rec.id + "\"><rect width=\"" + rec.clip[0] + "\" height=\"" + rec.clip[1] + "\"/></clipPath><g clip-path=\"url(#c" + rec.id + ")\">" + inner + "</g>";
          }
          return "<g class=\"" + cls + "\">" + withClip(rec, withMask(rec, inner)) + "</g>";
        }
        if (rec.kind === 'g') {
          return "<g class=\"" + cls + "\" " + rec.attrs + ">" + kids + "</g>";
        }
        if (rec.clip && kids) {
          kids = "<clipPath id=\"c" + rec.id + "\"><rect width=\"" + rec.clip[0] + "\" height=\"" + rec.clip[1] + "\"/></clipPath><g clip-path=\"url(#c" + rec.id + ")\">" + kids + "</g>";
        }
        return "<g class=\"" + cls + "\">" + withClip(rec, withMask(rec, vs.join('') + kids)) + "</g>";
      };
      body = out(recs[0]);
      faces = fonts.filter(function(it){
        return fontNames.has(it.name);
      }).map(function(f){
        return ("@font-face{font-family:'" + f.name + "';font-weight:" + f.weight + ";font-style:" + f.style + ";") + ("src:url(data:font/ttf;base64," + b64Bytes(f.data) + ") format('truetype')}");
      });
      style = faces.join('') + "g{transform-box:view-box;transform-origin:0 0}" + css.join('');
      return "<svg width=\"" + width + "\" height=\"" + height + "\" viewBox=\"0 0 " + width + " " + height + "\" xmlns=\"http://www.w3.org/2000/svg\"><style>" + style + "</style>" + body + "</svg>";
    };
    animate = function(opt){
      var ctx, fps, from, to, ref$, n, el, o, t0, recs, i$, len$, rec, t1, fonts;
      opt == null && (opt = {});
      ctx = makeCtx();
      fps = opt.fps || 30;
      from = opt.from || 0;
      to = (ref$ = opt.to) != null
        ? ref$
        : opt.duration;
      n = Math.max(1, Math.round((to - from) * fps));
      el = opt.el;
      o = {
        el: el,
        seek: opt.seek,
        n: n,
        fps: fps,
        from: from,
        signal: opt.signal,
        progress: opt.progress
      };
      t0 = performance.now();
      recs = sample(o, ctx);
      for (i$ = 0, len$ = recs.length; i$ < len$; ++i$) {
        rec = recs[i$];
        if (rec.kind === 'leaf') {
          drawOn(rec);
        }
      }
      t1 = performance.now();
      fonts = null;
      return prepare(ctx, opt).then(function(arg$){
        var satori, f, jobs, i$, ref$, len$, rec, j$, ref1$, len1$, k, va, step;
        satori = arg$[0], f = arg$[1];
        fonts = f;
        jobs = [];
        for (i$ = 0, len$ = (ref$ = recs).length; i$ < len$; ++i$) {
          rec = ref$[i$];
          if (!rec.kind) {
            for (j$ = 0, len1$ = (ref1$ = rec.variants).length; j$ < len1$; ++j$) {
              k = j$;
              va = ref1$[j$];
              jobs.push([rec, k, va]);
            }
          }
        }
        step = function(i){
          var ref$, rec, k, va, i$, len$, f;
          if (i >= jobs.length) {
            return;
          }
          ref$ = jobs[i], rec = ref$[0], k = ref$[1], va = ref$[2];
          for (i$ = 0, len$ = (ref$ = va.laters).length; i$ < len$; ++i$) {
            f = ref$[i$];
            f(fonts);
          }
          return draw(satori, fonts, rec, k, va).then(function(svg){
            va.svg = svg;
            if (opt.progress) {
              opt.progress(0.5 + 0.5 * (i + 1) / jobs.length);
            }
            return step(i + 1);
          });
        };
        return step(0);
      }).then(function(){
        var svg, ref$, count, stats;
        svg = compose(recs, {
          n: n,
          fps: fps,
          repeat: (ref$ = opt.loop) != null ? ref$ : true,
          width: opt.width || el.offsetWidth,
          height: opt.height || el.offsetHeight
        }, fonts);
        count = function(k){
          return recs.filter(function(r){
            return (r.kind || 'html') === k;
          }).reduce(function(a, r){
            return a + r.variants.length;
          }, 0);
        };
        stats = {
          frames: n,
          elements: recs.length,
          variants: {
            html: count('html'),
            svg: count('leaf')
          },
          sampleMs: Math.round(t1 - t0),
          totalMs: Math.round(performance.now() - t0),
          bytes: svg.length
        };
        return {
          svg: svg,
          warnings: ctx.warnings(),
          stats: stats
        };
      });
    };
    lotion.animate = animate;
    lotion.player.prototype.animate = function(opt){
      var t0, p, this$ = this;
      opt == null && (opt = {});
      this.pause();
      t0 = this.t;
      p = Promise.resolve().then(function(){
        return animate(import$({
          el: this$.stage,
          seek: this$.opt.seek,
          duration: this$.duration,
          width: this$.width,
          height: this$.height
        }, opt));
      });
      return p['finally'](function(){
        return this$.opt.seek(t0);
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
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
}).call(this);
