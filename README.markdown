
# Spectre Supreme
a lightweight quartz composer patch to render a web resource into an image

### HOW TO INSTALL
move SpectreSupreme.plugin into ~/Library/Graphics/Quartz Composer Plug-Ins/

### NOTES
* the Location input should be a fully qualified url with scheme, or a relative to the composition file path
* the Width Pixels and Height Pixels inputs default to the main screen's resolution and are relevant for relative-sized content. fixed-size content will render into a view of the destination size, but will then be resized to the document's native size. if the desired destination size is a hard limit, one should compare the output image size to the desired input size and transform accordingly.
* render occurs on change of any input or when the Render signal goes high. the Render signal could be tied to an LFO to periodically render an animated resource, but performance is currently not ideal for that.
* rendering occurs on the main thread and depending on the complexity of the content, can stall the host application

### THANKS
* Tamas Nagy (¿?¿?) and Anton Marini (vade) for the inspiration and point of reference through [CoGeWebKit](http://code.google.com/p/cogewebkit/)
* Paul Hammond's [webkit2png](http://www.paulhammond.org/webkit2png/) for a vexing -[NSWindow display] hint
* Mike Ash (mikeash) in #macdev for a much better way to pull a bitmap of a view rather than using -[NSWindow display], -[NSView lockFocus] and -[NSBitmapImageRep initWithFocusedViewRect:] in (ugly) concert
