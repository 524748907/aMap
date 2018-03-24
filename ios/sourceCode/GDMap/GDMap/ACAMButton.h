//
//  ACAMButton.h
//  UZEngine
//
//  Created by zhengcuan on 15/12/7.
//  Copyright © 2015年 uzmap. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ACAMButton : UIButton

@property (nonatomic, assign) NSInteger btnId;
@property (nonatomic, assign) NSInteger bubbleCbid;//点击气泡的按钮的回调id
@property (nonatomic, assign) NSInteger billboardCbid;//点击布告牌上的按钮的回调id

@end
