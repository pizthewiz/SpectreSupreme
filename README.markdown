
# Spectre Supreme
a lightweight quartz composer patch to render a web resource into an image

### HOW TO INSTALL
move SpectreSupreme.plugin into ~/Library/Graphics/Quartz Composer Plug-Ins/

### NOTES
* a resource renders in one-shot, continuous rendering is not offered but could be simulated through periodically changeing the Location with an anchor or parameter
* the Location input should be a fully qualified url with scheme, or a relative to the composition file path
* rendering occurrs on the main thread, so the host application can get starved

### THANKS
* Tamas Nagy (¿?¿?) and Anton Marini (vade) for the inspiration and point of reference through [CoGeWebKit](http://code.google.com/p/cogewebkit/)
* Paul Hammond's [webkit2png](http://www.paulhammond.org/webkit2png/) for a vexing -[NSWindow display] hint
* Mike Ash (mikeash) in #macdev for a much better way to get a bitmap of a view rather than -[NSWindow display], -[NSView lockFocus] and -[NSBitmapImageRep initWithFocusedViewRect:]
