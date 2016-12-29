//
//  ACBubbleView.m
//  UZEngine
//
//  Created by zhengcuan on 15/12/4.
//  Copyright © 2015年 APICloud. All rights reserved.
//

#import "ACBubbleView.h"

@interface ACBubbleView ()
{
    UIColor *bgColor;               //背景色
    UIColor *shadowColor;           //阴影色
    float forwardAnimationDuration; //弹出时间
    float backwardAnimationDuration;//关闭时间
}

@end

@implementation ACBubbleView

#pragma mark Life cycle

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        bgColor = [UIColor clearColor];
        shadowColor = [UIColor grayColor];
        forwardAnimationDuration = 0.2f;
        backwardAnimationDuration = 0.2f;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

#pragma mark - Showing popup

- (void)show {
    self.hidden = NO;
    CABasicAnimation *forwardAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    forwardAnimation.duration = forwardAnimationDuration;
    forwardAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.5f :1.7f :0.6f :0.85f];
    forwardAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
    forwardAnimation.toValue = [NSNumber numberWithFloat:1.0f];
    
    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    animationGroup.animations = [NSArray arrayWithObjects:forwardAnimation, nil];
    animationGroup.delegate = self;
    animationGroup.duration = forwardAnimation.duration;
    animationGroup.removedOnCompletion = NO;
    animationGroup.fillMode = kCAFillModeForwards;
    
    [UIView animateWithDuration:animationGroup.duration
                          delay:0.0
                        options:0
                     animations:^{
                         [self.layer addAnimation:animationGroup
                                           forKey:@"kLPAnimationKeyPopup"];
                     }
                     completion:^(BOOL finished) {
                     }];
}

- (void)hide {
     CABasicAnimation *reverseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
     reverseAnimation.duration = backwardAnimationDuration;
     reverseAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.4f :0.15f :0.5f :-0.7f];
     reverseAnimation.fromValue = [NSNumber numberWithFloat:1.0f];
     reverseAnimation.toValue = [NSNumber numberWithFloat:0.0f];
    
    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    animationGroup.animations = [NSArray arrayWithObjects:reverseAnimation, nil];
    animationGroup.delegate = self;
    animationGroup.duration = reverseAnimation.duration;
    animationGroup.removedOnCompletion = NO;
    animationGroup.fillMode = kCAFillModeForwards;
    
    [UIView animateWithDuration:animationGroup.duration
                          delay:0.0
                        options:0
                     animations:^{
                         [self.layer addAnimation:animationGroup
                                           forKey:@"kLPAnimationKeyPopup"];
                     }
                     completion:^(BOOL finished) {
                         self.hidden = NO;
                     }];
}

#pragma mark - Core animation delegate

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    if(flag) {
        if(self.animationCompletion) {
            self.animationCompletion();
        }
    }
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, 5.0f, 5.0f) cornerRadius:0.0f];
    CGContextSetFillColorWithColor(context, bgColor.CGColor);
    CGContextFillPath(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 0.5f), 3.0f, shadowColor.CGColor);
    CGContextAddPath(context, roundedRect.CGPath);
    CGContextDrawPath(context, kCGPathFill);
    CGContextRestoreGState(context);
    [super drawRect:rect];
}

@end
