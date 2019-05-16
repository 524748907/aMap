//
//  GDMap.h
//  UZEngine
//
//  Created by zhengcuan on 15/10/26.
//  Copyright © 2015年 APICloud. All rights reserved.
//

#import "AnimatedAnnotationView.h"
#import "ACGDAnnotaion.h"
#import "UZAppUtils.h"

@interface AnimatedAnnotationView ()

@property (nonatomic, strong) NSMutableArray *animatedImages;
@property (nonatomic, assign) float interval;

@end

@implementation AnimatedAnnotationView

#pragma mark - Life Cycle -

- (id)initWithAnnotation:(id<MAAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self) {
        [self refreshAnimatedPin:annotation];
    }
    return self;
}
//刷新动态图
- (void)refreshAnimatedPin:(id<MAAnnotation>)annotation {
    ACGDAnnotaion *animatedAnnotation = (ACGDAnnotaion *)annotation;
    if (![animatedAnnotation isKindOfClass:[ACGDAnnotaion class]]) {
        return ;
    }
    if (animatedAnnotation.pinIcons.count > 1) {
        self.interval = animatedAnnotation.interval;
        //如果是选中状态
        NSArray *imageDataSource = animatedAnnotation.pinIcons;
        if (self.isSelected) {
            imageDataSource = animatedAnnotation.selPinIcons;
        }
        if (!self.animatedImages) {
            self.animatedImages = [NSMutableArray array];
            for (NSString *path in imageDataSource) {
                UIImage *imgn = [UIImage imageWithContentsOfFile:path];
                if (imgn) {
                    [self.animatedImages addObject:imgn];
                }
            }
        } else {
            [self.animatedImages removeAllObjects];
            for (NSString *path in imageDataSource) {
                UIImage *imgn = [UIImage imageWithContentsOfFile:path];
                if (imgn) {
                    [self.animatedImages addObject:imgn];
                }
            }
        }
        float kWidth = 66;
        float kHeight = 108;
        UIImage *firstPinImg = [self.animatedImages firstObject];
        kWidth = firstPinImg.size.width/2.0;
        kHeight = firstPinImg.size.height/2.0;
//        [self setBounds:CGRectMake(0.f, 0.f, kWidth, kHeight)];
        [self setBounds:CGRectMake(0.f, 0.f, (animatedAnnotation.w == -1)?kWidth:animatedAnnotation.w, (animatedAnnotation.h == -1)?kHeight:animatedAnnotation.h)];

        [self setBackgroundColor:[UIColor clearColor]];
        if (!self.animationView) {
            self.animationView = [[UIImageView alloc] initWithFrame:self.bounds];
            [self addSubview:self.animationView];
        }
        [self updateAnimationView];
    }
}

#pragma mark - Utility

- (void)updateAnimationView {
    if ([self.animationView isAnimating]) {
        [self.animationView stopAnimating];
    }
    self.animationView.animationImages = self.animatedImages;
    self.animationView.animationDuration = self.interval;
    self.animationView.animationRepeatCount = 0;
    [self.animationView startAnimating];
}

#pragma mark - Override -

- (void)setAnnotation:(id<MAAnnotation>)annotation {
    [super setAnnotation:annotation];
    [self updateAnimationView];
}

- (void)setBubbleView:(ACBubbleView *)bubbleView {
    if (_bubbleView != bubbleView) {
        [_bubbleView removeFromSuperview];
        _bubbleView = bubbleView;
        [self addSubview:_bubbleView];
    }
    _bubbleView.center = CGPointMake(CGRectGetWidth(self.bounds) / 2.f + self.calloutOffset.x, -CGRectGetHeight(_bubbleView.bounds) / 2.f + self.calloutOffset.y);
}

- (void)setBillboardView:(UIView *)billboardView {
    if (_billboardView != billboardView) {
        [_billboardView removeFromSuperview];
        _billboardView = billboardView;
        self.bounds = _billboardView.bounds;
        [self addSubview:_billboardView];
    }
}

- (void)setWebBillboardView:(UIView *)webBillboardView {
    if (_webBillboardView != webBillboardView) {
        [_webBillboardView removeFromSuperview];
        _webBillboardView = webBillboardView;
        self.bounds = _webBillboardView.bounds;
        [self addSubview:_webBillboardView];
    }
}

- (void)setSelected:(BOOL)selected {
    [self setSelected:selected animated:NO];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    if (self.selected == selected) {
        return;
    }
    if (selected) {
        [self.bubbleView show];
    } else {
        [self.bubbleView hide];
    }
    [super setSelected:selected animated:YES];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    BOOL inside = [super pointInside:point withEvent:event];
    /* Points that lie outside the receiver’s bounds are never reported as hits,
     even if they actually lie within one of the receiver’s subviews.
     This can occur if the current view’s clipsToBounds property is set to NO and the affected subview extends beyond the view’s bounds.
     */
    if (!inside && self.selected) {
        inside = [self.bubbleView pointInside:[self convertPoint:point toView:self.bubbleView] withEvent:event];
    }
    return inside;
}
@end
