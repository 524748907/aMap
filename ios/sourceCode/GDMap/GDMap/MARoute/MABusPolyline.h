//
//  MABusPolyline.h
//  UZEngine
//
//  Created by zhengcuan on 15/12/19.
//  Copyright © 2015年 uzmap. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import <AMapNaviKit/MAMapKit.h>
#import <MAMapKit/MAMapKit.h>

@interface MABusPolyline : NSObject<MAOverlay>

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly) MAMapRect boundingMapRect;
@property (nonatomic, retain)  MAPolyline *polyline;

- (id)initWithPolyline:(MAPolyline *)polyline;

@end
