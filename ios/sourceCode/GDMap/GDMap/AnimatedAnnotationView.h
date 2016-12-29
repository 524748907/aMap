//
//  GDMap.h
//  UZEngine
//
//  Created by zhengcuan on 15/10/26.
//  Copyright © 2015年 APICloud. All rights reserved.
//

//#import <AMapNaviKit/MAMapKit.h>
#import <MAMapKit/MAMapKit.h>
#import "ACBubbleView.h"

@interface AnimatedAnnotationView : MAAnnotationView

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) ACBubbleView *bubbleView;
@property (nonatomic, strong) UIView *billboardView;

@end
