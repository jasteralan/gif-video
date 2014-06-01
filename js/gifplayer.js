(function() {
  var Canvas, Frames, GIFVideo, Player,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  GIFVideo = (function() {
    function GIFVideo(block, opts) {
      this.block = block;
      this.eofHandler = __bind(this.eofHandler, this);
      this.imgHandler = __bind(this.imgHandler, this);
      this.gceHandler = __bind(this.gceHandler, this);
      this.hdrHandler = __bind(this.hdrHandler, this);
      this.opts = opts || {};
      this.opts.gif = $(this.block).data('src');
      this.stream = this.hdr = this.transparency = null;
      this.delay = this.disposalMethod = this.lastDisposalMethod = null;
      this.frame = this.lastImg = null;
      this.disposalRestoreFromIdx = 0;
      this.set_first_frame = false;
      this.canvas = new Canvas(this.block);
      this.frames = this.canvas.frames;
      this.tcanvas = this.canvas.tmp_canvas;
      this._loadGif();
    }

    GIFVideo.prototype._loadGif = function() {
      var h;
      this.loading = true;
      this.load_callback = function() {
        return console.log('call load_callback');
      };
      h = new XMLHttpRequest();
      h.overrideMimeType('text/plain; charset=x-user-defined');
      h.onload = (function(_this) {
        return function(e) {
          _this.stream = new jsgif.Stream(h.responseText);
          return _this._parse();
        };
      })(this);
      h.onprogress = (function(_this) {
        return function(e) {};
      })(this);
      h.onerror = (function(_this) {
        return function() {
          return _this.drawError('xhr');
        };
      })(this);
      h.open('GET', this.opts.gif, true);
      return h.send();
    };

    GIFVideo.prototype._parse = function() {
      var err, parseHandlers;
      parseHandlers = {
        hdr: this.hdrHandler,
        gce: this.gceHandler,
        com: function() {},
        app: {
          NETSCAPE: function() {}
        },
        img: this._getHandlerwithDrawProgress(this.imgHandler),
        eof: this.eofHandler
      };
      try {
        return jsgif.parseGIF(this.stream, parseHandlers);
      } catch (_error) {
        err = _error;
        return this.canvas.drawError('parse');
      }
    };

    GIFVideo.prototype.hdrHandler = function(_hdr) {
      this.hdr = _hdr;
      return this.canvas.setSize(this.hdr.width, this.hdr.height);
    };

    GIFVideo.prototype.gceHandler = function(gce) {
      this._pushFrame();
      this.frame = null;
      this.delay = gce.delayTime;
      this.transparency = gce.transparencyIndex || null;
      this.disposalMethod = gce.disposalMethod;
      return this.lastDisposalMethod = this.disposalMethod;
    };

    GIFVideo.prototype._pushFrame = function() {
      if (!this.frame) {
        return true;
      }
      this.frames.addFrame({
        data: this.frame.getImageData(0, 0, this.hdr.width, this.hdr.height),
        delay: this.delay
      });
      return this.canvas.drawFrame();
    };

    GIFVideo.prototype.imgHandler = function(img) {
      if (!this.frame) {
        this.frame = this.tcanvas.getContext('2d');
      }
      if (this.frames.getLength() > 0) {
        this._setDisposal();
      }
      this._setFrame(img);
      return this.lastImg = img;
    };

    GIFVideo.prototype._setDisposal = function() {
      var data;
      if (this.lastDisposalMethod === 3) {
        data = this.frames.getFrame(this.disposalRestoreFromIdx).data;
        return this.frame.putImageData(data, 0, 0);
      } else if (this.lastDisposalMethod === 2) {
        return this.frame.clearRect(this.lastImg.leftPos, this.lastImg.topPos, this.lastImg.width, this.lastImg.height);
      } else {
        return this.disposalRestoreFromIdx = this.frames.getLength() - 1;
      }
    };

    GIFVideo.prototype._setFrame = function(img) {
      var cdd, ct, imgData;
      imgData = this.frame.getImageData(img.leftPos, img.topPos, img.width, img.height);
      cdd = imgData.data;
      ct = img.lctFlag ? img.lct : this.hdr.gct;
      img.pixels.forEach((function(_this) {
        return function(pixel, i) {
          if (pixel !== _this.transparency) {
            cdd[i * 4 + 0] = ct[pixel][0];
            cdd[i * 4 + 1] = ct[pixel][1];
            cdd[i * 4 + 2] = ct[pixel][2];
            return cdd[i * 4 + 3] = 255;
          }
        };
      })(this));
      imgData.data = cdd;
      return this.frame.putImageData(imgData, img.leftPos, img.topPos);
    };

    GIFVideo.prototype.eofHandler = function(block) {
      var loading;
      loading = false;
      this._pushFrame();
      return this._eofCallBack();
    };

    GIFVideo.prototype._eofCallBack = function() {
      return console.log('finish parse');
    };

    GIFVideo.prototype._getHandlerwithDrawProgress = function(fn) {
      return (function(_this) {
        return function(block) {
          fn(block);
          return _this.canvas.drawProgress(_this.stream.pos, _this.stream.data.length);
        };
      })(this);
    };

    return GIFVideo;

  })();

  Canvas = (function() {
    function Canvas(block) {
      this.block = block;
      this.progress_height = 15;
      this.frames = new Frames();
      this._init();
    }

    Canvas.prototype._init = function() {
      var div, parent;
      parent = this.block.parentNode;
      div = document.createElement("div");
      this.tmp_canvas = document.createElement("canvas");
      this.canvas = document.createElement("canvas");
      this.ctx = this.canvas.getContext("2d");
      div.width = this.canvas.width = this.block.width;
      div.height = this.canvas.height = this.block.height;
      div.className = "gifvideo";
      div.appendChild(this.canvas);
      parent.insertBefore(div, this.block);
      return parent.removeChild(this.block);
    };

    Canvas.prototype.setSize = function(w, h) {
      this.canvas.width = w;
      this.canvas.height = h;
      this.tmp_canvas.width = w;
      this.tmp_canvas.height = h;
      this.tmp_canvas.style.width = "" + w + "px";
      this.tmp_canvas.style.height = "" + h + "px";
      return this.tmp_canvas.getContext('2d').setTransform(1, 0, 0, 1, 0, 0);
    };

    Canvas.prototype.drawFrame = function() {
      var data;
      data = this.frames.getFrame(this.frames.getLength() - 1).data;
      this.tmp_canvas.getContext("2d").putImageData(data, 0, 0);
      return this.ctx.drawImage(this.tmp_canvas, 0, 0);
    };

    Canvas.prototype.drawError = function(errorType) {
      var d, frames;
      console.log('drawError', errorType);
      frames = [];
      d = {
        width: this.block.width,
        height: this.block.height
      };
      this.ctx.fillStyle = 'black';
      this.ctx.fillRect(0, 0, d.width, d.height);
      this.ctx.strokeStyle = 'red';
      this.ctx.lineWidth = 3;
      this.ctx.moveTo(0, 0);
      this.ctx.lineTo(d.width, d.height);
      this.ctx.moveTo(0, d.height);
      this.ctx.lineTo(d.width, 0);
      return this.ctx.stroke();
    };

    Canvas.prototype.drawProgress = function(pos, length) {
      var d;
      console.log('drawProgress');
      d = {
        top: this.canvas.height - this.progress_height,
        mid: (pos / length) * this.canvas.width,
        width: this.canvas.width,
        height: this.progress_height
      };
      console.log(d);
      this.ctx.fillStyle = 'rgba(255, 255, 255, 0.4)';
      this.ctx.fillRect(d.mid, d.top, d.width - d.mid, d.height);
      this.ctx.fillStyle = 'rgba(255, 0, 22, .8)';
      return this.ctx.fillRect(0, d.top, d.mid, d.height);
    };

    return Canvas;

  })();

  Frames = (function() {
    function Frames() {
      this.frames = [];
    }

    Frames.prototype.getLength = function() {
      return this.frames.length;
    };

    Frames.prototype.getFrame = function(index) {
      return this.frames[index];
    };

    Frames.prototype.addFrame = function(frame) {
      return this.frames.push({
        data: frame.data,
        delay: frame.delay
      });
    };

    return Frames;

  })();

  Player = (function() {
    function Player(frames, autoplay) {
      this.frames = frames;
      this._playLoop = __bind(this._playLoop, this);
      this.index = 0;
      this.curFrame = this.delayInfo = null;
      this.showingInfo = this.pinned = false;
      this.playing = false;
      if (autoplay) {
        this.play();
      } else {
        this.drawFrame();
      }
    }

    Player.prototype.drwFrameAfter = function(delta) {
      this.index = (this.index + delta + this.frames.length) % this.frames.length;
      this.curFrame = this.index + 1;
      this.delayInfo = frames[i].delay;
      return this.drawFrame();
    };

    Player.prototype.drawFrame = function() {};

    Player.prototype.play = function() {
      this.playing = true;
      return this._playLoop();
    };

    Player.prototype._playLoop = function() {
      if (!this.playing) {
        return true;
      }
      drawFrameAfter(1);
      return setTimeout(this._playLoop, frames[this.index].delay * 10 || 100);
    };

    Player.prototype.pause = function() {
      return this.playing = false;
    };

    Player.prototype.getFrameLength = function() {
      return frames.length;
    };

    Player.prototype.moveTo = function(index) {
      this.index = index;
      return this.drawFrame();
    };

    return Player;

  })();

  $(function() {
    return $('[data-gifvideo]').each(function(k, block) {
      return new GIFVideo(block);
    });
  });

}).call(this);
