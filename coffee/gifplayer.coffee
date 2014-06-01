class GIFVideo
  constructor: (@block, opts) ->
    @opts = opts || {}
    @opts.gif = $(@block).data('src')

    @stream = @hdr = @transparency = null
    @delay  = @disposalMethod = @lastDisposalMethod = null
    @frame  = @lastImg = null
    @disposalRestoreFromIdx = 0
    @set_first_frame = false
    
    @canvas  = new Canvas @block
    @frames  = @canvas.frames
    @tcanvas = @canvas.tmp_canvas 
    # @player = new Player()
    
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

    @canvas.drawFrame() 
    #if !@set_first_frame
    #  @canvas.drawFrame() 
    #  @set_first_frame = true 

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
    console.log 'finish parse'

  _getHandlerwithDrawProgress: (fn) ->
    (block) =>
      fn block
      @canvas.drawProgress @stream.pos, @stream.data.length

class Canvas 
  constructor: (@block) -> 
    @progress_height = 15
    @frames = new Frames()  
    @_init()

  _init: ->
    parent = @block.parentNode
    div    = document.createElement("div")
    
    @tmp_canvas = document.createElement "canvas"
    @canvas    = document.createElement("canvas")
    @ctx       = @canvas.getContext("2d")

    div.width  = @canvas.width = @block.width
    div.height = @canvas.height= @block.height
    div.className = "gifvideo"
    div.appendChild @canvas

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

  drawFrame : ->
    data = @frames.getFrame(@frames.getLength()-1).data
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
    console.log 'drawProgress'
    d = 
      top    : @canvas.height - @progress_height
      mid    : (pos / length) * @canvas.width
      width  : @canvas.width
      height : @progress_height

    console.log d

    @ctx.fillStyle = 'rgba(255, 255, 255, 0.4)'
    @ctx.fillRect d.mid, d.top, d.width - d.mid, d.height
    
    @ctx.fillStyle = 'rgba(255, 0, 22, .8)'
    @ctx.fillRect 0, d.top, d.mid, d.height

class Frames
  constructor: -> @frames = []
  getLength: ()-> @frames.length
  getFrame: (index)-> @frames[index]
  addFrame: (frame) ->
    @frames.push 
      data : frame.data,
      delay: frame.delay

class Player 
  constructor: (@frames, autoplay) ->
    @index = 0
    @curFrame   = @delayInfo = null
    @showingInfo= @pinned = false
    @playing = false

    if autoplay then @play() else @drawFrame()

  drwFrameAfter: (delta)->
      @index = (@index + delta + @frames.length) % @frames.length
      @curFrame  = @index + 1
      @delayInfo = frames[i].delay
      @drawFrame()    

  drawFrame : ->
      #@curFrame = @index
      #@tmpCanvas.getContext "2d" .putImageData frames[i].data, 0, 0
      #@ctx.globalCompositeOperation = "copy"
      #@ctx.drawImage @tmpCanvas, 0, 0

  play: ->
    @playing = true
    @_playLoop()

  _playLoop: =>
    return true if !@playing

    drawFrameAfter 1
    setTimeout @_playLoop, frames[@index].delay*10 || 100

  pause: ->
    @playing = false

  getFrameLength: ->
    frames.length

  moveTo: (index) ->
    @index = index
    @drawFrame()


$ ->
  $('[data-gifvideo]').each (k, block)->
    new GIFVideo block


