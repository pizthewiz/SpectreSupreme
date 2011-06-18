
# Spectre Supreme
a lightweight quartz composer patch to render a web resource into an image

### HOW TO INSTALL
move SpectreSupreme.plugin into ~/Library/Graphics/Quartz Composer Plug-Ins/

### NOTES
* the Location input should be a fully qualified url with scheme, or a relative to the composition file path
* the Width and Height inputs are measured in pixels and are primarily relevant for relative-sized content. fixed-size content will render into a view of the destination size, but will then be resized to the document's native size. if the desired destination size is a hard limit, one should compare the output image size to the desired input size and transform accordingly.
* a resource renders in one-shot, continuous rendering is not offered but could be simulated through periodically changing the Location with an anchor or parameter
* rendering occurs on the main thread and depending on the complexity of the content, can stall the host application

### THANKS
* Tamas Nagy (¿?¿?) and Anton Marini (vade) for the inspiration and point of reference through [CoGeWebKit](http://code.google.com/p/cogewebkit/)
* Paul Hammond's [webkit2png](http://www.paulhammond.org/webkit2png/) for a vexing -[NSWindow display] hint
* Mike Ash (mikeash) in #macdev for a much better way to pull a bitmap of a view rather than using -[NSWindow display], -[NSView lockFocus] and -[NSBitmapImageRep initWithFocusedViewRect:] in (ugly) concert
