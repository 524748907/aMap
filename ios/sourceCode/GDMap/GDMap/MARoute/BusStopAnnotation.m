/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import "BusStopAnnotation.h"

@interface BusStopAnnotation ()

@property (nonatomic, readwrite, strong) AMapBusStop *busStop;

@end

@implementation BusStopAnnotation
@synthesize busStop    = _busStop;
@synthesize type;

#pragma mark - MAAnnotation Protocol

- (NSString *)title
{
    return self.busStop.name;
}

- (NSString *)subtitle
{
    //return [NSString stringWithFormat:@"ID = %@", self.busStop.uid];
    return @"";
}

- (CLLocationCoordinate2D)coordinate
{
    return CLLocationCoordinate2DMake(self.busStop.location.latitude, self.busStop.location.longitude);
}

#pragma mark - Life Cycle

- (id)initWithBusStop:(AMapBusStop *)busStop
{
    if (self = [super init])
    {
        self.busStop = busStop;
    }
    
    return self;
}

@end
