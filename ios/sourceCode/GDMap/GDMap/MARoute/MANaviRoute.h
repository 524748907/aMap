/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import <Foundation/Foundation.h>
#import <AMapNaviKit/MAMapKit.h>
#import <AMapSearchKit/AMapSearchAPI.h>
#import "MANaviAnnotation.h"
#import "MANaviPolyline.h"
#import "LineDashPolyline.h"

@interface MANaviRoute : NSObject

@property (nonatomic, strong) NSArray *routePolylines;
@property (nonatomic, strong) NSArray *naviAnnotations;
@property (nonatomic, strong) UIColor *routeColor;
@property (nonatomic, strong) UIColor *walkingColor;

- (void)addToMapView:(MAMapView *)mapView;

- (void)removeFromMapView;

- (void)setNaviAnnotationVisibility:(BOOL)visible;

+ (instancetype)naviRouteForTransit:(AMapTransit *)transit;
+ (instancetype)naviRouteForPath:(AMapPath *)path withNaviType:(MANaviAnnotationType)type;
+ (instancetype)naviRouteForPolylines:(NSArray *)polylines andAnnotations:(NSArray *)annotations;

- (instancetype)initWithTransit:(AMapTransit *)transit;
- (instancetype)initWithPath:(AMapPath *)path withNaviType:(MANaviAnnotationType)type;
- (instancetype)initWithPolylines:(NSArray *)polylines andAnnotations:(NSArray *)annotations;

@end
