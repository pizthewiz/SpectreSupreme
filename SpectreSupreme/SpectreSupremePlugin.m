//
//  SpectreSupremePlugIn.m
//  SpectreSupreme
//
//  Created by Jean-Pierre Mouilleseaux on 13 Jun 2011.
//  Copyright 2011-2012 Chorded Constructions. All rights reserved.
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
@end

@implementation SSWebView
- (BOOL)isOpaque {
    return NO;
}

- (BOOL)drawsBackground {
    return NO;
}
@end

#pragma mark - PLUGIN

static NSString* const SSExampleCompositionName = @"Render SVG";
static NSUInteger SSMainScreenWidth = 0;
static NSUInteger SSMainScreenHeight = 0;

static void _BufferReleaseCallback(const void* address, void* context) {
    CCDebugLog(@"_BufferReleaseCallback");
    // release bitmap context backing
    free((void*)address);
}

@interface SpectreSupremePlugIn()
@property (nonatomic, strong) id <QCPlugInOutputImageProvider> placeHolderProvider;
@property (nonatomic, strong) NSURL* location;
- (void)_setupWindow;
- (void)_teardownWindow;
- (void)_captureImageFromWebView;
@end

@implementation SpectreSupremePlugIn

@dynamic inputLocation, inputDestinationWidth, inputDestinationHeight, inputRenderSignal, outputImage, outputDoneSignal;
@synthesize placeHolderProvider = _placeHolderProvider, location = _location;

+ (void)initialize {
    SSMainScreenWidth = NSWidth([[NSScreen mainScreen] frame]);
    SSMainScreenHeight = NSHeight([[NSScreen mainScreen] frame]);
}

+ (NSDictionary*)attributes {
    return [NSDictionary dictionaryWithObjectsAndKeys: 
        CCLocalizedString(@"kQCPlugIn_Name", NULL), QCPlugInAttributeNameKey, 
        CCLocalizedString(@"kQCPlugIn_Description", NULL), QCPlugInAttributeDescriptionKey, 
        [NSArray arrayWithObjects:@"Source", nil], QCPlugInAttributeCategoriesKey,
        [NSArray arrayWithObjects:[[NSBundle bundleForClass:[self class]] URLForResource:SSExampleCompositionName withExtension:@"qtz"], nil], QCPlugInAttributeExamplesKey, 
        nil];
}

