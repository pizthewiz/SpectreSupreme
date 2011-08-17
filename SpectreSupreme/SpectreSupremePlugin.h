//
//  SpectreSupremePlugin.h
//  SpectreSupreme
//
//  Created by Jean-Pierre Mouilleseaux on 13 Jun 2011.
//  Copyright 2011 Chorded Constructions. All rights reserved.
//

#import <Quartz/Quartz.h>

@class SSWindow, SSWebView;

@interface SpectreSupremePlugIn : QCPlugIn {
@private
    SSWindow* _window;
    SSWebView* _webView;
    CGImageRef _renderedImage;
    id<QCPlugInOutputImageProvider> _placeHolderProvider;

    NSURL* _location;
    NSUInteger _destinationWidth;
    NSUInteger _destinationHeight;
    BOOL _doneSignal;
    BOOL _doneSignalDidChange;
}
@property (nonatomic, unsafe_unretained) NSString* inputLocation;
@property (nonatomic) NSUInteger inputDestinationWidth;
@property (nonatomic) NSUInteger inputDestinationHeight;
@property (nonatomic) BOOL inputRenderSignal;
@property (nonatomic, unsafe_unretained) id<QCPlugInOutputImageProvider> outputImage;
@property (nonatomic) BOOL outputDoneSignal;
@end
