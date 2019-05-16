//
//  AMapBillboardLabel.m
//  UZApp
//
//  Created by Turbo Sun on 2019/5/7.
//  Copyright © 2019 APICloud. All rights reserved.
//

#import "AMapBillboardLabel.h"

@interface AMapBillboardLabel ()

//@property (assign, nonatomic) UIEdgeInsets edgeInsets;

@end

@implementation AMapBillboardLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.edgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    }
    return self;
}
- (void)drawRect:(CGRect)rect
{
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.edgeInsets)];
}
- (CGSize)intrinsicContentSize
{
    CGSize size = [super intrinsicContentSize];
    size.width  += self.edgeInsets.left + self.edgeInsets.right;
    size.height += self.edgeInsets.top + self.edgeInsets.bottom;
    return size;
}

@end