+ (NSDictionary*)attributesForPropertyPortWithKey:(NSString*)key {
    if ([key isEqualToString:@"inputLocation"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Location", QCPortAttributeNameKey, nil];
    else if ([key isEqualToString:@"inputDestinationWidth"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Width Pixels", QCPortAttributeNameKey, 
            [NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey, 
            [NSNumber numberWithUnsignedInteger:10000], QCPortAttributeMaximumValueKey, 
            [NSNumber numberWithUnsignedInteger:SSMainScreenWidth], QCPortAttributeDefaultValueKey, nil];
    else if ([key isEqualToString:@"inputDestinationHeight"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Height Pixels", QCPortAttributeNameKey, 
            [NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey, 
            [NSNumber numberWithUnsignedInteger:10000], QCPortAttributeMaximumValueKey, 
            [NSNumber numberWithUnsignedInteger:SSMainScreenHeight], QCPortAttributeDefaultValueKey, nil];
    else if ([key isEqualToString:@"inputRenderSignal"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Render Signal", QCPortAttributeNameKey, nil];
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

- (id)init {
    self = [super init];
    if (self) {
        _destinationWidth = SSMainScreenWidth;
        _destinationHeight = SSMainScreenHeight;
    }
    return self;
}

- (void)finalize {
    [self _teardownWindow];
    CGImageRelease(_renderedImage);
    self.placeHolderProvider = nil;

	[super finalize];
}

- (void)dealloc {
    [self _teardownWindow];
    CGImageRelease(_renderedImage);
}

#pragma mark - EXECUTION

- (BOOL)startExecution:(id <QCPlugInContext>)context {
	/*
	Called by Quartz Composer when rendering of the composition starts: perform any required setup for the plug-in.
	Return NO in case of fatal failure (this will prevent rendering of the composition to start).
	*/

    CCDebugLogSelector();

    dispatch_async(dispatch_get_main_queue(), ^{
        [self _setupWindow];
    });

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

//            CCDebugLog(@"update output image to %fx%f", (double)renderedImageWidth, (double)renderedImageHeight);

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

    BOOL shouldResize = [self didValueForInputKeyChange:@"inputDestinationWidth"] || [self didValueForInputKeyChange:@"inputDestinationHeight"];
    BOOL shouldLoadURL = [self didValueForInputKeyChange:@"inputLocation"] && ![self.inputLocation isEqualToString:@""];
    BOOL shouldRender = shouldResize || ([self didValueForInputKeyChange:@"inputRenderSignal"] && self.inputRenderSignal);

    // resize when appropriate
    if (shouldResize) {
        if (self.inputDestinationWidth == 0 || self.inputDestinationHeight == 0) {
            CCErrorLog(@"ERROR - invalid dimensions %lux%lu", (unsigned long)self.inputDestinationWidth, (unsigned long)self.inputDestinationHeight);
            return NO;
        }
        _destinationWidth = self.inputDestinationWidth;
        _destinationHeight = self.inputDestinationHeight;
        CCDebugLog(@"resize content to %lux%lu", (unsigned long)_destinationWidth, (unsigned long)_destinationHeight);
        dispatch_async(dispatch_get_main_queue(), ^{
            [_window setContentSize:NSMakeSize(_destinationWidth, _destinationHeight)];
        });
    }
    // bail when new render is not necessary
    if (!shouldLoadURL && !shouldRender) {
        return YES;
    }

    CCDebugLogSelector();

    if (shouldLoadURL) {
        NSURL* url = [NSURL URLWithString:self.inputLocation];
        // scheme-less would suggest a relative file url
        if (![url scheme]) {
            NSURL* baseDirectoryURL = [[context compositionURL] URLByDeletingLastPathComponent];
//            NSString* cleanFilePath = [[[baseDirectoryURL path] stringByAppendingPathComponent:self.inputLocation] stringByStandardizingPath];
//            CCDebugLog(@"cleaned file path: %@", cleanFilePath);
            url = [baseDirectoryURL URLByAppendingPathComponent:self.inputLocation];
        }

        self.location = url;
        CCDebugLog(@"will fetch: %@", url);
        dispatch_async(dispatch_get_main_queue(), ^{
            [_window setContentSize:NSMakeSize(_destinationWidth, _destinationHeight)];
            [[_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
            if (![[_webView mainFrame] provisionalDataSource]) {
                CCErrorLog(@"ERROR - web view missing data source, perhaps a bad url %@", url);
            }
        });
    } else if (shouldRender) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _captureImageFromWebView];
        });
    }

	return YES;
}

- (void)disableExecution:(id <QCPlugInContext>)context {
	/*
	Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
	*/
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
//    NSView* documentView = [[[sender mainFrame] frameView ] documentView];
//    CCDebugLog(@"main frame: (%fx%f)", NSWidth(documentView.bounds), NSHeight(documentView.bounds));

    dispatch_async(dispatch_get_main_queue(), ^{
        [self _captureImageFromWebView];
    });
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
    _window = [[SSWindow alloc] initWithContentRect:NSMakeRect(-16000., -16000., _destinationWidth, _destinationHeight) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    _webView = [[SSWebView alloc] initWithFrame:NSMakeRect(0., 0., _destinationWidth, _destinationHeight) frameName:nil groupName:nil];
    _webView.frameLoadDelegate = self;
    [_window setContentView:_webView];
}

- (void)_teardownWindow {
    CCDebugLogSelector();

    [_window setContentView:nil];
    _webView = nil;

    [_window close];
    _window = nil;
}

- (void)_captureImageFromWebView {
    CCDebugLogSelector();

    // size to fit
    NSView* documentView = [[[_webView mainFrame] frameView] documentView];
    NSSize documentSize = [documentView bounds].size;
    BOOL shouldResize = !NSEqualSizes([(NSView*)[_window contentView] bounds].size, documentSize);
    if (shouldResize) {
        [_window setContentSize:[documentView bounds].size];
    }

    NSBitmapImageRep* bitmap = [_webView bitmapImageRepForCachingDisplayInRect:[_webView visibleRect]];
    [_webView cacheDisplayInRect:[_webView visibleRect] toBitmapImageRep:bitmap];

//    NSString* path = [NSString stringWithFormat:@"/tmp/SS-%f.png", [[NSDate date] timeIntervalSince1970]];
//    [[bitmap representationUsingType:NSPNGFileType properties:nil] writeToFile:path atomically:YES];

    CGImageRelease(_renderedImage);
    _renderedImage = CGImageRetain([bitmap CGImage]);

    _doneSignal = YES;
    _doneSignalDidChange = YES;
}

@end
