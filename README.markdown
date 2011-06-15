
# Spectre Supreme
a lightweight quartz composer patch to render a web resource into an image

### HOW TO INSTALL
move SpectreSupreme.plugin into ~/Library/Graphics/Quartz Composer Plug-Ins/

### NOTES
* resource is rendered as a one-shot, continuous rendering is not offered but could be simulated through periodically changeing the URL with an anchor or parameter
* location input should be a fully qualified url including protocol, relative links are not yet supported

### THANKS
* Tamas Nagy (¿?¿?) and Anton Marini (vade) for the inspiration and point of reference through [CoGeWebKit](http://code.google.com/p/cogewebkit/)
* Paul Hammond's [webkit2png](http://www.paulhammond.org/webkit2png/) for a vexing -[NSWindow display] hint
