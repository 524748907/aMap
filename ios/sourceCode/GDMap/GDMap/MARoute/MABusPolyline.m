/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import "MABusPolyline.h"

@implementation MABusPolyline
@synthesize coordinate;

@synthesize boundingMapRect ;

@synthesize polyline = _polyline;

- (id)initWithPolyline:(MAPolyline *)polyline
{
    self = [super init];
    if (self)
    {
        self.polyline = polyline;
    }
    return self;
}

- (CLLocationCoordinate2D) coordinate
{
    return [_polyline coordinate];
}

- (MAMapRect) boundingMapRect
{
    return [_polyline boundingMapRect];
}

@end
