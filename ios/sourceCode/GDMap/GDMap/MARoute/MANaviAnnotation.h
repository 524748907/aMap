/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import <Foundation/Foundation.h>
#import <AMapNaviKit/MAMapKit.h>

typedef NS_ENUM(NSInteger, MANaviAnnotationType)
{
    MANaviAnnotationTypeDrive = 0,
    MANaviAnnotationTypeWalking = 1,
    MANaviAnnotationTypeBus = 2,
    MANaviAnnotationTypeStart = 3,
    MANaviAnnotationTypeEnd = 4
};

@interface MANaviAnnotation : MAPointAnnotation

@property (nonatomic) MANaviAnnotationType type;

@end
