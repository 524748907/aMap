/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import <AMapNaviKit/MAMapKit.h>
#import "MANaviAnnotation.h"

@interface MANaviPolyline : NSObject<MAOverlay>

@property (nonatomic, assign) MANaviAnnotationType type;
@property (nonatomic, strong) MAPolyline *polyline;

- (id)initWithPolyline:(MAPolyline *)polyline;

@end
