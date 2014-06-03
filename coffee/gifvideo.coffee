
class this.GIFVideo
  constructor: (@block, opts) ->
    @opts = opts || {}
    @opts.gif    = @block.getAttribute 'data-src'

    @stream = @hdr = @transparency = null
    @delay  = @disposalMethod = @lastDisposalMethod = null
    @frame  = @lastImg = null
    @disposalRestoreFromIdx = 0
    @set_first_frame = false
    
    @canvas  = new Canvas @block
    @frames  = @canvas.frames
    @tcanvas = @canvas.tmp_canvas  
    
    @_loadGif()

  _loadGif: () ->
      @loading = true
      @load_callback = -> console.log 'call load_callback' 

      h = new XMLHttpRequest()
      h.overrideMimeType 'text/plain; charset=x-user-defined' 

      h.onload = (e) =>
        @stream = new jsgif.Stream h.responseText
        @_parse()

      h.onprogress = (e) =>

      h.onerror = => @drawError 'xhr'

      h.open 'GET', @opts.gif, true
      h.send()

  _parse: ->
    parseHandlers = 
      hdr: @hdrHandler
      gce: @gceHandler
      com: ->
      app: 
        NETSCAPE: ->
      img: @_getHandlerwithDrawProgress @imgHandler
      eof: @eofHandler

    try 
      jsgif.parseGIF @stream, parseHandlers
    catch err 
      @canvas.drawError 'parse'

  hdrHandler: (_hdr) =>
    @hdr = _hdr
    @canvas.setSize @hdr.width, @hdr.height

  gceHandler: (gce) =>
    @_pushFrame()

    @frame = null
    @delay          = gce.delayTime;
    @transparency   = gce.transparencyIndex || null
    @disposalMethod = gce.disposalMethod
    @lastDisposalMethod = @disposalMethod

  _pushFrame: ->
    return true if !@frame

    @frames.addFrame
      data : @frame.getImageData 0, 0, @hdr.width, @hdr.height
      delay: @delay

    if !@set_first_frame
      @canvas.drawFrame(0) 
      @set_first_frame = true 

  imgHandler: (img) =>
    @frame = @tcanvas.getContext('2d') if !@frame
    @_setDisposal() if @frames.getLength() > 0
    @_setFrame img
    @lastImg = img

  _setDisposal: ()->
    if @lastDisposalMethod == 3        
        data = @frames.getFrame(@disposalRestoreFromIdx).data
        @frame.putImageData data, 0, 0
    else if @lastDisposalMethod == 2
        @frame.clearRect @lastImg.leftPos, @lastImg.topPos, @lastImg.width, @lastImg.height
    else
        @disposalRestoreFromIdx = @frames.getLength() - 1

  _setFrame: (img) ->
    imgData = @frame.getImageData img.leftPos, img.topPos, img.width, img.height
    cdd     = imgData.data
    ct      = if img.lctFlag then img.lct else @hdr.gct

    img.pixels.forEach (pixel, i) =>
      if pixel != @transparency
        cdd[i * 4 + 0] = ct[pixel][0]
        cdd[i * 4 + 1] = ct[pixel][1]
        cdd[i * 4 + 2] = ct[pixel][2]
        cdd[i * 4 + 3] = 255
    imgData.data = cdd
    @frame.putImageData imgData, img.leftPos, img.topPos 

  eofHandler: (block) =>
      loading = false;
      @_pushFrame()
      @_eofCallBack()

  _eofCallBack: ->
    @canvas.setPlayer()

  getPlayer: ->
    @player

  _getHandlerwithDrawProgress: (fn) ->
    (block) =>
      fn block
      @canvas.drawProgress @stream.pos, @stream.data.length

class Canvas 
  constructor: (@block) ->
    @progress_height = 5
    @frames = new Frames()  
    @_init()

  _init: ->
    w = @block.getAttribute 'data-width' 
    h = @block.getAttribute 'data-height'

    parent = @block.parentNode
    div    = document.createElement "div"
    
    @tmp_canvas= document.createElement "canvas"
    @canvas    = document.createElement "canvas"
    @ctx       = @canvas.getContext "2d"

    @canvas.width = w
    @canvas.height= h

    div.className = "gifvideo"
    div.setAttribute "style", "width:#{w}px;height:#{h}px"

    ul = document.createElement "ul"
    @li_play = document.createElement "li"
    @li_play.className = "play"
    @li_play.innerHTML = "play"
    @li_stop = document.createElement "li"
    @li_stop.className = "stop"
    @li_stop.innerHTML = "stop"

    ul.appendChild @li_play
    ul.appendChild @li_stop
    
    div.appendChild @canvas
    div.appendChild ul

    parent.insertBefore div, @block
    parent.removeChild  @block

  setSize: (w, h)->
    @canvas.width = w
    @canvas.height= h

    @tmp_canvas.width = w
    @tmp_canvas.height= h
    @tmp_canvas.style.width = "#{w}px"
    @tmp_canvas.style.height= "#{h}px"
    @tmp_canvas.getContext('2d').setTransform(1, 0, 0, 1, 0, 0)

  drawFrame : (index)->
    data = @frames.getFrame(index).data
    @tmp_canvas
      .getContext "2d" 
      .putImageData data, 0, 0
    #@ctx.globalCompositeOperation = "copy"
    @ctx.drawImage @tmp_canvas, 0, 0

  drawError: (errorType)->
    console.log 'drawError', errorType
    frames = [];

    d = 
      width : @block.width
      height: @block.height

    @ctx.fillStyle = 'black'
    @ctx.fillRect 0, 0, d.width, d.height
    @ctx.strokeStyle = 'red'
    @ctx.lineWidth = 3
    @ctx.moveTo 0, 0
    @ctx.lineTo d.width, d.height
    @ctx.moveTo 0, d.height
    @ctx.lineTo d.width, 0
    @ctx.stroke()

  drawProgress: (pos, length)->
    d = 
      top    : @canvas.height - @progress_height
      mid    : (pos / length) * @canvas.width
      width  : @canvas.width
      height : @progress_height

    @ctx.fillStyle = '#79bca5'
    @ctx.fillRect 0, d.top, d.mid, d.height

  setPlayer: ->
    player = new Player @, @frames 
    @li_play.onclick = -> player.play()
    @li_stop.onclick = -> player.stop()  

class Frames
  constructor: -> @frames = []
  getLength: ()-> @frames.length
  getFrame: (index)-> @frames[index]
  addFrame: (frame) ->
    @frames.push 
      data : frame.data,
      delay: frame.delay

class Player 
  constructor: (@canvas, @frames) ->
    @index  = 0
    @playing= false
    @frames_len = @frames.getLength()   

  stop : -> 
    @playing = false;
    @index   = 0;
    @canvas.drawFrame @index

  pause: -> @playing = false

  play: ->
    @playing = true
    @_playLoop()

  _playLoop: =>
    return true if !@playing

    @drawFrameAfter 1
    delay = @_getDelay()
    setTimeout @_playLoop, delay

  drawFrameAfter: (delta) ->
    @index = (@index + delta + @frames_len) % @frames_len
    @canvas.drawFrame @index

  _getDelay: =>
    @frames.getFrame(@index).delay*10 || 100

  moveTo: (index) ->
    @index = index
    @canvas.drawFrame(@index) 


