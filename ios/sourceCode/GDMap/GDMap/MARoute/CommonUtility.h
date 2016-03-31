/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import <Foundation/Foundation.h>
#import <AMapNaviKit/MAMapKit.h>
#import <AMapSearchKit/AMapSearchAPI.h>

@interface CommonUtility : NSObject

+ (CLLocationCoordinate2D *)coordinatesForString:(NSString *)string
                                 coordinateCount:(NSUInteger *)coordinateCount
                                      parseToken:(NSString *)token;

+ (MAPolyline *)polylineForCoordinateString:(NSString *)coordinateString;

+ (MAPolyline *)polylineForStep:(AMapStep *)step;

+ (MAPolyline *)polylineForBusLine:(AMapBusLine *)busLine;

+ (NSArray *)polylinesForWalking:(AMapWalking *)walking;

+ (NSArray *)polylinesForSegment:(AMapSegment *)segment;

+ (NSArray *)polylinesForPath:(AMapPath *)path;

+ (NSArray *)polylinesForTransit:(AMapTransit *)transit;


+ (MAMapRect)unionMapRect1:(MAMapRect)mapRect1 mapRect2:(MAMapRect)mapRect2;

+ (MAMapRect)mapRectUnion:(MAMapRect *)mapRects count:(NSUInteger)count;

+ (MAMapRect)mapRectForOverlays:(NSArray *)overlays;


+ (MAMapRect)minMapRectForMapPoints:(MAMapPoint *)mapPoints count:(NSUInteger)count;

+ (MAMapRect)minMapRectForAnnotations:(NSArray *)annotations;

@end
