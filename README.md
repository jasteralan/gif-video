# GIF Video

Play/stop gif like video!

Forked from [buzzfeed/libgif-js](https://github.com/buzzfeed/libgif-js)

## Usage

```
<div data-gifvideo
	data-src = "/example_gifs/you_blew_it.gif" 
	data-width="400" data-height="218"></div>

<script src="js/gifvideo.min.js"></script>
<script>
	[].forEach.call(
	  	document.querySelectorAll('[data-gifvideo]'), 
	  	function(element){
	    	new GIFVideo(element);
	  	}
	);
</script>
```

See example.html for reference

Example [here](http://jasteralan.github.io/play-gif-like-video/)
