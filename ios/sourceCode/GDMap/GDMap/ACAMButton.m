//
//  ACAMButton.m
//  UZEngine
//
//  Created by zhengcuan on 15/12/7.
//  Copyright © 2015年 uzmap. All rights reserved.
//

#import "ACAMButton.h"

@implementation ACAMButton

@synthesize btnId;
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/
+ (instancetype)buttonWithType:(UIButtonType)buttonType {
    ACAMButton *btnSelf = [super buttonWithType:buttonType];
    if (btnSelf) {
        btnSelf.bubbleCbid = -1;
    }
    return [super buttonWithType:buttonType];
}

@end
