//
//  SpectreSupremePlugin.h
//  SpectreSupreme
//
//  Created by Jean-Pierre Mouilleseaux on 13 Jun 2011.
//  Copyright 2011 Chorded Constructions. All rights reserved.
//

#import <Quartz/Quartz.h>

@interface SpectreSupremePlugIn : QCPlugIn {
@private
    NSURL* _location;
    BOOL _doneSignal;
    BOOL _doneSignalDidChange;
}
@property (nonatomic, assign) NSString* inputLocation;
@property (nonatomic, assign) id<QCPlugInOutputImageProvider> outputImage;
@property (nonatomic) BOOL outputDoneSignal;
@end
