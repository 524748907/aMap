//
//  MABusPolyline.m
//  UZEngine
//
//  Created by zhengcuan on 15/12/19.
//  Copyright © 2015年 uzmap. All rights reserved.
//

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
