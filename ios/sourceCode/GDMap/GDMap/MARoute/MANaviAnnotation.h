//
//  MANaviAnnotation.h
//  OfficialDemo3D
//
//  Created by yi chen on 1/7/15.
//  Copyright (c) 2015 songjian. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import <AMapNaviKit/MAMapKit.h>
#import <MAMapKit/MAMapKit.h>

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
