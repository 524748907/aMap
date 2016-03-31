/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import "AnimatedAnnotationView.h"
#import "ACGDAnnotaion.h"
#import "UZAppUtils.h"

@interface AnimatedAnnotationView ()

@property (nonatomic, strong) NSMutableArray *animatedImages;
@property (nonatomic, assign) float interval;

@end

@implementation AnimatedAnnotationView

@synthesize imageView = _imageView;
@synthesize animatedImages = _animatedImages;
@synthesize interval = _interval;
@synthesize bubbleView = _bubbleView;
@synthesize billboardView = _billboardView;

#pragma mark - Life Cycle -

- (id)initWithAnnotation:(id<MAAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self) {
        ACGDAnnotaion *animatedAnnotation = (ACGDAnnotaion *)self.annotation;
        if (![animatedAnnotation isKindOfClass:[ACGDAnnotaion class]]) {
            return self;
        }
        if (animatedAnnotation.pinIcons.count > 1) {
            self.interval = animatedAnnotation.interval;
            self.animatedImages = [NSMutableArray arrayWithCapacity:1];
            for (NSString *path in animatedAnnotation.pinIcons) {
                UIImage *imgn = [UIImage imageWithContentsOfFile:path];
                if (imgn) {
                    [self.animatedImages addObject:imgn];
                }
            }
            float kWidth = 66;
            float kHeight = 108;
            UIImage *firstPinImg = [self.animatedImages firstObject];
            kWidth = firstPinImg.size.width/2.0;
            kHeight = firstPinImg.size.height/2.0;
            [self setBounds:CGRectMake(0.f, 0.f, kWidth, kHeight)];
            [self setBackgroundColor:[UIColor clearColor]];
            self.imageView = [[UIImageView alloc] initWithFrame:self.bounds];
            [self addSubview:self.imageView];
        }
    }
    return self;
}

#pragma mark - Utility

- (void)updateImageView {
    if ([self.imageView isAnimating]) {
        [self.imageView stopAnimating];
    }
    self.imageView.animationImages = self.animatedImages;
    self.imageView.animationDuration = self.interval;
    self.imageView.animationRepeatCount = 0;
    [self.imageView startAnimating];
}

#pragma mark - Override -

- (void)setAnnotation:(id<MAAnnotation>)annotation {
    [super setAnnotation:annotation];
    [self updateImageView];
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
