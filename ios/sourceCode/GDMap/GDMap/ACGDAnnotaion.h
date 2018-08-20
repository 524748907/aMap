//
//  UZGDAnnotaion.h
//  UZEngine
//
//  Created by zhengcuan on 15/11/26.
//  Copyright © 2015年 APICloud. All rights reserved.
//

//#import <AMapNaviKit/MAMapKit.h>
#import <MAMapKit/MAMapKit.h>

typedef enum {
    ANNOTATION_MARKE = 0,  //标注
    ANNOTATION_BILLBOARD,  //布告牌
    ANNOTATION_MOBILEGD      //可移动的标注
} AnnotationType;

@protocol CanMovingAnimationDelegate;

@interface ACGDAnnotaion : MAAnimatedAnnotation

@property (nonatomic, assign) AnnotationType type;      //annotation的类型
@property (nonatomic, assign) NSInteger annotId;        //annotation的id
@property (nonatomic, assign) NSInteger clickCbId;      //annotation点击回调id
@property (nonatomic, assign) NSInteger bubbleClickCbid;//annotation气泡点击回调id
@property (nonatomic, assign) NSInteger moveAnnoCbid;   //可移动的标注回调id
@property (nonatomic, assign) NSInteger addBillboardCbid;//添加布告牌标注的回调id
@property (nonatomic, assign) NSInteger moveAnnoEndCbid;//标注移动结束的回调id
@property (nonatomic, strong) NSArray *pinIcons;        //annotation的icon图标
@property (nonatomic, strong) NSArray *selPinIcons;        //annotation的选中后的icon图标
@property (nonatomic, assign) BOOL draggable;           //annotation是否可拖动
@property (nonatomic, assign) float interval;           //annotation标注动画时间
@property (nonatomic, assign) BOOL haveBubble;          //annotation是否点击弹出气泡
@property (nonatomic, copy) NSString *bubbleBgImg, *billBgImg, *mobileBgImg;//annotation的气泡的背景图片
@property (nonatomic, assign) BOOL billboardSelected;
@property (nonatomic, strong) NSDictionary *selectedBillStyle; //选中后的布告牌的样式
@property (nonatomic, strong) NSDictionary *contentDict;//annotation的气泡的内如文本信息
@property (nonatomic, strong) NSDictionary *stylesDict; //annotation的气泡的样式信息
@property (nonatomic, strong) NSDictionary *webBubbleDict; //加载网页的的气泡的样式信息

//可移动的标注
@property (nonatomic, assign) float currentAngle;   //annotation的图标当前旋转角度（与x轴正向之间的角度）
@property (nonatomic, assign) float moveDuration;   //annotation的图标移动时间
@property (nonatomic, assign) CLLocationCoordinate2D toCoords, fromCoords;
@property (nonatomic, assign) CFTimeInterval lastStep;
@property (nonatomic, assign) NSTimeInterval timeOffset;
@property (nonatomic, assign) id <CanMovingAnimationDelegate> delegate;

- (void)moveStep;

@end

@protocol CanMovingAnimationDelegate <NSObject>

@optional
- (void)willMoving:(ACGDAnnotaion *)anno;
- (void)didMovingAnimationFinished:(ACGDAnnotaion *)anno;

@end
