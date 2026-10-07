#!/usr/bin/env node
var fs, path, http, child_process, usage, parse, types, serve, playwright, open, shot, frames, sheet, WARM, encode, video, cues, bundle, moved, argv, ref$, pos, opt, cmd, src, out, rest, times, p, slice$ = [].slice;
fs = require('fs');
path = require('path');
http = require('http');
child_process = require('child_process');
usage = 'usage:\n  lotion <frames|sheet|video|cues> <src> <out> [t...] [options]\n  lotion bundle <base-url> <block-name> <out> [options]\n  audio generators ( bgm | sfx | mix | beats ) were removed, see README > Audio\nsee README for options.';
parse = function(argv){
  var ref$, pos, opt, i, a;
  ref$ = [[], {}], pos = ref$[0], opt = ref$[1];
  i = 0;
  while (i < argv.length) {
    a = argv[i];
    if (/^--/.test(a)) {
      opt[a.replace(/^--/, '')] = argv[i + 1];
      i += 2;
    } else {
      pos.push(a);
      i++;
    }
  }
  return {
    pos: pos,
    opt: opt
  };
};
types = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav'
};
serve = function(src){
  return new Promise(function(res, rej){
    var stat, root, page, server;
    stat = fs.statSync(src);
    root = stat.isDirectory()
      ? src
      : path.dirname(src);
    page = stat.isDirectory()
      ? ''
      : path.basename(src);
    server = http.createServer(function(req, rsp){
      var f;
      f = path.join(root, decodeURIComponent(req.url.split('?')[0]));
      if (fs.existsSync(f) && fs.statSync(f).isDirectory()) {
        f = path.join(f, 'index.html');
      }
      return fs.readFile(f, function(e, buf){
        if (e) {
          rsp.writeHead(404);
          return rsp.end();
        }
        rsp.writeHead(200, {
          'Content-Type': types[path.extname(f)] || 'application/octet-stream'
        });
        return rsp.end(buf);
      });
    });
    server.on('error', rej);
    return server.listen(0, function(){
      return res({
        url: "http://localhost:" + server.address().port + "/" + page,
        close: function(){
          return server.close();
        }
      });
    });
  });
};
playwright = function(){
  var e;
  try {
    return require('playwright');
  } catch (e$) {
    e = e$;
    if (e.code !== 'MODULE_NOT_FOUND' || !/playwright/.test(e.message)) {
      throw e;
    }
    console.error('lotion: this command needs playwright, which is not installed. install it with:\n\n    npm i -D playwright\n    npx playwright install chromium');
    return process.exit(1);
  }
};
open = function(src, opt){
  var chromium, p;
  chromium = playwright().chromium;
  p = /^https?:/.test(src)
    ? Promise.resolve({
      url: src,
      close: function(){}
    })
    : serve(src);
  return p.then(function(srv){
    var ref$, u, h;
    ref$ = srv.url.split('#'), u = ref$[0], h = ref$[1];
    u += (/\?/.test(u) ? '&' : '?') + 'render' + (opt.query ? "&" + opt.query : '');
    return chromium.launch().then(function(browser){
      return browser.newPage({
        viewport: {
          width: +(opt.width || 1920),
          height: +(opt.height || 1080)
        },
        deviceScaleFactor: 1
      }).then(function(page){
        page.on('pageerror', function(e){
          return console.error("[page] " + e.message);
        });
        return page.goto(u, {
          waitUntil: 'networkidle'
        }).then(function(){
          return page.waitForFunction(function(){
            return typeof window.seek === 'function' && window.DURATION != null;
          }, null, {
            timeout: 30000
          });
        }).then(function(){
          return page.evaluate(function(){
            return document.fonts.ready.then(function(){
              return true;
            });
          });
        }).then(function(){
          return page.evaluate(function(){
            return window.DURATION;
          });
        }).then(function(duration){
          return {
            page: page,
            duration: duration,
            close: function(){
              return browser.close().then(function(){
                return srv.close();
              });
            }
          };
        });
      });
    });
  });
};
shot = function(page, t, type){
  type == null && (type = 'png');
  return page.evaluate(function(t){
    return window.seek(t);
  }, t).then(function(){
    return page.screenshot({
      type: type
    });
  });
};
frames = function(src, out, times, opt){
  fs.mkdirSync(out, {
    recursive: true
  });
  return open(src, opt).then(function(arg$){
    var page, close;
    page = arg$.page, close = arg$.close;
    return times.reduce(function(p, t, i){
      return p.then(function(){
        return shot(page, t).then(function(buf){
          return fs.writeFileSync(path.join(out, "f" + (i + "").padStart(3, '0') + "-" + t + ".png"), buf);
        });
      });
    }, Promise.resolve()).then(function(){
      return close();
    });
  });
};
sheet = function(src, out, times, opt){
  var tmp, cols, rows;
  tmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'lotion-'));
  cols = +(opt.cols || 3);
  rows = Math.ceil(times.length / cols);
  return frames(src, tmp, times, opt).then(function(){
    return new Promise(function(res, rej){
      var ff;
      ff = child_process.spawn('ffmpeg', ['-v', 'error', '-y', '-pattern_type', 'glob', '-i', path.join(tmp, '*.png'), '-vf', "scale=" + (opt.tile || 640) + ":-1,tile=" + cols + "x" + rows, '-frames:v', '1', out], {
        stdio: 'inherit'
      });
      return ff.on('close', function(c){
        fs.rmSync(tmp, {
          recursive: true,
          force: true
        });
        if (c) {
          return rej(new Error("ffmpeg exited with " + c));
        } else {
          return res();
        }
      });
    });
  });
};
WARM = 3;
encode = function(page, i0, i1, out, o, tick){
  var fps, sub, shutter, from, d, vf, ff, write, step, warm;
  fps = o.fps, sub = o.sub, shutter = o.shutter, from = o.from;
  d = shutter / fps / sub;
  vf = sub > 1
    ? ['-vf', "tmix=frames=" + sub + ",select='eq(mod(n\\," + sub + ")\\," + (sub - 1) + ")',setpts=N/" + fps + "/TB"]
    : [];
  ff = child_process.spawn('ffmpeg', ['-y', '-v', 'error', '-f', 'image2pipe', '-framerate', fps * sub + "", '-i', '-'].concat(vf, ['-r', fps + "", '-c:v', 'libx264', '-preset', 'slow', '-crf', o.crf + "", '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out]), {
    stdio: ['pipe', 'inherit', 'inherit']
  });
  write = function(buf){
    return new Promise(function(res){
      if (ff.stdin.write(buf)) {
        return res();
      } else {
        return ff.stdin.once('drain', res);
      }
    });
  };
  step = function(i, j){
    var t;
    if (i >= i1) {
      return Promise.resolve();
    }
    if (j >= sub) {
      tick();
      return step(i + 1, 0);
    }
    t = Math.max(0, from + i / fps + (sub > 1 ? (j - (sub - 1) / 2) * d : 0));
    return shot(page, t).then(write).then(function(){
      return step(i, j + 1);
    });
  };
  warm = (function(){
    var i$, to$, results$ = [];
    for (i$ = Math.max(0, i0 - WARM), to$ = i0; i$ < to$; ++i$) {
      results$.push(i$);
    }
    return results$;
  }()).reduce(function(p, i){
    return p.then(function(){
      return shot(page, Math.max(0, from + i / fps));
    });
  }, Promise.resolve());
  return warm.then(function(){
    return step(i0, 0);
  }).then(function(){
    return new Promise(function(res, rej){
      ff.on('close', function(c){
        if (c) {
          return rej(new Error("ffmpeg exited with " + c));
        } else {
          return res();
        }
      });
      return ff.stdin.end();
    });
  });
};
video = function(src, out, opt){
  var o, workers, t0;
  o = {
    fps: +(opt.fps || 60),
    sub: +(opt.sub || 1),
    shutter: +(opt.shutter || 0.5),
    crf: opt.crf || 16
  };
  workers = Math.max(1, Math.floor(+(opt.workers || 1)));
  t0 = Date.now();
  return open(src, opt).then(function(first){
    var n, done, tick, finish, k, tmp, parts;
    o.from = +(opt.from || 0);
    n = Math.round((+(opt.to || first.duration) - o.from) * o.fps);
    done = 0;
    tick = function(){
      if (++done % 300 === 0) {
        return console.log("frame " + done + "/" + n + " " + ((Date.now() - t0) / 1000).toFixed(0) + "s");
      }
    };
    console.log(("frame 0/" + n + " 0s") + (workers > 1 ? " ( " + workers + " workers )" : ''));
    finish = function(){
      return console.log(out + " ( " + n + " frames, " + ((Date.now() - t0) / 1000).toFixed(0) + "s )");
    };
    if (workers === 1) {
      return encode(first.page, 0, n, out, o, tick).then(function(){
        return first.close();
      }).then(finish);
    }
    k = Math.min(workers, n);
    tmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'lotion-'));
    parts = (function(){
      var i$, to$, results$ = [];
      for (i$ = 0, to$ = k; i$ < to$; ++i$) {
        results$.push(i$);
      }
      return results$;
    }()).map(function(w){
      return {
        i0: Math.floor(n * w / k),
        i1: Math.floor(n * (w + 1) / k),
        out: path.join(tmp, "part-" + w + ".mp4")
      };
    });
    return Promise.all([Promise.resolve(first)].concat((function(){
      var i$, to$, results$ = [];
      for (i$ = 1, to$ = k; i$ < to$; ++i$) {
        results$.push(i$);
      }
      return results$;
    }()).map(function(){
      return open(src, opt);
    }))).then(function(pages){
      return Promise.all(parts.map(function(p, w){
        return encode(pages[w].page, p.i0, p.i1, p.out, o, tick);
      }))['finally'](function(){
        return Promise.all(pages.map(function(p){
          return p.close();
        }));
      });
    }).then(function(){
      var list;
      list = path.join(tmp, 'list.txt');
      fs.writeFileSync(list, parts.map(function(p){
        return "file '" + p.out + "'";
      }).join('\n'));
      return new Promise(function(res, rej){
        var ff;
        ff = child_process.spawn('ffmpeg', ['-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', '-movflags', '+faststart', out], {
          stdio: 'inherit'
        });
        return ff.on('close', function(c){
          if (c) {
            return rej(new Error("ffmpeg concat exited with " + c));
          } else {
            return res();
          }
        });
      });
    })['finally'](function(){
      return fs.rmSync(tmp, {
        recursive: true,
        force: true
      });
    }).then(finish);
  });
};
cues = function(src, out, opt){
  return open(src, opt).then(function(arg$){
    var page, close;
    page = arg$.page, close = arg$.close;
    return page.evaluate(function(){
      if (window.cues) {
        return window.cues();
      } else {
        return [];
      }
    }).then(function(c){
      return fs.writeFileSync(out, JSON.stringify(c, null, 1));
    }).then(function(){
      return close();
    });
  });
};
bundle = function(base, name, out, opt){
  var chromium, m;
  chromium = playwright().chromium;
  base = base.replace(/\/$/, '');
  m = function(f){
    return require.resolve(f);
  };
  return chromium.launch().then(function(browser){
    return browser.newPage().then(function(page){
      page.on('pageerror', function(e){
        return console.error("[page] " + e.message);
      });
      return page.goto(base, {
        waitUntil: 'load'
      })['catch'](function(){}).then(function(){
        var libs;
        libs = ['@plotdb/semver/index.min.js', 'proxise/index.min.js', '@plotdb/csscope/bundle.js', '@plotdb/rescope/bundle.js', '@plotdb/block/bundle.js'];
        return libs.reduce(function(p, f){
          return p.then(function(){
            return page.addScriptTag({
              path: m(f)
            });
          });
        }, Promise.resolve());
      }).then(function(){
        return page.evaluate(function(arg$){
          var base, name, br, lr, mgr;
          base = arg$.base, name = arg$.name, br = arg$.br, lr = arg$.lr;
          mgr = new block.manager({
            registry: {
              lib: function(arg$){
                var name, version, path;
                name = arg$.name, version = arg$.version, path = arg$.path;
                return base + "" + lr + "/" + name + "/" + (version || 'main') + "/" + (path || 'index.min.js');
              },
              block: function(arg$){
                var name, path;
                name = arg$.name, path = arg$.path;
                return base + "" + br + "/" + name + "/" + (path || 'index.html');
              }
            }
          });
          return mgr.bundle({
            blocks: [{
              name: name
            }]
          }).then(function(r){
            return r.code;
          });
        }, {
          base: base,
          name: name,
          br: opt['block-root'] || '/block',
          lr: opt['lib-root'] || '/assets/lib'
        });
      });
    }).then(function(code){
      fs.writeFileSync(out, code);
      return console.log(out + " ( " + code.length + " bytes )");
    })['finally'](function(){
      return browser.close();
    });
  });
};
moved = function(cmd){
  console.error("lotion " + cmd + ": audio generators are no longer part of lotion ( moved to @plotdb/lotitor, not public yet ).\nto align any audio with the animation, export cue times with `lotion cues <src> cues.json`. see README > Audio.");
  return process.exit(1);
};
argv = process.argv.slice(2);
if ((ref$ = argv[0]) === 'bgm' || ref$ === 'sfx' || ref$ === 'mix' || ref$ === 'beats') {
  moved(argv[0]);
} else {
  ref$ = parse(argv), pos = ref$.pos, opt = ref$.opt;
  cmd = pos[0], src = pos[1], out = pos[2], rest = slice$.call(pos, 3);
  times = rest.map(function(it){
    return +it;
  });
  p = (function(){
    switch (cmd) {
    case 'frames':
      return frames(src, out, times, opt);
    case 'sheet':
      return sheet(src, out, times, opt);
    case 'video':
      return video(src, out, opt);
    case 'cues':
      return cues(src, out, opt);
    case 'bundle':
      if (rest[0]) {
        return bundle(src, out, rest[0], opt);
      } else {
        return null;
      }
    default:
      return null;
    }
  }());
  if (!p || !src || !out) {
    console.log(usage);
    process.exit(1);
  }
  p['catch'](function(e){
    console.error(e.message) || e;
    return process.exit(1);
  });
}
