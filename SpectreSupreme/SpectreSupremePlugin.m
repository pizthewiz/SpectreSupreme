//
//  SpectreSupremePlugIn.m
//  SpectreSupreme
//
//  Created by Jean-Pierre Mouilleseaux on 13 Jun 2011.
//  Copyright 2011 Chorded Constructions. All rights reserved.
//

#import "SpectreSupremePlugIn.h"
#import "SpectreSupreme.h"
#import <WebKit/WebKit.h>

#pragma mark WINDOW

@interface SSWindow : NSWindow
@end

@implementation SSWindow

- (BOOL)isOpaque {
    return NO;
}

- (NSColor*)backgroundColor {
    return [NSColor clearColor];
}

@end

#pragma mark - WEBVIEW

@interface SSWebView : WebView
//@property (nonatomic, readonly) double documentWidth;
//@property (nonatomic, readonly) double documentHeight;
@end

@implementation SSWebView

- (BOOL)isOpaque {
    return NO;
}

- (BOOL)drawsBackground {
    return NO;
}

//- (double)documentWidth {
//    return [[self stringByEvaluatingJavaScriptFromString:@"document.width"] doubleValue];
//}
//
//- (double)documentHeight {
//    return [[self stringByEvaluatingJavaScriptFromString:@"document.height"] doubleValue];
//}

@end

#pragma mark - PLUGIN

static NSString* SSExampleCompositionName = @"Render SVG";

static void _BufferReleaseCallback(const void* address, void* context) {
    CCDebugLog(@"_BufferReleaseCallback");
    // release bitmap context backing
    free((void*)address);
}

@interface SpectreSupremePlugIn()
@property (nonatomic, retain) id <QCPlugInOutputImageProvider> placeHolderProvider;
@property (nonatomic, retain) NSURL* location;
- (void)_setupWindow;
- (void)_teardownWindow;
- (void)_captureImageFromWebView;
@end

@implementation SpectreSupremePlugIn

@dynamic inputLocation, outputImage, outputDoneSignal;
@synthesize placeHolderProvider = _placeHolderProvider, location = _location;

+ (NSDictionary*)attributes {
    NSMutableDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys: 
        CCLocalizedString(@"kQCPlugIn_Name", NULL), QCPlugInAttributeNameKey, 
        CCLocalizedString(@"kQCPlugIn_Description", NULL), QCPlugInAttributeDescriptionKey, 
        nil];

#if defined(MAC_OS_X_VERSION_10_7) && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_7)
    if (&QCPlugInAttributeCategoriesKey != NULL) {
        // array with category strings
        NSArray* categories = [NSArray arrayWithObjects:@"obviously", @"fake", nil];
        [attributes setObject:categories forKey:QCPlugInAttributeCategoriesKey];
    }
    if (&QCPlugInAttributeExamplesKey != NULL) {
        // array of file paths or urls relative to plugin resources
        NSArray* examples = [NSArray arrayWithObjects:[[NSBundle mainBundle] URLForResource:SSExampleCompositionName withExtension:@"qtz"], nil];
        [attributes setObject:examples forKey:QCPlugInAttributeExamplesKey];
    }
#endif

    return (NSDictionary*)attributes;
}

