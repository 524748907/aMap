/**
 * APICloud Modules
 * Copyright (c) 2014-2015 by APICloud, Inc. All Rights Reserved.
 * Licensed under the terms of the The MIT License (MIT).
 * Please see the license.html included with this distribution for details.
 */

#import <AMapNaviKit/MAMapKit.h>

typedef enum {
    ANNOTATION_MARKE = 0,  //标注
    ANNOTATION_BILLBOARD,  //布告牌
    ANNOTATION_MOBILEGD      //可移动的标注
} AnnotationType;

@protocol CanMovingAnimationDelegate;

@interface ACGDAnnotaion : MAPointAnnotation

@property (nonatomic, assign) AnnotationType type;      //annotation的类型
@property (nonatomic, assign) NSInteger annotId;        //annotation的id
@property (nonatomic, strong) NSArray *pinIcons;        //annotation的icon图标
@property (nonatomic, assign) BOOL draggable;           //annotation是否可拖动
@property (nonatomic, assign) float interval;           //annotation标注动画时间
@property (nonatomic, assign) BOOL haveBubble;          //annotation是否点击弹出气泡
@property (nonatomic, strong) NSString *bubbleBgImg, *billBgImg, *mobileBgImg;//annotation的气泡的背景图片
@property (nonatomic, strong) NSDictionary *contentDict;//annotation的气泡的内如文本信息
@property (nonatomic, strong) NSDictionary *stylesDict; //annotation的气泡的样式信息

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
- (void)didMoving:(ACGDAnnotaion *)anno;

@end
