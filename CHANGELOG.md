
v0.2.7 (7 Jan 2012)
* webview confined to main queue to avoid threading issues in apps that render off the main thread

v0.2.6 (17 Aug 2011)
* remove debug rendered image writing to /tmp/
* use arc on 10.7 and arclite on 10.6

v0.2.4 (9 Aug 2011)
* fix plugin loading problem on 10.6 when built on 10.7

v0.2.4 (3 Aug 2011)
* fix crash on close due to double releasing the off-screen rendering window
* bundle example composition and categorize patch on lion

v0.2.3 (4 July 2011)
* workaround hang on dealloc from deferred off-screen window cleanup again (again)

v0.2.2 (22 June 2011)
* minor performance improvement on image capture from web resource

v0.2.1 (19 June 2011)
* fix crash on quit from deferred off-screen window cleanup

v0.2.0 (18 June 2011)
* expose destination width and height for relative-sized content
* offer an explicit render signal to re-render loaded content

v0.1.2 (17 June 2011)
* greatly improve bitmap capture from webview, faster and more robust

v0.1.1 (15 June 2011)
* support for relative file paths

v0.1.0 (14 June 2011)
* initial release