+ (NSDictionary*)attributesForPropertyPortWithKey:(NSString*)key {
    if ([key isEqualToString:@"inputLocation"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Location", QCPortAttributeNameKey, nil];
    else if ([key isEqualToString:@"outputImage"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
    else if ([key isEqualToString:@"outputDoneSignal"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Done Signal", QCPortAttributeNameKey, nil];
	return nil;
}

+ (QCPlugInExecutionMode)executionMode {
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode)timeMode {
	return kQCPlugInTimeModeIdle;
}

#pragma mark -

- (void)finalize {
    [self _teardownWindow];
    CGImageRelease(_renderedImage);
    self.placeHolderProvider = nil;
    
    [_location release];

	[super finalize];
}

- (void)dealloc {
    [self _teardownWindow];
    CGImageRelease(_renderedImage);
    self.placeHolderProvider = nil;

    [_location release];

	[super dealloc];
}

#pragma mark - EXECUTION

- (BOOL)startExecution:(id <QCPlugInContext>)context {
	/*
	Called by Quartz Composer when rendering of the composition starts: perform any required setup for the plug-in.
	Return NO in case of fatal failure (this will prevent rendering of the composition to start).
	*/

    CCDebugLogSelector();

    [self _setupWindow];

    return YES;
}

- (void)enableExecution:(id <QCPlugInContext>)context {
	/*
	Called by Quartz Composer when the plug-in instance starts being used by Quartz Composer.
	*/
}

- (BOOL)execute:(id <QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments {
	/*
	Called by Quartz Composer whenever the plug-in instance needs to execute.
	Only read from the plug-in inputs and produce a result (by writing to the plug-in outputs or rendering to the destination OpenGL context) within that method and nowhere else.
	Return NO in case of failure during the execution (this will prevent rendering of the current frame to complete).

	The OpenGL context for rendering can be accessed and defined for CGL macros using:
	CGLContextObj cgl_ctx = [context CGLContextObj];
	*/

    // update outputs when appropriate
    if (_doneSignalDidChange) {
        // set image on done
        if (_doneSignal) {
            // TODO - move this somewhere convenient
            size_t renderedImageWidth = CGImageGetWidth(_renderedImage);
            size_t bytesPerRow = renderedImageWidth * 4;
            if (bytesPerRow % 16)
                bytesPerRow = ((bytesPerRow / 16) + 1) * 16;

            size_t renderedImageHeight = CGImageGetHeight(_renderedImage);
            double totalBytes = renderedImageHeight * bytesPerRow;
            void* baseAddress = valloc(totalBytes);
            if (baseAddress == NULL) {
                CCErrorLog(@"ERROR - failed to valloc %f bytes for bitmap data to write into", totalBytes);
                CGImageRelease(_renderedImage);
                _renderedImage = NULL;
                return NO;
            }

            CCDebugLog(@"update output to %fx%f image", (double)renderedImageWidth, (double)renderedImageHeight);

            CGContextRef bitmapContext = CGBitmapContextCreate(baseAddress, renderedImageWidth, renderedImageHeight, 8, bytesPerRow, [context colorSpace], kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
            if (bitmapContext == NULL) {
                CCErrorLog(@"ERROR - failed to create bitmap context");
                free(baseAddress);
                CGImageRelease(_renderedImage);
                _renderedImage = NULL;
                return NO;
            }
            CGRect bounds = CGRectMake(0., 0., renderedImageWidth, renderedImageHeight);
            CGContextClearRect(bitmapContext, bounds);
            CGContextDrawImage(bitmapContext, bounds, _renderedImage);
            CGContextRelease(bitmapContext);
            CGImageRelease(_renderedImage);
            _renderedImage = NULL;

            self.placeHolderProvider = [context outputImageProviderFromBufferWithPixelFormat:QCPlugInPixelFormatBGRA8 pixelsWide:renderedImageWidth pixelsHigh:renderedImageHeight baseAddress:baseAddress bytesPerRow:bytesPerRow releaseCallback:_BufferReleaseCallback releaseContext:NULL colorSpace:[context colorSpace] shouldColorMatch:YES];
            self.outputImage = self.placeHolderProvider;
        }

        self.outputDoneSignal = _doneSignal;
        _doneSignalDidChange = _doneSignal;
        _doneSignal = NO;
    }

    // process input when location changes
    if (![self didValueForInputKeyChange:@"inputLocation"])
        return YES;

    // bail on empty location
    if ([self.inputLocation isEqualToString:@""])
        return YES;

    CCDebugLogSelector();

    NSURL* url = [NSURL URLWithString:self.inputLocation];
//    if (![url isFileURL])
//        url = [NSURL fileURLWithPath:[self.inputLocation stringByExpandingTildeInPath] isDirectory:NO];

    self.location = url;
    CCDebugLog(@"will fetch: %@", url);
#define DISPATH_ON_MAIN_THREAD 1
#if DISPATH_ON_MAIN_THREAD
    dispatch_async(dispatch_get_main_queue(), ^{
#endif
#define WINDOW_WIDTH_DEFAULT 1680
#define WINDOW_HEIGHT_DEFAULT 1050
        [_window setContentSize:NSMakeSize(WINDOW_WIDTH_DEFAULT, WINDOW_HEIGHT_DEFAULT)];
        [[_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
        if (![[_webView mainFrame] provisionalDataSource]) {
            CCErrorLog(@"ERROR - web view missing data source, perhaps a bad url %@", url);
        }
#if DISPATH_ON_MAIN_THREAD
    });
#endif

	return YES;
}

- (void)disableExecution:(id <QCPlugInContext>)context {
	/*
	Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
	*/

    CCDebugLogSelector();
}

- (void)stopExecution:(id <QCPlugInContext>)context {
	/*
	Called by Quartz Composer when rendering of the composition stops: perform any required cleanup for the plug-in.
	*/

    CCDebugLogSelector();

    CGImageRelease(_renderedImage);
    _renderedImage = NULL;
    self.placeHolderProvider = nil;
}

#pragma mark - FRAME LOAD DELEGATE

- (void)webView:(WebView*)sender didFinishLoadForFrame:(WebFrame*)frame {
    CCDebugLogSelector();

    if (frame != [sender mainFrame])
        return;
    NSView* documentView = [[[sender mainFrame] frameView ] documentView];
	CCDebugLog(@"main frame: (%fx%f)", NSWidth(documentView.bounds), NSHeight(documentView.bounds));

    [self _captureImageFromWebView];
}

- (void)webView:(WebView*)sender didFailProvisionalLoadWithError:(NSError*)error forFrame:(WebFrame*)frame {
    CCDebugLogSelector();
    CCDebugLog(@"ERROR - failed provisional load with %@", error);
}

- (void)webView:(WebView*)sender didFailLoadWithError:(NSError*)error forFrame:(WebFrame*)frame {
    CCDebugLogSelector();
    CCDebugLog(@"ERROR - failed load with %@", error);
}

#pragma mark - PRIVATE

- (void)_setupWindow {
#if DISPATH_ON_MAIN_THREAD
    dispatch_async(dispatch_get_main_queue(), ^{
#endif
        _window = [[SSWindow alloc] initWithContentRect:NSMakeRect(-16000., -16000., WINDOW_WIDTH_DEFAULT, WINDOW_HEIGHT_DEFAULT) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
        _webView = [[SSWebView alloc] initWithFrame:NSMakeRect(0., 0., 1680., 1050.) frameName:nil groupName:nil];
        _webView.frameLoadDelegate = self;
        [_window setContentView:_webView];
#if DISPATH_ON_MAIN_THREAD
    });
#endif
}

- (void)_teardownWindow {
#if DISPATH_ON_MAIN_THREAD
    dispatch_async(dispatch_get_main_queue(), ^{
#endif
        [_window close];
        [_window release];
        _window = nil;
        [_webView release];
        _webView = nil;
#if DISPATH_ON_MAIN_THREAD
    });
#endif
}

- (void)_captureImageFromWebView {
    CCDebugLogSelector();

#if DISPATH_ON_MAIN_THREAD
    dispatch_async(dispatch_get_main_queue(), ^{
#endif
        @synchronized(_webView) {
            // size to fit
            NSView* documentView = [[[_webView mainFrame] frameView] documentView];
            CCDebugLog(@"documentView: %fx%f", NSWidth(documentView.bounds), NSHeight(documentView.bounds));
            [_window setContentSize:[documentView bounds].size];
            // NB - for some reason without this explicit -display call, svg content fails to render!
            [_window display];

            [_webView lockFocus];
            NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:[_webView visibleRect]];
            [_webView mainFrame];

//            NSString* path = [NSString stringWithFormat:@"/tmp/SS-%f.png", [[NSDate date] timeIntervalSince1970]];
//            [[bitmap representationUsingType:NSPNGFileType properties:nil] writeToFile:path atomically:YES];

            CGImageRelease(_renderedImage);
            _renderedImage = CGImageRetain([bitmap CGImage]);
            [bitmap release];

            _doneSignal = YES;
            _doneSignalDidChange = YES;
        }
#if DISPATH_ON_MAIN_THREAD
    });
#endif
}

@end
