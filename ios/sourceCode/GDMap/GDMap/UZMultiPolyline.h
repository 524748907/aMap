//
//  UZMultiPolyline.h
//  UZEngine
//
//  Created by zhengcuan on 16/7/21.
//  Copyright © 2016年 uzmap. All rights reserved.
//

#import <MAMapKit/MAMapKit.h>

@interface UZMultiPolyline : MAMultiPolyline

@property (nonatomic, assign) float locusWidth;
@property (nonatomic, strong) NSMutableArray *colorsAry;

@end
