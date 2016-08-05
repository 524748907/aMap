/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import "ACGDAnnotaion.h"

static double interpolate(double from, double to, NSTimeInterval time) {
    return (to - from) * time + from;
}

static CLLocationDegrees interpolateDegrees(CLLocationDegrees from, CLLocationDegrees to, NSTimeInterval time) {
    return interpolate(from, to, time);
}

static CLLocationCoordinate2D interpolateCoordinate(CLLocationCoordinate2D from, CLLocationCoordinate2D to, NSTimeInterval time) {
    return CLLocationCoordinate2DMake(interpolateDegrees(from.latitude, to.latitude, time), interpolateDegrees(from.longitude, to.longitude, time));
}

@implementation ACGDAnnotaion

@synthesize type;
@synthesize annotId;
@synthesize pinIcons;
@synthesize draggable, haveBubble;
@synthesize interval;
@synthesize bubbleBgImg, billBgImg, mobileBgImg;
@synthesize contentDict, stylesDict;
@synthesize currentAngle, moveDuration;
@synthesize fromCoords, toCoords;
@synthesize lastStep, timeOffset;
@synthesize delegate;

- (void)dealloc {
    if (self.delegate) {
        self.delegate = nil;
    }
}

- (id)init {
    if (self = [super init]) {
        self.interval = 3.0;
        self.haveBubble = NO;
        self.type = ANNOTATION_MARKE;
    }
    return self;
}

- (void)moveStep {
    CFTimeInterval thisStep = CACurrentMediaTime();
    CFTimeInterval stepDuration = thisStep - self.lastStep;
    self.lastStep = thisStep;
    self.timeOffset = MIN(self.timeOffset + stepDuration, moveDuration);
    NSTimeInterval time = self.timeOffset / self.moveDuration;
    CLLocationCoordinate2D coords = interpolateCoordinate(fromCoords, toCoords, time);
    [self setCoordinate:coords];
    if (self.timeOffset >= moveDuration) {
        self.timeOffset = 0;
        if ([self.delegate respondsToSelector:@selector(didMoving:)]) {
            [self.delegate didMoving:self];
        }
    }
}

@end
