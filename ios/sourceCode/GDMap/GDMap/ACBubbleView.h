//
//  ACBubbleView.h
//  UZEngine
//
//  Created by zhengcuan on 15/12/4.
//  Copyright © 2015年 APICloud. All rights reserved.
//

#import <UIKit/UIKit.h>

//#import "AMapAsyncImageView.h"
#import "ACAMButton.h"
#import "UIImageView+WebCache.h"

@interface NormalBubbleBgImgView : UIImageView

@property (nonatomic, strong) UIImageView *leftBgImgView, *rightBgImgView;
@property (nonatomic, strong) UIImageView *illusImgNetwork;
@property (nonatomic, strong) UIImageView *illusImgLocal;
@property (nonatomic, strong) ACAMButton *illusNetTap, *illusLocTap, *bubbleTap;
@property (nonatomic, strong) UILabel *titleLab, *subtitleLab;

@end

@interface ACBubbleView : UIView

@property (copy, nonatomic) void (^animationCompletion)(void);//动画结束
@property (nonatomic, strong) UIWebView *webBubbleView;
@property (nonatomic, strong) UIImageView *bubblleBgImgView;
@property (nonatomic, strong) NormalBubbleBgImgView *normalBgImgView;

- (void)show;
- (void)hide;

@end
