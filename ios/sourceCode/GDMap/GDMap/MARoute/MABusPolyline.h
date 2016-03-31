/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import <Foundation/Foundation.h>
#import <AMapNaviKit/MAMapKit.h>

@interface MABusPolyline : NSObject<MAOverlay>

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly) MAMapRect boundingMapRect;
@property (nonatomic, retain)  MAPolyline *polyline;

- (id)initWithPolyline:(MAPolyline *)polyline;

@end
