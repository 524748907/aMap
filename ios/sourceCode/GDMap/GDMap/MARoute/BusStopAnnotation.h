/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import <AMapNaviKit/MAMapKit.h>
#import <AMapSearchKit/AMapCommonObj.h>

@interface BusStopAnnotation : NSObject <MAAnnotation>

- (id)initWithBusStop:(AMapBusStop *)busStop;

@property (nonatomic, readonly, strong) AMapBusStop *busStop;

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;

@property (nonatomic, assign) NSInteger type;

/*!
 @brief 获取annotation标题
 @return 返回annotation的标题信息
 */
- (NSString *)title;

/*!
 @brief 获取annotation副标题
 @return 返回annotation的副标题信息
 */
- (NSString *)subtitle;

@end
