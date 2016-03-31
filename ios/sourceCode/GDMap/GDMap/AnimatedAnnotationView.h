/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import <AMapNaviKit/MAMapKit.h>
#import "ACBubbleView.h"

@interface AnimatedAnnotationView : MAAnnotationView

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) ACBubbleView *bubbleView;
@property (nonatomic, strong) UIView *billboardView;

@end
