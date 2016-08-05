/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import <UIKit/UIKit.h>

@interface ACBubbleView : UIView

@property (copy, nonatomic) void (^animationCompletion)(void);//动画结束

- (void)show;
- (void)hide;

@end
