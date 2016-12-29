//
//  ACBubbleView.h
//  UZEngine
//
//  Created by zhengcuan on 15/12/4.
//  Copyright © 2015年 APICloud. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ACBubbleView : UIView

@property (copy, nonatomic) void (^animationCompletion)(void);//动画结束

- (void)show;
- (void)hide;

@end
