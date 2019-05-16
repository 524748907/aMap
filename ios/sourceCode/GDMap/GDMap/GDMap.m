//
//  GDMap.m
//  UZEngine
//
//  Created by zhengcuan on 15/10/26.
//  Copyright © 2015年 APICloud. All rights reserved.
//

#import "GDMap.h"
#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import "NSDictionaryUtils.h"
#import "UZAppUtils.h"
#import <CoreLocation/CoreLocation.h>
#import "ACGDAnnotaion.h"
#import "AnimatedAnnotationView.h"
#import "UIImageView+WebCache.h"
#import <AMapSearchKit/AMapSearchKit.h>
#import "MANaviRoute.h"
#import "CommonUtility.h"
#import "BusStopAnnotation.h"
#import "MABusPolyline.h"
#import "UZMultiPolyline.h"
#import "ACDistrictSearch.h"
#import "ACDistrictLine.h"
#import "AMapBillboardLabel.h"

typedef NS_ENUM(NSInteger, AMapRoutePlanningType) {
    AMapRoutePlanningTypeDrive = 0, //驾车
    AMapRoutePlanningTypeWalk,      //步行
    AMapRoutePlanningTypeBus,        //公交
    AMapRoutePlanningTypeRide        //骑行
};

#define BUBBLEVIEW_PAOVIEW    1010
#define BUBBLEVIEW_LEFTPAO    1011
#define BUBBLEVIEW_RIGHTPAO   1012
#define BUBBLEVIEW_ILLUSAS    1020
#define BUBBLEVIEW_ILLUSASBTN 1021
#define BUBBLEVIEW_ILLUSIM    1022
#define BUBBLEVIEW_ILLUSIMBTN 1023
#define BUBBLEVIEW_TITLE      1030
#define BUBBLEVIEW_SUBTITLE   1031
#define BUBBLEVIEW_CONTENTCK  1040
#define BILLBOARD_BGIMG       1050
#define BILLBOARD_ILLUS       1051
#define BILLBOARD_TITLE       1052
#define BILLBOARD_SUBTITLE    1053
#define BILLBOARD_BUTTON      1054
#define WEBBILLBOARD_BGIMG       1055
#define WEBBILLBOARD_BGWEB       1056
#define ANNOTATION_MOBILETAG     1060

@interface GDMap ()
<MAMapViewDelegate, CanMovingAnimationDelegate, AMapSearchDelegate,UIGestureRecognizerDelegate, MAMultiPointOverlayRendererDelegate> {
    MAMapView *_mapView;
    BOOL firstShowLocation;
    //定位
    NSInteger getLocationCbid;
    BOOL getLocationAutostop;
    MAUserLocation *currentUserLocation;
    //监听地图事件id
    NSInteger longPressCbid, viewChangeCbid, singleTapCbid, trackingModeCbid, zoomLisCbid;
    //标注气泡类
    NSMutableDictionary *_allMovingAnno;//可移动的标注集合
    //覆盖物类
    NSMutableDictionary *_allOverlays;
    NSDictionary *overlayStyles, *multiPointStyles;//覆盖物样式
    NSInteger multiPointCbid;
    //添加路线类
    AMapSearchAPI *_mapSearch;
    NSInteger searcRouteCbid;
    NSMutableDictionary *_allRoutes;
    AMapRoute *_routePlans;
    BOOL canDraw;
    NSDictionary *routeStyles;
    //搜索添加公交线路类
    NSInteger getBusRouteCbid;
    NSArray *_allBusLines;
    NSDictionary *busLineStyles;
    NSMutableDictionary *_allBusRoutes;
    //纯搜索类
    NSInteger poiSearchCbid, autoComplateCbid;
    //地理编码搜索
    NSInteger getLoctionByAddrCbid, getAddrByLocationCbid;
    //网页气泡
    NSInteger webBubbleCbid;
    //选中的billboard
    ACGDAnnotaion *currentSelectedBillboard;
}

@property (nonatomic, strong) MAMapView *mapView;
@property (nonatomic, strong) NSMutableDictionary *allMovingAnno; //所有可移动的标注集合
@property (nonatomic, strong) CADisplayLink *timerAnnoMove;       //标注移动的时间控制器
@property (nonatomic, strong) NSMutableDictionary *allOverlays;   //所有的覆盖物集合
@property (nonatomic, strong) AMapSearchAPI *mapSearch;           //搜索实例对象
@property (nonatomic, strong) NSMutableDictionary *allRoutes;     //所有添加的路线
@property (nonatomic, strong) AMapRoute *routePlans;              //所有添加的路线
@property (nonatomic) AMapRoutePlanningType routePlanningType;    //路径规划类型
@property (nonatomic, strong) MANaviRoute *naviRoute;             //用于显示当前路线方案
@property (nonatomic, strong) NSArray *allBusLines;               //搜索到的所有公交路线
@property (nonatomic, strong) NSMutableDictionary *allBusRoutes;  //所有添加的公交路线
@property (nonatomic, strong) NSDictionary *districtLineDict;     //边界线样式
@property (nonatomic, strong) UIImage *placeholdImage;            //标注占位图(空图片)
@property (nonatomic, strong) NSOperation *queryOperation;
@property (nonatomic, strong) UZModuleMethodContext *webBoardListener;

@end

@implementation GDMap

@synthesize mapView = _mapView;
@synthesize allMovingAnno = _allMovingAnno;
@synthesize timerAnnoMove;
@synthesize allOverlays = _allOverlays;
@synthesize mapSearch = _mapSearch;
@synthesize allRoutes = _allRoutes;
@synthesize routePlans = _routePlans;
@synthesize routePlanningType;
@synthesize naviRoute;
@synthesize allBusLines = _allBusLines;
@synthesize allBusRoutes = _allBusRoutes;

#pragma mark - lifeCycle -

- (void)dealloc {
    [self cancelProcessedTrace:nil];
    if (timerAnnoMove) {
        [timerAnnoMove invalidate];
        self.timerAnnoMove = nil;
    }
    if (_allMovingAnno) {
        for (ACGDAnnotaion *annoEle in _allMovingAnno) {
            if (annoEle.delegate) {
                annoEle.delegate = nil;
            }
        }
        [_allMovingAnno removeAllObjects];
        self.allMovingAnno = nil;
    }
}

- (void)dispose {
    [self cancelProcessedTrace:nil];
    [self close:nil];
}

- (id)initWithUZWebView:(UZWebView *)webView_ {
    self = [super initWithUZWebView:webView_];
    if (self != nil) {
        //
        NSDictionary *feature_location = [self getFeatureByName:@"aMap"];
        NSString *ios_api_key = [feature_location stringValueForKey:@"ios_api_key" defaultValue:nil];
        if (ios_api_key.length > 0) {
            [[AMapServices sharedServices] setEnableHTTPS:YES];
            [AMapServices sharedServices].apiKey = (NSString *)ios_api_key;
        } else {
            NSLog(@"Turbo_aMap_init_fail!");
        }
        zoomLisCbid = -1;
        self.timerAnnoMove = nil;
        canDraw = NO;
        poiSearchCbid = -1;
        webBubbleCbid = -1;
    }
    return self;
}

#pragma mark - interface -
#pragma mark 基础类
- (void)open:(NSDictionary *)paramsDict_ {
    if (self.mapView) {
        [[self.mapView superview] bringSubviewToFront:self.mapView];
        self.mapView.hidden = NO;
        return;
    }
    NSString *fixedOnName = [paramsDict_ stringValueForKey:@"fixedOn" defaultValue:nil];
    UIView *superView = [self getViewByName:fixedOnName];
    NSDictionary *rectInfo = [paramsDict_ dictValueForKey:@"rect" defaultValue:@{}];
    float orgX = [rectInfo floatValueForKey:@"x" defaultValue:0];
    float orgY = [rectInfo floatValueForKey:@"y" defaultValue:0];
    float viewW = [rectInfo floatValueForKey:@"w" defaultValue:superView.bounds.size.width];
    float viewH = [rectInfo floatValueForKey:@"h" defaultValue:superView.bounds.size.height];
    CGRect defaultRect = CGRectMake(orgX, orgY, viewW, viewH);
    CGRect newRect = [paramsDict_ rectValueForKey:@"rect" defaultValue:defaultRect relativeToSuperView:superView];
    
    BOOL fixed = [paramsDict_ boolValueForKey:@"fixed" defaultValue:YES];
    float zoomLevel = [paramsDict_ floatValueForKey:@"zoomLevel" defaultValue:10];
    BOOL isShow = [paramsDict_ boolValueForKey:@"showUserLocation" defaultValue:YES];
    BOOL showAccuracyCircle = [paramsDict_ boolValueForKey:@"showsAccuracyRing" defaultValue:YES];

    //显示地图
    self.mapView = [[MAMapView alloc]initWithFrame:newRect];
    self.mapView.frame = newRect;
    self.mapView.delegate = self;
    [self.mapView setZoomLevel:zoomLevel animated:NO];
    self.mapView.showsUserLocation = isShow;
    self.mapView.customizeUserLocationAccuracyCircleRepresentation = !showAccuracyCircle;
    self.mapView.mapType = MAMapTypeStandard;
//    self.mapView.mapType = MAMapTypeSatellite;
    [self addSubview:self.mapView fixedOn:fixedOnName fixed:fixed];
    firstShowLocation = YES;
    //[AMapServices sharedServices].enableHTTPS = YES;
    //设置父滚动视图的canCancelContentTouches
    UIWebView *webView = (UIWebView *)[self getViewByName:fixedOnName];
    id superViewObj = [webView superview];
    if (!fixed && [superViewObj isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scrollView = (UIScrollView *)superViewObj;
        scrollView.canCancelContentTouches = NO;
    }
    //设置地图中心点
    NSDictionary *centerInfo = [paramsDict_ dictValueForKey:@"center" defaultValue:@{}];
    float centerLon = [centerInfo floatValueForKey:@"lon" defaultValue:116.397647];
    float centerLat = [centerInfo floatValueForKey:@"lat" defaultValue:39.908259];
    if ([self isValidLon:centerLon lat:centerLat]) {
        firstShowLocation = NO;
        CLLocationCoordinate2D coord2d;
        coord2d.latitude = centerLat;
        coord2d.longitude = centerLon;
        [self.mapView setCenterCoordinate:coord2d animated:NO];
    }
    //回调
    NSInteger openCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    if (self.mapView && openCbid>=0 && [AMapServices sharedServices].apiKey.length>0){
        [self sendResultEventWithCallbackId:openCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"status"] errDict:nil doDelete:YES];
    } else {
        [self sendResultEventWithCallbackId:openCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"status"] errDict:nil doDelete:YES];
    }
}

- (void)takeSnapshotInRect:(NSDictionary *)paramsDict_ {
    if (!self.mapView) {
        return;
    }
    NSDictionary *rectInfo = [paramsDict_ dictValueForKey:@"rect" defaultValue:@{}];
    float orgX = [rectInfo floatValueForKey:@"x" defaultValue:0];
    float orgY = [rectInfo floatValueForKey:@"y" defaultValue:0];
    float viewW = [rectInfo floatValueForKey:@"w" defaultValue:self.mapView.bounds.size.width];
    float viewH = [rectInfo floatValueForKey:@"h" defaultValue:self.mapView.bounds.size.height];
    CGRect defaultRect = CGRectMake(orgX, orgY, viewW, viewH);

    NSString *imgPath = [paramsDict_ stringValueForKey:@"path" defaultValue:@""];
    if (imgPath.length == 0) {
        return;
    }
    imgPath = [self getPathWithUZSchemeURL:imgPath];
    NSString *pathStr = [imgPath stringByDeletingLastPathComponent];
    NSString *extention = [[imgPath pathExtension] uppercaseString];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:pathStr]) {        //创建路径
        [fileManager createDirectoryAtPath:pathStr withIntermediateDirectories:YES attributes:nil error:nil];
    }
    __weak typeof(self) weakSelf = self;
    NSInteger SnapshotCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    [self.mapView takeSnapshotInRect:defaultRect withCompletionBlock:^(UIImage *resultImage, NSInteger state) {
        NSData *data = nil;
        if ([extention isEqualToString:@"JPG"] || [extention isEqualToString:@"JPEG"]|| [extention isEqualToString:@"jpg"] || [extention isEqualToString:@"jpeg"]) {
            data = UIImageJPEGRepresentation(resultImage, 1.0);
        } else {
            data = UIImagePNGRepresentation(resultImage);
        }
        BOOL status = NO;
        if (data) {
            status = [fileManager createFileAtPath:imgPath contents:data attributes:nil];
        }
        //回调
        [weakSelf sendResultEventWithCallbackId:SnapshotCbid dataDict:@{@"status":@(status),@"realPath":imgPath} errDict:nil doDelete:YES];
    }];
}

- (void)close:(NSDictionary *)parmasDict_ {
    if (timerAnnoMove) {
        [timerAnnoMove invalidate];
        self.timerAnnoMove = nil;
    }
    if (_allMovingAnno) {
        for (ACGDAnnotaion *annoEle in [_allMovingAnno allValues]) {
            if (annoEle) {
                if (annoEle.delegate) {
                    annoEle.delegate = nil;
                }
            }
        }
        [_allMovingAnno removeAllObjects];
        self.allMovingAnno = nil;
    }
    if (self.mapView) {
        self.mapView.delegate = nil;
        [self.mapView removeFromSuperview];
        self.mapView = nil;
    }
    if (_allOverlays) {
        [_allOverlays removeAllObjects];
        self.allOverlays = nil;
    }
    if (_mapSearch) {
        _mapSearch.delegate = nil;
        self.mapSearch = nil;
    }
    if (_allRoutes) {
        [_allRoutes removeAllObjects];
        self.allRoutes = nil;
    }
    if (_routePlans) {
        self.routePlans = nil;
    }
    if (_allBusLines) {
        self.allBusLines = nil;
    }
    if (_allBusRoutes) {
        [_allBusRoutes removeAllObjects];
        self.allBusRoutes = nil;
    }
}

- (void)show:(NSDictionary *)parmasDict_ {
    if (self.mapView) {
        self.mapView.hidden = NO;
    }
}

- (void)hide:(NSDictionary *)parmasDict_ {
    if (self.mapView) {
        self.mapView.hidden = YES;
    }
}

- (void)setRect:(NSDictionary *)paramsDict_ {
    if (!_mapView) {
        return;
    }
//    NSDictionary *rectInfo = [paramsDict_ dictValueForKey:@"rect" defaultValue:@{}];
//    float orgX = [rectInfo floatValueForKey:@"x" defaultValue:_mapView.frame.origin.x];
//    float orgY = [rectInfo floatValueForKey:@"y" defaultValue:_mapView.frame.origin.y];
//    float viewW = [rectInfo floatValueForKey:@"w" defaultValue:_mapView.bounds.size.width];
//    float viewH = [rectInfo floatValueForKey:@"h" defaultValue:_mapView.bounds.size.height];
//    CGRect newRect = CGRectMake(orgX, orgY, viewW, viewH);
    UIView *superView = [self.mapView superview];
    CGRect newRect = [paramsDict_ rectValueForKey:@"rect" defaultValue:_mapView.frame relativeToSuperView:superView];
    [_mapView setFrame:newRect];
}

- (void)getLocation:(NSDictionary *)paramsDict_ {
    getLocationCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    getLocationAutostop = [paramsDict_ boolValueForKey:@"autoStop" defaultValue:YES];
    NSArray* backAry  = [[NSBundle mainBundle].infoDictionary objectForKey:@"UIBackgroundModes"];
    if (backAry && [backAry containsObject:@"location"]) {
        _mapView.pausesLocationUpdatesAutomatically = NO;
        _mapView.allowsBackgroundLocationUpdates = YES;//iOS9以上系统必须配置
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:3];
    if (currentUserLocation) {
        [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    } else {
        return;
    }
    if (getLocationCbid>=0) {
        [sendDict setObject:[NSNumber numberWithFloat:currentUserLocation.location.coordinate.latitude] forKey:@"lat"];
        [sendDict setObject:[NSNumber numberWithFloat:currentUserLocation.location.coordinate.longitude] forKey:@"lon"];
        [sendDict setObject:[NSNumber numberWithFloat:currentUserLocation.heading.trueHeading] forKey:@"heading"];
        double altitud = currentUserLocation.location.altitude;
        [sendDict setObject:@(altitud) forKey:@"altitude"];
        long long timestamp = (long long)([currentUserLocation.location.timestamp timeIntervalSince1970] * 1000);
        double acur = currentUserLocation.location.horizontalAccuracy;
        [sendDict setObject:@(acur) forKey:@"accuracy"];
        [sendDict setObject:[NSNumber numberWithLongLong:timestamp] forKey:@"timestamp"];
        
        //lgg
        [sendDict setObject:@(currentUserLocation.location.verticalAccuracy) forKey:@"verticalAccuracy"];
        [sendDict setObject:@(currentUserLocation.location.horizontalAccuracy) forKey:@"horizontalAccuracy"];
        [sendDict setObject:@(currentUserLocation.location.course) forKey:@"course"];
        [sendDict setObject:@(currentUserLocation.location.speed) forKey:@"speed"];
        if (currentUserLocation.location.floor) {
            [sendDict setObject:@(currentUserLocation.location.floor.level) forKey:@"floor"];
        }
        
        [self sendResultEventWithCallbackId:getLocationCbid dataDict:sendDict errDict:nil doDelete:getLocationAutostop];
        if (getLocationAutostop) {
            getLocationCbid = -1;
        }
    }
}

- (void)stopLocation:(NSDictionary *)paramsDict_ {
    getLocationCbid = -1;
    getLocationAutostop = YES;
}

- (void)getCoordsFromName:(NSDictionary *)paramsDict_ {
    NSString *addr =[paramsDict_ stringValueForKey:@"address" defaultValue:nil];
    NSString *city =[paramsDict_ stringValueForKey:@"city" defaultValue:nil];
    if (!addr || addr.length==0) {
        return;
    }
    if (![city isKindOfClass:[NSString class]] || city.length==0) {
        //return;
    }
    //搜索实例对象
    if (![self initSearchClass]) {
        return;
    }
    getLoctionByAddrCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    AMapGeocodeSearchRequest *geoRequest = [[AMapGeocodeSearchRequest alloc]init];
    geoRequest.address = addr;
    geoRequest.city = city;
    [self.mapSearch AMapGeocodeSearch:geoRequest];
}

- (void)getNameFromCoords:(NSDictionary *)paramsDict_ {
    getAddrByLocationCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    float lon = [paramsDict_ floatValueForKey:@"lon" defaultValue:360];
    float lat = [paramsDict_ floatValueForKey:@"lat" defaultValue:360];
    if (![self isValidLon:lon lat:lat]) {
        return;
    }
    //搜索实例对象
    if (![self initSearchClass]) {
        [self sendResultEventWithCallbackId:getAddrByLocationCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"status"] errDict:nil  doDelete:YES];
        return;
    }
    AMapReGeocodeSearchRequest *geoRequest = [[AMapReGeocodeSearchRequest alloc]init];
    AMapGeoPoint *regeoPoint = [[AMapGeoPoint alloc]init];;
    regeoPoint.latitude = lat;
    regeoPoint.longitude = lon;
    geoRequest.location = regeoPoint;
    [self.mapSearch AMapReGoecodeSearch:geoRequest];
}

- (void)getDistance:(NSDictionary *)paramsDict_ {
    NSInteger getDistanceCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSDictionary *startInfo = [paramsDict_ dictValueForKey:@"start" defaultValue:@{}];
    NSDictionary *endInfo = [paramsDict_ dictValueForKey:@"end" defaultValue:@{}];
    float startLon = [startInfo floatValueForKey:@"lon" defaultValue:360];
    float startLat = [startInfo floatValueForKey:@"lat" defaultValue:360];
    float endLon = [endInfo floatValueForKey:@"lon" defaultValue:360];
    float endLat = [endInfo floatValueForKey:@"lat" defaultValue:360];
    if (![self isValidLon:startLon lat:startLat]) {
        return;
    }
    if (![self isValidLon:endLon lat:endLat]) {
        return;
    }
    //1.将两个经纬度点转成投影点
    MAMapPoint point1 = MAMapPointForCoordinate(CLLocationCoordinate2DMake(startLat,startLon));
    MAMapPoint point2 = MAMapPointForCoordinate(CLLocationCoordinate2DMake(endLat,endLon));
    //2.计算距离
    CLLocationDistance dis = MAMetersBetweenMapPoints(point1,point2);
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:2];
    if (dis > 0) {
        [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
        [sendDict setObject:[NSNumber numberWithLongLong:dis] forKey:@"distance"];
    } else {
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    }
    [self sendResultEventWithCallbackId:getDistanceCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)showUserLocation:(NSDictionary *)paramsDict_ {
    BOOL isShow = [paramsDict_ boolValueForKey:@"isShow" defaultValue:YES];
     self.mapView.showsUserLocation = isShow;
    //自定义当前位置图标
    BOOL ring = [paramsDict_ boolValueForKey:@"showsAccuracyRing" defaultValue:YES];
    BOOL indicator = [paramsDict_ boolValueForKey:@"showsHeadingIndicator" defaultValue:YES];
    BOOL annimation = [paramsDict_ boolValueForKey:@"enablePulseAnnimation" defaultValue:YES];
    MAUserLocationRepresentation *r = [[MAUserLocationRepresentation alloc] init];
    ///精度圈是否显示，默认YES
    r.showsAccuracyRing = ring;
    ///是否显示方向指示(MAUserTrackingModeFollowWithHeading模式开启)。默认为YES
    r.showsHeadingIndicator = indicator;
    ///内部蓝色圆点是否使用律动效果, 默认YES
    r.enablePulseAnnimation = annimation;
    
    NSString *fillColor = [paramsDict_ stringValueForKey:@"fillColor" defaultValue:nil];
    if (fillColor.length > 0) {
        ///精度圈 填充颜色, 默认 kAccuracyCircleDefaultColor
        r.fillColor = [UZAppUtils colorFromNSString:fillColor];
    }
    NSString *strokeColor = [paramsDict_ stringValueForKey:@"strokeColor" defaultValue:nil];
    if (strokeColor.length > 0) {
        ///精度圈 边线颜色, 默认 kAccuracyCircleDefaultColor
        r.strokeColor = [UZAppUtils colorFromNSString:strokeColor];
    }
    NSString *dotBgColor = [paramsDict_ stringValueForKey:@"dotBgColor" defaultValue:nil];
    if (dotBgColor.length > 0) {
        ///定位点背景色，不设置默认白色
        r.locationDotBgColor = [UZAppUtils colorFromNSString:dotBgColor];
    }
    NSString *dotFillColor = [paramsDict_ stringValueForKey:@"dotFillColor" defaultValue:nil];
    if (dotFillColor.length > 0) {
        ///定位点蓝色圆点颜色，不设置默认蓝色
        r.locationDotFillColor = [UZAppUtils colorFromNSString:dotFillColor];
    }
    NSString *icon = [paramsDict_ stringValueForKey:@"imagePath" defaultValue:nil];
    if (icon.length > 0) {
        ///定位图标, 与蓝色原点互斥
        NSString *realPath = [self getPathWithUZSchemeURL:icon];
        r.image = [UIImage imageWithContentsOfFile:realPath];
    }
    float lineWidth = [paramsDict_ floatValueForKey:@"lineWidth" defaultValue:0];
    ///精度圈 边线宽度，默认0
    r.lineWidth = lineWidth;
    [self.mapView updateUserLocationRepresentation:r];
}

- (void)setTrackingMode:(NSDictionary *)paramsDict_ {
    NSString *trackType = [paramsDict_ stringValueForKey:@"trackingMode" defaultValue:@"none"];
    if (trackType.length == 0) {
        trackType = @"none";
    }
    MAUserTrackingMode trackmode = MAUserTrackingModeNone;
    if ([trackType isEqualToString:@"heading"]) {
        trackmode = MAUserTrackingModeFollowWithHeading;
    } else if ([trackType isEqualToString:@"follow"]) {
        trackmode = MAUserTrackingModeFollow;
    }
    BOOL animation = [paramsDict_ boolValueForKey:@"animation" defaultValue:YES];
    [self.mapView setUserTrackingMode:trackmode animated:animation];
}

- (void)setCenter:(NSDictionary *)paramsDict_ {
    if (!self.mapView) {
        return;
    }
    NSDictionary *centerInfo = [paramsDict_ dictValueForKey:@"coords" defaultValue:@{}];
    float longitude = [centerInfo floatValueForKey:@"lon" defaultValue:360];
    float latitude = [centerInfo floatValueForKey:@"lat" defaultValue:360];
    if (![self isValidLon:longitude lat:latitude]) {
        return;
    }
    CLLocationCoordinate2D location2D ;
    location2D.longitude = longitude;
    location2D.latitude = latitude;
    BOOL animation = [paramsDict_ boolValueForKey:@"animation" defaultValue:YES];
    [self.mapView setCenterCoordinate:location2D animated:animation];
}

- (void)getCenter:(NSDictionary *)paramsDict_ {
    NSInteger getDistanceCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    float lat = self.mapView.centerCoordinate.latitude;
    float lon = self.mapView.centerCoordinate.longitude;
    [sendDict setObject:[NSNumber numberWithFloat:lat] forKey:@"lat"];
    [sendDict setObject:[NSNumber numberWithFloat:lon] forKey:@"lon"];
    [self sendResultEventWithCallbackId:getDistanceCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)setZoomLevel:(NSDictionary *)paramsDict_ {
    float zoomlevel = [paramsDict_ floatValueForKey:@"level" defaultValue:10];
    BOOL animation = [paramsDict_ boolValueForKey:@"animation" defaultValue:YES];
    [self.mapView setZoomLevel:zoomlevel animated:animation];
}

- (void)getZoomLevel:(NSDictionary *)paramsDict_ {
    NSInteger zoomCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    float  level = self.mapView.zoomLevel;
    [self sendResultEventWithCallbackId:zoomCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:level] forKey:@"level"] errDict:nil doDelete:YES];
}

- (void)setMapAttr:(NSDictionary *)paramsDict_ {
    if (!_mapView) {
        return;
    }
    BOOL zoomEnable = [paramsDict_ boolValueForKey:@"zoomEnable" defaultValue:YES];
    [_mapView setZoomEnabled:zoomEnable];
    BOOL scrollEnable = [paramsDict_ boolValueForKey:@"scrollEnable" defaultValue:YES];
    self.mapView.scrollEnabled = scrollEnable;
    BOOL trafficOn = [paramsDict_ boolValueForKey:@"trafficOn" defaultValue:NO];
    self.mapView.showTraffic = trafficOn;
    BOOL rotateOverlookEnabled = [paramsDict_ boolValueForKey:@"overlookEnabled" defaultValue:NO];
    self.mapView.rotateEnabled = [paramsDict_ boolValueForKey:@"rotateEnabled" defaultValue:NO];
    self.mapView.rotateCameraEnabled = rotateOverlookEnabled;
    BOOL building = [paramsDict_ boolValueForKey:@"building" defaultValue:NO];
    self.mapView.showsBuildings = building;
    //设置地图类型
    NSString *mapType = [paramsDict_ stringValueForKey:@"type" defaultValue:@"standard"];
    MAMapType realMapType = MAMapTypeStandard;
    if ([mapType isEqualToString:@"satellite"]) {
        realMapType = MAMapTypeSatellite;
    } else if ([mapType isEqualToString:@"night"]) {
        realMapType = MAMapTypeStandardNight;
    }
    [_mapView setMapType:realMapType];
}

- (void)setRotation:(NSDictionary *)paramsDict_ {
    if (!_mapView) {
        return;
    }
    float rotation = [paramsDict_ floatValueForKey:@"degree" defaultValue:0];
    if (rotation > 180) {
        rotation = 180;
    }
    if (rotation < -180) {
        rotation = -180;
    }
    BOOL animation = [paramsDict_ boolValueForKey:@"animation" defaultValue:YES];
    BOOL duration = [paramsDict_ floatValueForKey:@"duration" defaultValue:0.3];
    //地图旋转角度，在手机上当前可使用的范围为－180～180度
    [self.mapView setRotationDegree:rotation animated:animation duration:duration];
}

- (void)getRotation:(NSDictionary *)paramsDict_ {
    NSInteger rotationCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    float  rotation = self.mapView.rotationDegree;
    [self sendResultEventWithCallbackId:rotationCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:rotation] forKey:@"rotation"] errDict:nil doDelete:YES];
}

- (void)setOverlook:(NSDictionary *)paramsDict_ {
    if (!_mapView) {
        return;
    }
    float overlook = [paramsDict_ floatValueForKey:@"degree" defaultValue:0];
    if (overlook > 60) {
        overlook = 60 ;
    }
    if (overlook < 0) {
        overlook = 0;
    }
    BOOL animation = [paramsDict_ boolValueForKey:@"animation" defaultValue:YES];
    BOOL duration = [paramsDict_ floatValueForKey:@"duration" defaultValue:0.3];
    //地图俯视角度，在手机上当前可使用的范围为0-60度
    [self.mapView setCameraDegree:overlook animated:animation duration:duration];
}

- (void)getOverlook:(NSDictionary *)paramsDict_ {
    NSInteger overlookCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    float  overlook = self.mapView.cameraDegree;
    [self sendResultEventWithCallbackId:overlookCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:overlook] forKey:@"overlook"] errDict:nil doDelete:YES];
}

- (void)setRegion:(NSDictionary *)paramsDict_ {
    float lbLon = [paramsDict_ floatValueForKey:@"lbLon" defaultValue:360];
    float lbLat = [paramsDict_ floatValueForKey:@"lbLat" defaultValue:360];
    float rtLon = [paramsDict_ floatValueForKey:@"rtLon" defaultValue:360];
    float rtLat = [paramsDict_ floatValueForKey:@"rtLat" defaultValue:360];
    if (![self isValidLon:lbLon lat:lbLat]) {
        return;
    }
    if (![self isValidLon:rtLon lat:rtLat]) {
        return;
    }
    BOOL animation = [paramsDict_ boolValueForKey:@"animation" defaultValue:YES];
    float centerLon, centerLat;
    if (lbLon>0 && rtLon<0) {
        return;
    } else {
        centerLon = (lbLon + rtLon)/2.0;
    }
    if (lbLat>0 && rtLat<0) {
        return;
    } else {
        centerLat = (lbLat + rtLat)/2.0;
    }
    
    CLLocationCoordinate2D centerCoords = CLLocationCoordinate2DMake(centerLat, centerLon);
    double latDelta, lonDelta;
    if (lbLat>0 && rtLat<0) {
        return;
    } else {
        latDelta = rtLat - lbLat;
    }
    if (lbLon>0 && rtLon<0) {
        return;
    } else {
        lonDelta = rtLon - lbLon;
    }
    MACoordinateSpan span;
    span.latitudeDelta = latDelta;
    span.longitudeDelta = lonDelta;
    MACoordinateRegion region = MACoordinateRegionMake(centerCoords, span);
    [self.mapView setRegion:region animated:animation];
}

- (void)getRegion:(NSDictionary *)paramsDict_ {
    NSInteger getRegionId = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    MACoordinateRegion region = self.mapView.region;
    CLLocationCoordinate2D center = region.center;
    double lat = center.latitude;
    double lon = center.longitude;
    MACoordinateSpan span = region.span;
    double spanLat = span.latitudeDelta;
    double spanLon = span.longitudeDelta;
    double lbLon, lbLat, rtLon, rtLat;
    lbLon = lon - spanLon;
    lbLat = lat - spanLat;
    rtLon = lon + spanLon;
    rtLat = lat + spanLat;
    //回调
    BOOL status;
    if ([self isValidLon:lbLon lat:lbLat]) {
        status = YES;
    } else {
        status = NO;
    }
    if ([self isValidLon:rtLon lat:rtLat]) {
        status = YES;
    } else {
        status = NO;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:2];
    [sendDict setObject:[NSNumber numberWithDouble:lbLat] forKey:@"lbLat"];
    [sendDict setObject:[NSNumber numberWithDouble:lbLon] forKey:@"lbLon"];
    [sendDict setObject:[NSNumber numberWithDouble:rtLat] forKey:@"rtLat"];
    [sendDict setObject:[NSNumber numberWithDouble:rtLon] forKey:@"rtLon"];
    [sendDict setObject:[NSNumber numberWithBool:status] forKey:@"status"];
    [self sendResultEventWithCallbackId:getRegionId dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)setScaleBar:(NSDictionary *)paramsDict_ {
    BOOL show = [paramsDict_ boolValueForKey:@"show" defaultValue:NO];
    if (show) {
        self.mapView.showsScale = YES;
    } else {
        self.mapView.showsScale = NO;
    }
    NSDictionary *position = [paramsDict_ dictValueForKey:@"position" defaultValue:@{}];
    float x = [position floatValueForKey:@"x" defaultValue:0];
    float y = [position floatValueForKey:@"y" defaultValue:0];
    self.mapView.scaleOrigin = CGPointMake(x, y);
}

- (void)setCompass:(NSDictionary *)paramsDict_ {
    BOOL show = [paramsDict_ boolValueForKey:@"show" defaultValue:NO];
    if (show) {
        self.mapView.showsCompass = YES;
    } else {
        self.mapView.showsCompass = NO;
    }
    NSDictionary *position = [paramsDict_ dictValueForKey:@"position" defaultValue:@{}];
    float x = [position floatValueForKey:@"x" defaultValue:0];
    float y = [position floatValueForKey:@"y" defaultValue:0];
    self.mapView.compassOrigin = CGPointMake(x, y);
    NSString *imgPath = [paramsDict_ stringValueForKey:@"img" defaultValue:nil];
    if (imgPath.length > 0) {
        UIImage *image = [UIImage imageWithContentsOfFile:[self getPathWithUZSchemeURL:imgPath]];
        [self.mapView setCompassImage:image];
    }
}

- (void)setLogo:(NSDictionary *)paramsDict_ {
    NSString *position = [paramsDict_ stringValueForKey:@"position" defaultValue:@"right"];
    CGSize logoSize = self.mapView.logoSize;
    if ([position isEqualToString:@"right"]) {
        CGPoint point = CGPointMake(self.mapView.bounds.size.width-logoSize.width/2.0-10, self.mapView.bounds.size.height-logoSize.height/2.0-10);
        [self.mapView setLogoCenter:point];
    } else if ([position isEqualToString:@"left"]) {
        CGPoint point = CGPointMake(logoSize.width/2.0, self.mapView.bounds.size.height-logoSize.height/2.0-10);
        [self.mapView setLogoCenter:point];
    } else {
        CGPoint point = CGPointMake(self.mapView.bounds.size.width/2.0, self.mapView.bounds.size.height-logoSize.height/2.0-10);
        [self.mapView setLogoCenter:point];
    }
}

- (void)isPolygonContainsPoint:(NSDictionary *)paramsDict_ {
    NSInteger cbcontantId = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSArray *arrSome = [paramsDict_ arrayValueForKey:@"points" defaultValue:nil];
    if (arrSome.count == 0) {
        [self sendResultEventWithCallbackId:cbcontantId dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"status"] errDict:nil doDelete:YES];
        return;
    }
    NSDictionary *targetInfo = [paramsDict_ dictValueForKey:@"point" defaultValue:@{}];
    if (!targetInfo || targetInfo.count==0) {
        [self sendResultEventWithCallbackId:cbcontantId dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"status"] errDict:nil doDelete:YES];
        return;
    }
    float targetX = [targetInfo floatValueForKey:@"lat" defaultValue:360];
    float targetY = [targetInfo floatValueForKey:@"lon" defaultValue:360];
    
    NSInteger pointCount = [arrSome count];
    CLLocationCoordinate2D allPoint[200]= {0};
    for (int i=0; i<pointCount; i++){
        NSDictionary *item = [arrSome objectAtIndex:i];
        float lon = [item floatValueForKey:@"lon" defaultValue:360];
        float lat = [item floatValueForKey:@"lat" defaultValue:360];
        if (![self isValidLon:lon lat:lat]) {
            continue;
        }
        CLLocationCoordinate2D tempPoint = CLLocationCoordinate2DMake(lat, lon);
        allPoint[i] = tempPoint;
    }
    
    CLLocationCoordinate2D targetPoint = CLLocationCoordinate2DMake(targetX, targetY);
    BOOL is = MAPolygonContainsCoordinate(targetPoint, allPoint, pointCount);
    [self sendResultEventWithCallbackId:cbcontantId dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:is] forKey:@"status"] errDict:nil doDelete:YES];
}

- (void)isCircleContainsPoint:(NSDictionary *)paramsDict_ {
    NSInteger cbcontantId = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSDictionary *circleDict = [paramsDict_ dictValueForKey:@"circle" defaultValue:nil];
    if (!circleDict) {
        [self sendResultEventWithCallbackId:cbcontantId dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"status"] errDict:nil doDelete:YES];
        return;
    }
    NSDictionary *centerDict = [circleDict dictValueForKey:@"center" defaultValue:@{}];
    float centerX = [centerDict floatValueForKey:@"lat" defaultValue:360];
    float centerY = [centerDict floatValueForKey:@"lon" defaultValue:360];
    CLLocationCoordinate2D centerPoint = CLLocationCoordinate2DMake(centerX, centerY);
    double radius = [circleDict floatValueForKey:@"radius" defaultValue:100];
    
    NSDictionary *targetInfo = [paramsDict_ dictValueForKey:@"point" defaultValue:@{}];
    if (!targetInfo || targetInfo.count==0) {
        [self sendResultEventWithCallbackId:cbcontantId dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"status"] errDict:nil doDelete:YES];
        return;
    }
    float targetX = [targetInfo floatValueForKey:@"lat" defaultValue:360];
    float targetY = [targetInfo floatValueForKey:@"lon" defaultValue:360];
    CLLocationCoordinate2D targetPoint = CLLocationCoordinate2DMake(targetX, targetY);
    
    BOOL is = MACircleContainsCoordinate(targetPoint, centerPoint, radius);
    [self sendResultEventWithCallbackId:cbcontantId dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:is] forKey:@"status"] errDict:nil doDelete:YES];
}

- (void)interconvertCoords:(NSDictionary *)paramsDict_ {
    NSInteger convertCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    float orignalLon = [paramsDict_ floatValueForKey:@"lon" defaultValue:360];
    float orignalLat = [paramsDict_ floatValueForKey:@"lat" defaultValue:360];
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    if ([self isValidLon:orignalLon lat:orignalLat]) {
        [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(orignalLat, orignalLon);
        CGPoint point = [self.mapView convertCoordinate:coord toPointToView:self.mapView];
        [sendDict setObject:[NSNumber numberWithFloat:point.x] forKey:@"x"];
        [sendDict setObject:[NSNumber numberWithFloat:point.y] forKey:@"y"];
    }
    if ([paramsDict_ objectForKey:@"x"] && [paramsDict_ objectForKey:@"y"]) {
        [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
        float orignalX = [paramsDict_ floatValueForKey:@"x" defaultValue:0];
        float orignalY = [paramsDict_ floatValueForKey:@"y" defaultValue:0];
        CGPoint oriPoint = CGPointMake(orignalX, orignalY);
        CLLocationCoordinate2D convertCoord = [self.mapView convertPoint:oriPoint toCoordinateFromView:self.mapView];
        [sendDict setObject:[NSNumber numberWithFloat:convertCoord.latitude] forKey:@"lat"];
        [sendDict setObject:[NSNumber numberWithFloat:convertCoord.longitude] forKey:@"lon"];
    }
    [self sendResultEventWithCallbackId:convertCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)addEventListener:(NSDictionary *)paramsDict_ {
    NSString *nameStr = [paramsDict_ stringValueForKey:@"name" defaultValue:nil];
    if (nameStr.length == 0) {
        return;
    }
    if ([nameStr isEqualToString:@"longPress"]) {//长按监听
        longPressCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    } else if ([nameStr isEqualToString:@"viewChange"]) {//视角改变监听
        viewChangeCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    } else if ([nameStr isEqualToString:@"click"]) {//单击监听
        singleTapCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    } else if ([nameStr isEqualToString:@"trackingMode"]) {//tackingmode监听
        trackingModeCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    } else if ([nameStr isEqualToString:@"zoom"]) {//tackingmode监听
        zoomLisCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    }
}

- (void)removeEventListener:(NSDictionary *)paramsDict_ {
    NSString *nameStr = [paramsDict_ stringValueForKey:@"name" defaultValue:nil];
    if (nameStr.length == 0) {
        return;
    }
    if ([nameStr isEqualToString:@"longPress"]) {//移除长按监听
        if (longPressCbid != -1) {
            [self deleteCallback:longPressCbid];
        }
        longPressCbid = -1;
    } else if ([nameStr isEqualToString:@"viewChange"]) {//移除视角改变监听
        if (viewChangeCbid >= 0) {
            [self deleteCallback:viewChangeCbid];
        }
        viewChangeCbid = -1;
    } else if ([nameStr isEqualToString:@"click"]) {//移除单击监听
        if (singleTapCbid != -1) {
            [self deleteCallback:singleTapCbid];
        }
        singleTapCbid = -1;
    } else if ([nameStr isEqualToString:@"dbclick"]) {//移除tackingmode监听
        if (trackingModeCbid != -1) {
            [self deleteCallback:trackingModeCbid];
        }
        trackingModeCbid = -1;
    } else if ([nameStr isEqualToString:@"zoom"]) {
        if (zoomLisCbid != -1) {
            [self deleteCallback:zoomLisCbid];
        }
        zoomLisCbid = -1;
    }
}

#pragma mark 室内地图
- (void)isShowsIndoorMap:(NSDictionary *)paramsDict_ {
    BOOL isShow = [self.mapView isShowsIndoorMap];
    NSInteger cbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    [self sendResultEventWithCallbackId:cbid dataDict:@{@"status":@(isShow)} errDict:nil doDelete:YES];
}

- (void)showsIndoorMap:(NSDictionary *)paramsDict_ {
    BOOL isShow = [paramsDict_ boolValueForKey:@"isShows" defaultValue:NO];
    self.mapView.showsIndoorMap = isShow;
}

- (void)isShowsIndoorMapControl:(NSDictionary *)paramsDict_ {
    BOOL isShow = [self.mapView isShowsIndoorMapControl];
    NSInteger cbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    [self sendResultEventWithCallbackId:cbid dataDict:@{@"status":@(isShow)} errDict:nil doDelete:YES];
}

- (void)showsIndoorMapControl:(NSDictionary *)paramsDict_ {
    BOOL isShow = [paramsDict_ boolValueForKey:@"isShows" defaultValue:NO];
    self.mapView.showsIndoorMapControl = isShow;
}

- (void)indoorMapControlSize:(NSDictionary *)paramsDict_ {
    CGSize size = [self.mapView indoorMapControlSize];
    NSInteger cbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    [self sendResultEventWithCallbackId:cbid dataDict:@{@"size":@{@"width":@(size.width),@"height":@(size.height)}} errDict:nil doDelete:YES];
}

- (void)setIndoorMapControlOrigin:(NSDictionary *)paramsDict_ {
    NSDictionary  *pointDict = [paramsDict_ dictValueForKey:@"point" defaultValue:@{}];
    float x = [pointDict floatValueForKey:@"x" defaultValue:0];
    float y = [pointDict floatValueForKey:@"y" defaultValue:0];
    CGPoint point =CGPointMake(x, y);
    [self.mapView setIndoorMapControlOrigin:point];
}

- (void)setCurrentIndoorMapFloorIndex:(NSDictionary *)paramsDict_ {
    NSInteger floorIndex = [paramsDict_ integerValueForKey:@"floorIndex" defaultValue:0];
    [self.mapView setCurrentIndoorMapFloorIndex:floorIndex];
}

- (void)clearIndoorMapCache:(NSDictionary *)paramsDict_ {
    [self.mapView clearIndoorMapCache];
}


#pragma mark 标注、气泡类

- (void)addAnnotations:(NSDictionary *)paramsDict_ {
    NSInteger addAnnCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSArray *iconPaths = [paramsDict_ arrayValueForKey:@"icons" defaultValue:nil];
    if (iconPaths.count > 0) {
        NSMutableArray *newPinIcons = [NSMutableArray arrayWithCapacity:1];
        for (NSString *iconPath in iconPaths) {
            NSString *realPath = [self getPathWithUZSchemeURL:iconPath];
            [newPinIcons addObject:realPath];
        }
        iconPaths = newPinIcons;
    }
    //选择后的
    NSArray *selIconPaths = [paramsDict_ arrayValueForKey:@"selectedIcons" defaultValue:nil];
    if (selIconPaths.count > 0) {
        NSMutableArray *newSelPinIcons = [NSMutableArray arrayWithCapacity:1];
        for (NSString *iconPath in selIconPaths) {
            NSString *realPath = [self getPathWithUZSchemeURL:iconPath];
            [newSelPinIcons addObject:realPath];
        }
        selIconPaths = newSelPinIcons;
    }
    BOOL draggable = [paramsDict_ boolValueForKey:@"draggable" defaultValue:NO];
    BOOL timeInterval = [paramsDict_ floatValueForKey:@"timeInterval" defaultValue:3.0];
    NSArray *annoAry = [paramsDict_ arrayValueForKey:@"annotations" defaultValue:nil];
    NSMutableArray *annotationsAry = [NSMutableArray arrayWithCapacity:1];
    for (NSDictionary *annoInfo in annoAry) {
        if (![annoInfo isKindOfClass:[NSDictionary class]] || annoInfo.count==0) {
            continue;
        }
        float lon = [annoInfo floatValueForKey:@"lon" defaultValue:360];
        float lat = [annoInfo floatValueForKey:@"lat" defaultValue:360];
        
        float w = [annoInfo floatValueForKey:@"w" defaultValue:-1];
        float h = [annoInfo floatValueForKey:@"h" defaultValue:-1];
        if (![self isValidLon:lon lat:lat]) {
            continue;
        }
        NSInteger annoId = [annoInfo integerValueForKey:@"id" defaultValue:-1];
        if (annoId < 0) {
            continue;
        }
        NSArray *pinIcons = [annoInfo arrayValueForKey:@"icons" defaultValue:nil];
        if (pinIcons.count > 0) {
            NSMutableArray *newPinIcons = [NSMutableArray array];
            for (NSString *iconPath in pinIcons) {
                NSString *realPath = [self getPathWithUZSchemeURL:iconPath];
                [newPinIcons addObject:realPath];
            }
            pinIcons = newPinIcons;
        }
        NSArray *selPinIcons = [annoInfo arrayValueForKey:@"selectedIcons" defaultValue:nil];
        if (selPinIcons.count > 0) {
            NSMutableArray *newSelPinIcons = [NSMutableArray array];
            for (NSString *iconPath in selPinIcons) {
                NSString *realPath = [self getPathWithUZSchemeURL:iconPath];
                [newSelPinIcons addObject:realPath];
            }
            selPinIcons = newSelPinIcons;
        }
        
        BOOL locked = [annoInfo boolValueForKey:@"locked" defaultValue:NO];
        
        ACGDAnnotaion *annotation = [[ACGDAnnotaion alloc] init];
        CLLocationCoordinate2D coor;
        coor.longitude = lon;
        coor.latitude = lat;
        annotation.coordinate = coor;
        annotation.w = w;
        annotation.h = h;
        annotation.annotId = annoId;
        annotation.clickCbId = addAnnCbid;//点击标注的回调id
        annotation.interval = timeInterval;
        if (pinIcons.count > 0) {
            annotation.pinIcons = pinIcons;
        } else {
            annotation.pinIcons = iconPaths;
        }
        if (selPinIcons.count > 0) {
            annotation.selPinIcons = selPinIcons;
        } else {
            annotation.selPinIcons = selIconPaths;
        }
        if ([annoInfo objectForKey:@"draggable"]) {
            annotation.draggable = [annoInfo boolValueForKey:@"draggable" defaultValue:NO];
        } else {
            annotation.draggable = draggable;
        }
        
        annotation.lockedToScreen = locked;
        if (locked) {
            float lockedX = [annoInfo floatValueForKey:@"lockedX" defaultValue:CGRectGetWidth(self.mapView.frame) * 0.5];
            float lockedY = [annoInfo floatValueForKey:@"lockedY" defaultValue:CGRectGetHeight(self.mapView.frame) * 0.5];
            annotation.lockedScreenPoint = CGPointMake(lockedX, lockedY);
        }
        
        [annotationsAry addObject:annotation];
    }
    if (annotationsAry.count > 0) {
        [self.mapView addAnnotations:annotationsAry];
    }
}

// 取消选中标注
- (void)cancelAnnotationSelected:(NSDictionary *)paramsDict_
{
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![setID isKindOfClass:[NSString class]] || setID.length==0) {
        return;
    }
    
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos) {
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [setID integerValue]) {

            [self.mapView deselectAnnotation:annoElem animated:NO];

            break;
        }
    }
}

- (void)getAnnotationCoords:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![setID isKindOfClass:[NSString class]] || setID.length==0) {
        return;
    }
    NSInteger getCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    if (getCbid < 0) {
        return;
    }
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos) {
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [setID integerValue]) {
            CLLocationCoordinate2D coords = annoElem.coordinate;
            NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:2];
            [sendDict setObject:[NSNumber numberWithDouble:coords.latitude] forKey:@"lat"];
            [sendDict setObject:[NSNumber numberWithDouble:coords.longitude] forKey:@"lon"];
            [self sendResultEventWithCallbackId:getCbid dataDict:sendDict errDict:nil doDelete:YES];
            break;
        }
    }
}

- (void)setAnnotationCoords:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![setID isKindOfClass:[NSString class]] || setID.length==0) {
        return;
    }
    float lat = [paramsDict_ floatValueForKey:@"lat" defaultValue:360];
    float lon = [paramsDict_ floatValueForKey:@"lon" defaultValue:360];
    if (![self isValidLon:lon lat:lat]) {
        return;
    }
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos) {
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [setID integerValue]) {
            CLLocationCoordinate2D coords = CLLocationCoordinate2DMake(lat, lon);
            [annoElem setCoordinate:coords];
            break;
        }
    }
}

- (void)annotationExist:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![setID isKindOfClass:[NSString class]] || setID.length==0) {
        return;
    }
    NSInteger cbExistID = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos) {
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [setID integerValue]) {
            [self sendResultEventWithCallbackId:cbExistID dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"status"] errDict:nil doDelete:YES];
            break;
        }
    }
    [self sendResultEventWithCallbackId:cbExistID dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"status"] errDict:nil doDelete:YES];
}


- (void)addWebBubbleListener:(NSDictionary *)paramsDict_ {
    webBubbleCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
}

- (void)removeWebBubbleListener:(NSDictionary *)paramsDict_ {
    webBubbleCbid = -1;
}


- (void)setWebBubble:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos) {
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [setID integerValue]) {
            annoElem.haveBubble = YES;
            annoElem.webBubbleDict = paramsDict_;
            [self.mapView removeAnnotation:annoElem];
            [self.mapView addAnnotation:annoElem];
            break;
        }
    }
}


- (void)setBubble:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    NSString *bgImgStr = [paramsDict_ stringValueForKey:@"bgImg" defaultValue:nil];
    NSDictionary *contentInfo = [paramsDict_ dictValueForKey:@"content" defaultValue:@{}];
    NSDictionary *styleInfo = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    if (![setID isKindOfClass:[NSString class]] || setID.length==0) {
        return;
    }
    NSInteger setBubbleCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos) {
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [setID integerValue]) {
            if (bgImgStr.length > 0) {
                annoElem.bubbleBgImg = [self getPathWithUZSchemeURL:bgImgStr];
            }
            annoElem.contentDict = contentInfo;
            annoElem.stylesDict = styleInfo;
            annoElem.haveBubble = YES;
            annoElem.bubbleClickCbid = setBubbleCbid;
            [self.mapView removeAnnotation:annoElem];
            [self.mapView addAnnotation:annoElem];
            break;
        }
    }
}

- (void)popupBubble:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![setID isKindOfClass:[NSString class]] || setID.length==0) {
        return;
    }
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos) {
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [setID intValue]) {
            [self.mapView selectAnnotation:annoElem animated:YES];
            break;
        }
    }
}

- (void)closeBubble:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![setID isKindOfClass:[NSString class]] || setID.length==0) {
        return;
    }
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos) {
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [setID intValue]) {
            [self.mapView deselectAnnotation:annoElem animated:YES];
            break;
        }
    }
}

- (void)addBillboard:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![setID isKindOfClass:[NSString class]]|| setID.length==0){
        return;
    }
    NSDictionary *coordsInfo = [paramsDict_ dictValueForKey:@"coords" defaultValue:@{}];
    double lon = [coordsInfo floatValueForKey:@"lon" defaultValue:360];
    double lat = [coordsInfo floatValueForKey:@"lat" defaultValue:360];
    if (![self isValidLon:lon lat:lat] ) {
        return;
    }
    NSString *bgImgStr = [paramsDict_ stringValueForKey:@"bgImg" defaultValue:nil];
    if (![bgImgStr isKindOfClass:[NSString class]] || bgImgStr.length==0) {
        return;
    }
    NSDictionary *selectedDict = [paramsDict_ dictValueForKey:@"selectedStyles" defaultValue:nil];
    NSDictionary *contentInfo = [paramsDict_ dictValueForKey:@"content" defaultValue:@{}];
    NSDictionary *styleInfo = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    
    NSInteger addBillboardCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    ACGDAnnotaion *annotation = [[ACGDAnnotaion alloc] init];
    CLLocationCoordinate2D coor;
    coor.longitude = lon;
    coor.latitude = lat;
    annotation.coordinate = coor;
    annotation.annotId = [setID integerValue];
    annotation.billBgImg = bgImgStr;
    annotation.selectedBillStyle = selectedDict;
    annotation.addBillboardCbid = addBillboardCbid;
    annotation.draggable = [paramsDict_ boolValueForKey:@"draggable" defaultValue:NO];
    annotation.contentDict = contentInfo;
    annotation.stylesDict = styleInfo;
    annotation.type = ANNOTATION_BILLBOARD;
    [self.mapView addAnnotation:annotation];
}

- (void)jsmethod_addWebBoard:(UZModuleMethodContext *)context {
    NSString *setID = [context.param stringValueForKey:@"id" defaultValue:nil];
    if (![setID isKindOfClass:[NSString class]]|| setID.length==0){
        return;
    }
    NSDictionary *coordsInfo = [context.param dictValueForKey:@"coords" defaultValue:@{}];
    double lon = [coordsInfo floatValueForKey:@"lon" defaultValue:360];
    double lat = [coordsInfo floatValueForKey:@"lat" defaultValue:360];
    if (![self isValidLon:lon lat:lat] ) {
        return;
    }
    NSString *bgImgStr = [context.param stringValueForKey:@"bg" defaultValue:nil];
    if (![UZAppUtils isValidColor:bgImgStr]) {
        bgImgStr = [self getPathWithUZSchemeURL:bgImgStr];
    }
    NSString *urlStr = [context.param stringValueForKey:@"url" defaultValue:nil];
    NSString *dataStr = [context.param stringValueForKey:@"data" defaultValue:nil];
    NSDictionary *sizeInfo = [context.param dictValueForKey:@"size" defaultValue:@{}];
    ACGDAnnotaion *annotation = [[ACGDAnnotaion alloc] init];
    CLLocationCoordinate2D coor;
    coor.longitude = lon;
    coor.latitude = lat;
    annotation.draggable = [context.param boolValueForKey:@"draggable" defaultValue:NO];
    annotation.bgStr = bgImgStr;
    annotation.dataStr = dataStr;
    annotation.urlStr = urlStr;
    annotation.sizeDict = sizeInfo;
    annotation.coordinate = coor;
    annotation.annotId = [setID integerValue];
    annotation.billBgImg = bgImgStr;
    annotation.type = ANNOTATION_WEBBOARD;
    [self.mapView addAnnotation:annotation];
}
- (void)jsmethod_addWebBoardListener:(UZModuleMethodContext *)context {
    self.webBoardListener = context;
}

- (void)jsmethod_removeWebBoardListener:(NSDictionary *)paramsDict_ {
    self.webBoardListener = nil;
}

- (void)addMobileAnnotations:(NSDictionary *)paramsDict_ {
    NSInteger addMobileAnnoCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSArray *annoAry = [paramsDict_ arrayValueForKey:@"annotations" defaultValue:nil];
    NSMutableArray *annotationsAry = [NSMutableArray arrayWithCapacity:1];
    for (NSDictionary *annoInfo in annoAry) {
        if (![annoInfo isKindOfClass:[NSDictionary class]] || annoInfo.count==0) {
            continue;
        }
        float lon = [annoInfo floatValueForKey:@"lon" defaultValue:360];
        float lat = [annoInfo floatValueForKey:@"lat" defaultValue:360];
        if (![self isValidLon:lon lat:lat]) {
            continue;
        }
        NSInteger annoId = [annoInfo integerValueForKey:@"id" defaultValue:-1];
        if (annoId < 0) {
            continue;
        }
        NSString *pinIcon = [annoInfo stringValueForKey:@"icon" defaultValue:nil];
        ACGDAnnotaion *annotation = [[ACGDAnnotaion alloc] init];
        CLLocationCoordinate2D coor;
        coor.longitude = lon;
        coor.latitude = lat;
        annotation.coordinate = coor;
        annotation.annotId = annoId;
        annotation.moveAnnoCbid = addMobileAnnoCbid;
        annotation.mobileBgImg = pinIcon;
        annotation.draggable = [annoInfo boolValueForKey:@"draggable" defaultValue:NO];
        annotation.type = ANNOTATION_MOBILEGD;
        annotation.currentAngle = M_PI/2.0;
        [annotationsAry addObject:annotation];
    }
    if (annotationsAry.count > 0) {
        [self.mapView addAnnotations:annotationsAry];
    }
}

- (void)moveAnnotation:(NSDictionary *)paramsDict_ {
    if (!_allMovingAnno) {
        _allMovingAnno = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    NSDictionary *endInfo = [paramsDict_ dictValueForKey:@"end" defaultValue:@{}];
    if (endInfo.count == 0) {
        return;
    }
    float endlon = [endInfo floatValueForKey:@"lon" defaultValue:360];
    float endlat = [endInfo floatValueForKey:@"lat" defaultValue:360];
    if (![self isValidLon:endlon lat:endlat]) {
        return;
    }
    CLLocationCoordinate2D toCoords = CLLocationCoordinate2DMake(endlat, endlon);
    NSString *moveId = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![moveId isKindOfClass:[NSString class]] || moveId.length==0) {
        return;
    }
    
    NSInteger moveAnnoEndCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    float moveDuration = [paramsDict_ floatValueForKey:@"duration" defaultValue:1];
    CFTimeInterval thisStep = CACurrentMediaTime();
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos){
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [moveId intValue]) {
            //获取当前坐标
            float startlon = annoElem.coordinate.longitude;
            float startlat = annoElem.coordinate.latitude;
            CLLocationCoordinate2D fromCoords = CLLocationCoordinate2DMake(startlat, startlon);
            annoElem.fromCoords = fromCoords;
            annoElem.toCoords = toCoords;
            //计算旋转方向
            float angle = -atan2(endlat - startlat, endlon - startlon);
            float currentAngle = annoElem.currentAngle;
            float rotateAngle;
            if (currentAngle > angle) {
                rotateAngle = M_PI - currentAngle + angle;
            } else {
                rotateAngle = -(M_PI + currentAngle - angle);
            }
            annoElem.currentAngle += rotateAngle;
            annoElem.moveDuration = moveDuration;
            annoElem.lastStep = thisStep;
            annoElem.timeOffset = 0;
            annoElem.delegate = self;
            annoElem.moveAnnoEndCbid = moveAnnoEndCbid;
            //添加到移动队列
            [self.allMovingAnno setObject:annoElem forKey:moveId];
            //先做旋转动画
            MAAnnotationView *pinAnnotationView = [_mapView viewForAnnotation:annoElem];
            UIImageView *roteImg = (UIImageView *)[pinAnnotationView viewWithTag:ANNOTATION_MOBILETAG];
            void(^animationManager)(void) = ^(void) {
                CGAffineTransform transform = roteImg.transform;
                transform = CGAffineTransformRotate(transform, rotateAngle);
                roteImg.transform = transform;
            };
            //再做移动动画
            __weak GDMap *OBJMap = self;
            void(^completion)(BOOL finished) = ^(BOOL finished) {
                if (OBJMap.timerAnnoMove == nil) {//若已经存在计时器则不创建
                    [OBJMap.timerAnnoMove invalidate];
                    OBJMap.timerAnnoMove = [CADisplayLink displayLinkWithTarget:OBJMap selector:@selector(doStep)];//更屏幕刷新频率同步的计时器
                    OBJMap.timerAnnoMove.frameInterval = 2;//比屏幕刷新频率低一半
                    NSRunLoop *mainRunLoop = [NSRunLoop currentRunLoop];
                    [OBJMap.timerAnnoMove addToRunLoop:mainRunLoop forMode:NSDefaultRunLoopMode];
                    [OBJMap.timerAnnoMove addToRunLoop:mainRunLoop forMode:UITrackingRunLoopMode];
                }
            };
            //0.3秒旋转后开始移动
            [UIView animateWithDuration:0.3 animations:animationManager completion:completion];
            break;
        }
    }
}

- (void)removeAnnotations:(NSDictionary *)paramsDict_ {
    NSArray *idAry = [paramsDict_ arrayValueForKey:@"ids" defaultValue:nil];
    if (idAry.count > 0) {
        NSMutableArray *removeIdAry = [NSMutableArray arrayWithCapacity:1];
        for (int i=0; i<idAry.count; i++) {
            NSString *idStr = [NSString stringWithFormat:@"%@",[idAry objectAtIndex:i]];
            [removeIdAry addObject:idStr];
        }
        NSArray *annos = [self.mapView annotations];
        NSMutableArray *willRemoveAnnos = [NSMutableArray arrayWithCapacity:1];
        for (ACGDAnnotaion *annoAry in annos) {
            if (![annoAry isKindOfClass:[ACGDAnnotaion class]]) {
                continue;
            }
            NSString *annID = [NSString stringWithFormat:@"%ld",(long)annoAry.annotId];
            if ([removeIdAry containsObject:annID]) {
                [willRemoveAnnos addObject:annoAry];
            }
        }
        for (ACGDAnnotaion *annoAry in willRemoveAnnos) {
            if (annoAry.delegate) {
                annoAry.delegate = nil;
            }
        }
        [self.mapView removeAnnotations:willRemoveAnnos];
    } else {//若为空数组则移除全部
        NSArray *annos = [self.mapView annotations];
        NSMutableArray *willRemoveAnnos = [NSMutableArray arrayWithCapacity:1];
        for (ACGDAnnotaion *annoAry in annos) {
            if (![annoAry isKindOfClass:[ACGDAnnotaion class]]) {
                continue;
            }
            [willRemoveAnnos addObject:annoAry];
        }
        for (ACGDAnnotaion *annoAry in willRemoveAnnos) {
            if (annoAry.delegate) {
                annoAry.delegate = nil;
            }
        }
        [self.mapView removeAnnotations:willRemoveAnnos];
    }
}

- (void)addMoveAnimation:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![setID isKindOfClass:[NSString class]] || setID.length==0) {
        return;
    }
    ACGDAnnotaion *targetAnno = nil;
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos) {
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [setID integerValue]) {
            targetAnno = annoElem;
            break;
        }
    }
    if (!targetAnno) {
        return;
    }
    NSInteger addMoveAnimCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    float duration = [paramsDict_ floatValueForKey:@"duration" defaultValue:3.0];
    NSArray *coordinates = [paramsDict_ arrayValueForKey:@"coordinates" defaultValue:@[]];
    if (coordinates.count == 0) {
        return;
    }
    NSInteger arrCount = coordinates.count;
    CLLocationCoordinate2D *coordinateArr = (CLLocationCoordinate2D*)malloc(arrCount * sizeof(CLLocationCoordinate2D));
    for (int i = 0; i < arrCount; i++) {
        NSDictionary *data = coordinates[i];
        coordinateArr[i].longitude = [data[@"lon"] doubleValue];
        coordinateArr[i].latitude  = [data[@"lat"] doubleValue];
    }
    __weak typeof(self) weakSelf = self;
    [targetAnno addMoveAnimationWithKeyCoordinates:coordinateArr count:arrCount withDuration:duration withName:nil completeCallback:^(BOOL isFinished) {
        free(coordinateArr);
        [weakSelf sendResultEventWithCallbackId:addMoveAnimCbid dataDict:@{@"isFinished":@(isFinished)} errDict:nil doDelete:NO];
    }];
}


- (void)cancelMoveAnimation:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![setID isKindOfClass:[NSString class]] || setID.length==0) {
        return;
    }
    ACGDAnnotaion *targetAnno = nil;
    NSArray *annos = [self.mapView annotations];
    for (ACGDAnnotaion *annoElem in annos) {
        if (![annoElem isKindOfClass:[ACGDAnnotaion class]]) {
            continue;
        }
        if (annoElem.annotId == [setID integerValue]) {
            targetAnno = annoElem;
            break;
        }
    }
    if (!targetAnno) {
        return;
    }
    NSArray *allMoveAnno = [targetAnno allMoveAnimations];
    for(MAAnnotationMoveAnimation *animation in allMoveAnno) {
        [animation cancel];
    }
}

- (void)jsmethod_showAnnotations:(UZModuleMethodContext *)context {
    NSMutableArray *willShowAnnos = [NSMutableArray array];
    NSArray *idAry = [context.param arrayValueForKey:@"ids" defaultValue:nil];
    if (idAry.count > 0) {
        NSMutableArray *removeIdAry = [NSMutableArray array];
        for (int i=0; i<idAry.count; i++) {
            NSString *idStr = [NSString stringWithFormat:@"%@",[idAry objectAtIndex:i]];
            [removeIdAry addObject:idStr];
        }
        NSArray *annos = [self.mapView annotations];
        for (ACGDAnnotaion *annoAry in annos) {
            if (![annoAry isKindOfClass:[ACGDAnnotaion class]]) {
                continue;
            }
            NSString *annID = [NSString stringWithFormat:@"%ld",(long)annoAry.annotId];
            if ([removeIdAry containsObject:annID]) {
                [willShowAnnos addObject:annoAry];
            }
        }
    } else {//若为空数组则移除全部
        NSArray *annos = [self.mapView annotations];
        for (ACGDAnnotaion *annoAry in annos) {
            if (![annoAry isKindOfClass:[ACGDAnnotaion class]]) {
                continue;
            }
            [willShowAnnos addObject:annoAry];
        }
    }
    NSDictionary *insetsDict = [context.param dictValueForKey:@"insets" defaultValue:@{}];
    float top = [insetsDict floatValueForKey:@"top" defaultValue:50];
    float left = [insetsDict floatValueForKey:@"left" defaultValue:20];
    float bottom = [insetsDict floatValueForKey:@"bottom" defaultValue:50];
    float right = [insetsDict floatValueForKey:@"right" defaultValue:20];
    UIEdgeInsets insets = UIEdgeInsetsMake(top, left, bottom, right);
    BOOL animation = [context.param boolValueForKey:@"animation" defaultValue:YES];
    [self.mapView showAnnotations:willShowAnnos edgePadding:insets animated:animation];
}
#pragma mark 覆盖物类接口

- (void)addHeatMap:(NSDictionary *)paramsDict_ {
    NSString *overlayIdStr = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![overlayIdStr isKindOfClass:[NSString class]] || overlayIdStr.length==0) {
        return;
    }
    if (!self.allOverlays) {
        self.allOverlays = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    id target = [self.allOverlays objectForKey:overlayIdStr];
    if (target) {
        [self.mapView removeOverlay:target];
    }
    id dataSource = [paramsDict_ objectForKey:@"data"];
    NSArray *locInfoArr = nil;
    if ([dataSource isKindOfClass:[NSString class]]) {
        NSString *file = [paramsDict_ stringValueForKey:@"data" defaultValue:@""];
        if (file.length > 0) {
            file = [self getPathWithUZSchemeURL:file];
        } else {
            return;
        }
        //NSString *locationString = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
        //NSData *data = [NSData dataWithContentsOfFile:locationString];
        NSData *data = [NSData dataWithContentsOfFile:file];
        NSError *err = nil;
        locInfoArr = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
        if(!locInfoArr) {
            NSLog(@"[Turbo_AMap] Read trace data error: %@", err);
            return;
        }
    } else {
        locInfoArr = [paramsDict_ arrayValueForKey:@"data" defaultValue:nil];
    }
    if(locInfoArr.count <= 0) {
        NSLog(@"[Turbo_AMap] Read trace data error");
        return;
    }
    NSMutableArray *items = [NSMutableArray array];
    for (int i = 0; i < locInfoArr.count; ++i) {
        @autoreleasepool {
            MAHeatMapNode *item = [[MAHeatMapNode alloc] init];
            NSDictionary *pointDict = locInfoArr[i];
            item.coordinate =  CLLocationCoordinate2DMake([[pointDict objectForKey:@"latitude"] doubleValue], [[pointDict objectForKey:@"longitude"] doubleValue]);
            item.intensity = [pointDict floatValueForKey:@"intensity" defaultValue:1];
            [items addObject:item];
        }
    }
    MAHeatMapTileOverlay *heatMapTileOverlay = [[MAHeatMapTileOverlay alloc] init];
    heatMapTileOverlay.data = items;
    //热力点图层样式配置
    NSDictionary *heatMapStyles = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    NSInteger radius = [heatMapStyles integerValueForKey:@"radius" defaultValue:12];
    [heatMapTileOverlay setRadius:radius];
    float opacity = [heatMapStyles floatValueForKey:@"opacity" defaultValue:0.6];
    [heatMapTileOverlay setOpacity: opacity];
    BOOL allowRetinaAdapting = [heatMapStyles boolValueForKey:@"allowRetinaAdapting" defaultValue:NO];
    [target setAllowRetinaAdapting:allowRetinaAdapting];
    NSDictionary *gradient = [heatMapStyles dictValueForKey:@"gradient" defaultValue:@{}];
    NSArray *colors = [gradient arrayValueForKey:@"colors" defaultValue:@[]];
    NSMutableArray *allColors = [NSMutableArray array];
    for (NSString *color in colors) {
        [allColors addObject:[UZAppUtils colorFromNSString:color]];
    }
    if (allColors.count == 0) {
        allColors = [NSMutableArray arrayWithObjects:[UIColor redColor], [UIColor blueColor],[UIColor greenColor], nil];
    }
    NSArray *points = [heatMapStyles arrayValueForKey:@"points" defaultValue:@[]];
    if (points.count == 0) {
        points = @[@(0.3),@(0.6),@(0.9)];
    }
    [heatMapTileOverlay setGradient:[[MAHeatMapGradient alloc] initWithColor:allColors andWithStartPoints:points]];
    
    [self.mapView addOverlay:heatMapTileOverlay];
    [self.allOverlays setObject:heatMapTileOverlay forKey:overlayIdStr];
}

- (void)refreshHeatMap:(NSDictionary *)paramsDict_ {
    NSString *overlayIdStr = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![overlayIdStr isKindOfClass:[NSString class]] || overlayIdStr.length==0) {
        return;
    }
    MAHeatMapTileOverlay *target = [self.allOverlays objectForKey:overlayIdStr];
    if (![target isKindOfClass:[MAHeatMapTileOverlay class]]) {
        return;
    }
    NSDictionary *heatMapStyles = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    NSInteger radius = [heatMapStyles integerValueForKey:@"radius" defaultValue:12];
    [target setRadius:radius];
    float opacity = [heatMapStyles floatValueForKey:@"opacity" defaultValue:0.6];
    [target setOpacity: opacity];
    BOOL allowRetinaAdapting = [heatMapStyles boolValueForKey:@"allowRetinaAdapting" defaultValue:NO];
    [target setAllowRetinaAdapting:allowRetinaAdapting];
    NSDictionary *gradient = [heatMapStyles dictValueForKey:@"gradient" defaultValue:@{}];
    NSArray *colors = [gradient arrayValueForKey:@"colors" defaultValue:@[]];
    NSMutableArray *allColors = [NSMutableArray array];
    for (NSString *color in colors) {
        [allColors addObject:[UZAppUtils colorFromNSString:color]];
    }
    if (allColors.count == 0) {
        allColors = [NSMutableArray arrayWithObjects:[UIColor redColor], [UIColor blueColor],[UIColor greenColor], nil];
    }
    NSArray *points = [heatMapStyles arrayValueForKey:@"points" defaultValue:@[]];
    if (points.count == 0) {
        points = @[@(0.3),@(0.6),@(0.9)];
    }
    [target setGradient:[[MAHeatMapGradient alloc] initWithColor:allColors andWithStartPoints:points]];
    MATileOverlayRenderer *render = (MATileOverlayRenderer *)[self.mapView rendererForOverlay:target];
    [render reloadData];
}

- (void)addMultiPoint:(NSDictionary *)paramsDict_ {
    NSString *overlayIdStr = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![overlayIdStr isKindOfClass:[NSString class]] || overlayIdStr.length==0) {
        return;
    }
    if (!self.allOverlays) {
        self.allOverlays = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    id target = [self.allOverlays objectForKey:overlayIdStr];
    if (target) {
        [self.mapView removeOverlay:target];
    }
    
    NSString *file = [paramsDict_ stringValueForKey:@"path" defaultValue:@""];
    if (file.length > 0) {
        file = [self getPathWithUZSchemeURL:file];
    } else {
        return;
    }
    NSString *locationString = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    NSData *data =  [NSData dataWithContentsOfFile:file];//[NSData dataWithContentsOfFile:locationString];
    NSError *err = nil;
    NSArray *locInfoArr = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if(!locInfoArr) {
        NSLog(@"[Turbo_AMap] Read trace data error: %@", err);
        return;
    }
    NSMutableArray *items = [NSMutableArray array];
    for (int i = 0; i < locInfoArr.count; ++i) {
        @autoreleasepool {
            MAMultiPointItem *item = [[MAMultiPointItem alloc] init];
            NSDictionary *pointDict = locInfoArr[i];
            if ([pointDict objectForKey:@"latitude"]) {
                item.coordinate =  CLLocationCoordinate2DMake([[pointDict objectForKey:@"latitude"] doubleValue], [[pointDict objectForKey:@"longitude"] doubleValue]);
            } else {
                item.coordinate =  CLLocationCoordinate2DMake([[pointDict objectForKey:@"lat"] doubleValue], [[pointDict objectForKey:@"lon"] doubleValue]);
            }
            item.title = [pointDict stringValueForKey:@"title" defaultValue:@""];
            item.subtitle = [pointDict stringValueForKey:@"subtitle" defaultValue:@""];
            item.customID = [pointDict stringValueForKey:@"customID" defaultValue:@""];
            [items addObject:item];
        }
    }
    //点聚合图层样式配置
    multiPointStyles = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    multiPointCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    MAMultiPointOverlay *_overlay = [[MAMultiPointOverlay alloc] initWithMultiPointItems:items];
    [self.mapView addOverlay:_overlay];
    [self.mapView setVisibleMapRect:_overlay.boundingMapRect];
    [self.allOverlays setObject:_overlay forKey:overlayIdStr];
}

- (void)addLine:(NSDictionary *)paramsDict_ {
    
    NSArray *pointAry = [paramsDict_ arrayValueForKey:@"points" defaultValue:nil];
    if (pointAry.count == 0) {
        return;
    }
    NSString *overlayIdStr = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![overlayIdStr isKindOfClass:[NSString class]] || overlayIdStr.length==0) {
        return;
    }
    if (!self.allOverlays) {
        self.allOverlays = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    id target = [self.allOverlays objectForKey:overlayIdStr];
    if (target) {
        [self.mapView removeOverlay:target];
    }
    overlayStyles = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    int pointCount = (int)[pointAry count];
    
    CLLocationCoordinate2D *coorAry = (CLLocationCoordinate2D*)malloc(pointCount*sizeof(CLLocationCoordinate2D));
    
    //CLLocationCoordinate2D coorAry[] = {0};
    for (int i=0; i<pointCount; i++){
        NSDictionary *item = [pointAry objectAtIndex:i];
        if ([item isKindOfClass:[NSDictionary class]]) {
            float lon = [item floatValueForKey:@"lon" defaultValue:360];
            float lat = [item floatValueForKey:@"lat" defaultValue:360];
            if (![self isValidLon:lon lat:lat]) {
                continue;
            }
            coorAry[i].longitude = lon;
            coorAry[i].latitude = lat;
        }
    }
    MAPolyline *commonPolyline = [MAPolyline polylineWithCoordinates:coorAry count:pointCount];
    [self.mapView addOverlay:commonPolyline];
    [self.allOverlays setObject:commonPolyline forKey:overlayIdStr];
}

- (void)addCircle:(NSDictionary *)paramsDict_ {
    NSDictionary *centerInfo = [paramsDict_ dictValueForKey:@"center" defaultValue:@{}];
    float lon = [centerInfo floatValueForKey:@"lon" defaultValue:360];
    float lat = [centerInfo floatValueForKey:@"lat" defaultValue:360];
    if (![self isValidLon:lon lat:lat]) {
        return;
    }
    float radius = [paramsDict_ floatValueForKey:@"radius" defaultValue:0];
    if (radius < 0) {
        return;
    }
    NSString *overlayIdStr = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![overlayIdStr isKindOfClass:[NSString class]] || overlayIdStr.length==0) {
        return;
    }
    if (!self.allOverlays) {
        self.allOverlays = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    id target = [self.allOverlays objectForKey:overlayIdStr];
    if (target) {
        [self.mapView removeOverlay:target];
    }
    overlayStyles = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    CLLocationCoordinate2D coor;
    coor.longitude = lon;
    coor.latitude = lat;
    MACircle *circle = [MACircle circleWithCenterCoordinate:coor radius:radius];
    [self.mapView addOverlay:circle];
    [self.allOverlays setObject:circle forKey:overlayIdStr];
}

- (void)addArc:(NSDictionary *)paramsDict_ {
    NSArray *pointAry = [paramsDict_ arrayValueForKey:@"points" defaultValue:nil];
    if (pointAry.count == 0) {
        return;
    }
    NSString *overlayIdStr = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![overlayIdStr isKindOfClass:[NSString class]] || overlayIdStr.length==0) {
        return;
    }
    if (!self.allOverlays) {
        self.allOverlays = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    id target = [self.allOverlays objectForKey:overlayIdStr];
    if (target) {
        [self.mapView removeOverlay:target];
    }
    overlayStyles = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    NSInteger pointCount = [pointAry count];
    CLLocationCoordinate2D coorAry[2] = {0};
    for (int i=0; i<pointCount; i++){
        NSDictionary *item = [pointAry objectAtIndex:i];
        if ([item isKindOfClass:[NSDictionary class]]) {
            float lon = [item floatValueForKey:@"lon" defaultValue:360];
            float lat = [item floatValueForKey:@"lat" defaultValue:360];
            if (![self isValidLon:lon lat:lat]) {
                continue;
            }
            coorAry[i].longitude = lon;
            coorAry[i].latitude = lat;
        }
    }
    MAGeodesicPolyline *geodesicPolyline = [MAGeodesicPolyline polylineWithCoordinates:coorAry
                                          count:2];
    [self.mapView addOverlay:geodesicPolyline];
    [self.allOverlays setObject:geodesicPolyline forKey:overlayIdStr];
}

- (void)addGeoLine:(NSDictionary *)paramsDict_ {
    NSArray *pointAry = [paramsDict_ arrayValueForKey:@"points" defaultValue:nil];
    if (pointAry.count == 0) {
        return;
    }
    NSString *overlayIdStr = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![overlayIdStr isKindOfClass:[NSString class]] || overlayIdStr.length==0) {
        return;
    }
    if (!self.allOverlays) {
        self.allOverlays = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    id target = [self.allOverlays objectForKey:overlayIdStr];
    if (target) {
        [self.mapView removeOverlay:target];
    }
    overlayStyles = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    NSInteger pointCount = [pointAry count];
    CLLocationCoordinate2D coorAry[2] = {0};
    for (int i=0; i<pointCount; i++){
        NSDictionary *item = [pointAry objectAtIndex:i];
        if ([item isKindOfClass:[NSDictionary class]]) {
            float lon = [item floatValueForKey:@"lon" defaultValue:360];
            float lat = [item floatValueForKey:@"lat" defaultValue:360];
            if (![self isValidLon:lon lat:lat]) {
                continue;
            }
            coorAry[i].longitude = lon;
            coorAry[i].latitude = lat;
        }
    }
    MAGeodesicPolyline *geodesicPolyline = [MAGeodesicPolyline polylineWithCoordinates:coorAry
                                                                                 count:2];
    [self.mapView addOverlay:geodesicPolyline];
    [self.allOverlays setObject:geodesicPolyline forKey:overlayIdStr];
}

- (void)addPolygon:(NSDictionary *)paramsDict_ {
    NSArray *pointAry = [paramsDict_ arrayValueForKey:@"points" defaultValue:nil];
    if (pointAry.count == 0) {
        return;
    }
    NSString *overlayIdStr = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![overlayIdStr isKindOfClass:[NSString class]] || overlayIdStr.length==0) {
        return;
    }
    if (!self.allOverlays) {
        self.allOverlays = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    id target = [self.allOverlays objectForKey:overlayIdStr];
    if (target) {
        [self.mapView removeOverlay:target];
    }
    overlayStyles = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    NSInteger pointCount = [pointAry count];
    CLLocationCoordinate2D coorAry[200] = {0};
    for (int i=0; i<pointCount; i++){
        NSDictionary *item = [pointAry objectAtIndex:i];
        if ([item isKindOfClass:[NSDictionary class]]) {
            float lon = [item floatValueForKey:@"lon" defaultValue:360];
            float lat = [item floatValueForKey:@"lat" defaultValue:360];
            if (![self isValidLon:lon lat:lat]) {
                continue;
            }
            coorAry[i].longitude = lon;
            coorAry[i].latitude = lat;
        }
    }
    MAPolygon *polygon = [MAPolygon polygonWithCoordinates:coorAry count:pointCount];
    [self.mapView addOverlay:polygon];
    [self.allOverlays setObject:polygon forKey:overlayIdStr];
}

- (void)addImg:(NSDictionary *)paramsDict_ {
    NSString *overlayIdStr = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![overlayIdStr isKindOfClass:[NSString class]] || overlayIdStr.length==0) {
        return;
    }
    if (!self.allOverlays) {
        self.allOverlays = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    id target = [self.allOverlays objectForKey:overlayIdStr];
    if (target) {
        [self.mapView removeOverlay:target];
    }
    float lbLon = [paramsDict_ floatValueForKey:@"lbLon" defaultValue:360];
    float lbLat = [paramsDict_ floatValueForKey:@"lbLat" defaultValue:360];
    float rtLon = [paramsDict_ floatValueForKey:@"rtLon" defaultValue:360];
    float rtLat = [paramsDict_ floatValueForKey:@"rtLat" defaultValue:360];
    if (![self isValidLon:lbLon lat:lbLat]) {
        return;
    }
    if (![self isValidLon:rtLon lat:rtLat]) {
        return;
    }
    NSString *imgPath = [paramsDict_ stringValueForKey:@"imgPath" defaultValue:nil];
    if (![imgPath isKindOfClass:[NSString class]] || imgPath.length==0) {
        return;
    }
    float alpha = [paramsDict_ floatValueForKey:@"opacity" defaultValue:1];
    CLLocationCoordinate2D coords[2] = {0};
    coords[0].latitude = lbLat;
    coords[0].longitude = lbLon;
    coords[1].latitude = rtLat;
    coords[1].longitude = rtLon;
    MACoordinateBounds bound;
    bound.southWest = coords[0];
    bound.northEast = coords[1];
    NSString *realPath = [self getPathWithUZSchemeURL:imgPath];
    UIImage *image = [UIImage imageWithContentsOfFile:realPath];
    MAGroundOverlay *ground = [MAGroundOverlay groundOverlayWithBounds:bound icon:image];
    ground.alpha = alpha;
    [self.mapView addOverlay:ground];
    [self.allOverlays setObject:ground forKey:overlayIdStr];
}


- (void)addLocus:(NSDictionary *)paramsDict_ {
    NSString *overlayIdStr = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (![overlayIdStr isKindOfClass:[NSString class]] || overlayIdStr.length==0) {
        return;
    }
    if (!self.allOverlays) {
        self.allOverlays = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    id target = [self.allOverlays objectForKey:overlayIdStr];
    if (target) {
        [self.mapView removeOverlay:target];
    }
    float locusWidth = [paramsDict_ floatValueForKey:@"borderWidth" defaultValue:5];
    NSString *locusDataPath = [paramsDict_ stringValueForKey:@"locusData" defaultValue:nil];
    if (![locusDataPath isKindOfClass:[NSString class]] || locusDataPath.length==0) {
        return;
    }
    NSString *realPath = [self getPathWithUZSchemeURL:locusDataPath];
    NSData *jsdata = [NSData dataWithContentsOfFile:realPath];
    if (!jsdata) {
        return;
    }
    
    NSInteger _count;
    CLLocationCoordinate2D * _runningCoords;
    NSMutableArray *indexes = [NSMutableArray array];
    
    NSArray *dataArray = [NSJSONSerialization JSONObjectWithData:jsdata options:NSJSONReadingAllowFragments error:nil];
    _count = dataArray.count;
    _runningCoords = (CLLocationCoordinate2D *)malloc(_count * sizeof(CLLocationCoordinate2D));
    NSMutableArray *_speedColors = [NSMutableArray array];
    for (int i = 0; i < _count; i++) {
        @autoreleasepool {
            NSDictionary *data = dataArray[i];
            _runningCoords[i].latitude = [data[@"latitude"] doubleValue];
            if ([data objectForKey:@"longitude"]) {
                _runningCoords[i].longitude = [data[@"longitude"] doubleValue];
            } else {
                _runningCoords[i].longitude = [data[@"longtitude"] doubleValue];
            }
            UIColor *speedColor = [UZAppUtils colorFromNSString:data[@"rgba"]];
            [_speedColors addObject:speedColor];
            [indexes addObject:@(i)];
        }
    }
    
    UZMultiPolyline *_polyline = [UZMultiPolyline polylineWithCoordinates:_runningCoords count:_count drawStyleIndexes:indexes];
    _polyline.locusWidth = locusWidth;
    _polyline.colorsAry = _speedColors;
    [self.mapView addOverlay:_polyline];
    [self.allOverlays setObject:_polyline forKey:overlayIdStr];
    
    BOOL isShow = [paramsDict_ boolValueForKey:@"autoresizing" defaultValue:YES];
    if (isShow) {
        const CGFloat screenEdgeInset = 20;
        UIEdgeInsets inset = UIEdgeInsetsMake(screenEdgeInset, screenEdgeInset, screenEdgeInset, screenEdgeInset);
        [self.mapView setVisibleMapRect:_polyline.boundingMapRect edgePadding:inset animated:YES];
    }
}

- (void)removeOverlay:(NSDictionary *)paramsDict_ {
    NSArray *idAry = [paramsDict_ arrayValueForKey:@"ids" defaultValue:nil];
    if (idAry.count == 0) {
        return;
    }
    for (id idstr in idAry) {
        NSString *idString = [NSString stringWithFormat:@"%@",idstr];
        id target = [self.allOverlays objectForKey:idString];
        if (target) {
            [self.mapView removeOverlay:target];
            [self.allOverlays removeObjectForKey:idString];
        }
    }
}

#pragma mark  搜索类接口

- (void)searchRoute:(NSDictionary *)paramsDict_ {
    //起点
    NSDictionary *startNode = [paramsDict_ dictValueForKey:@"start" defaultValue:@{}];
    float startLon = [startNode floatValueForKey:@"lon" defaultValue:360];
    float startLat = [startNode floatValueForKey:@"lat" defaultValue:360];
    AMapGeoPoint *start;
    if ([self isValidLon:startLon lat:startLat]) {
        start = [AMapGeoPoint locationWithLatitude:startLat longitude:startLon];
    } else {
        return;
    }
    //途经点
    NSArray *waypoints = [paramsDict_ arrayValueForKey:@"waypoints" defaultValue:@[]];
    NSMutableArray *waypointsAry;
    if (waypoints.count > 0) {
        waypointsAry = [NSMutableArray arrayWithCapacity:1];
    }
    for (NSDictionary *pointInfo in waypoints) {
        float pointLon = [pointInfo floatValueForKey:@"lon" defaultValue:360];
        float pointLat = [pointInfo floatValueForKey:@"lat" defaultValue:360];
        if ([self isValidLon:pointLon lat:pointLat]) {
            AMapGeoPoint *waypointEle = [AMapGeoPoint locationWithLatitude:pointLat longitude:pointLon];
            [waypointsAry addObject:waypointEle];
        }
    }
    //终点
    NSDictionary *endNode = [paramsDict_ dictValueForKey:@"end" defaultValue:@{}];
    float endLon = [endNode floatValueForKey:@"lon" defaultValue:360];
    float endLat = [endNode floatValueForKey:@"lat" defaultValue:360];
    AMapGeoPoint *end;
    if ([self isValidLon:endLon lat:endLat]) {
        end = [AMapGeoPoint locationWithLatitude:endLat longitude:endLon];
    } else {
        return;
    }
    //回调id
    searcRouteCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    //搜索实例对象
    if (![self initSearchClass]) {
        return;
    }
    //规划路线类型
    NSString *routeType = [paramsDict_ stringValueForKey:@"type" defaultValue:@"transit"];
    if ([routeType isEqualToString:@"transit"]){
        self.routePlanningType = AMapRoutePlanningTypeBus;//公交
    } else if ([routeType isEqualToString:@"walk"]){
        self.routePlanningType = AMapRoutePlanningTypeWalk;//步行
    } else if ([routeType isEqualToString:@"drive"]){
        self.routePlanningType = AMapRoutePlanningTypeDrive;//驾车
    } else {
        self.routePlanningType = AMapRoutePlanningTypeRide;//骑行
    }
    //路线策略
    AMapDrivingStrategy drivePolicy = AMapDrivingStrategyFastest;
    AMapTransitStrategy transitPolicy = AMapTransitStrategyFastest;
    NSString *policy = nil;
    if (self.routePlanningType == AMapRoutePlanningTypeDrive) {//开车
        policy = [paramsDict_ stringValueForKey:@"strategy" defaultValue:@"drive_time_first"];
        if ([policy isEqualToString:@"drive_time_first"]) {//速度最快
            drivePolicy = AMapDrivingStrategyFastest;
        } else if ([policy isEqualToString:@"drive_fee_first"]){//避免收费
            drivePolicy = AMapDrivingStrategyMinFare;
        } else if ([policy isEqualToString:@"drive_dis_first"]){//距离最短
            drivePolicy = AMapDrivingStrategyShortest;
        } else if ([policy isEqualToString:@"drive_highway_no"]){//不走高速
            drivePolicy = AMapDrivingStrategyNoHighways;
        } else if ([policy isEqualToString:@"drive_jam_no"]){//躲避拥堵
            drivePolicy = AMapDrivingStrategyAvoidCongestion;
        } else if ([policy isEqualToString:@"drive_highway_fee_no"]){//不走高速且避免收费
            drivePolicy = AMapDrivingStrategyAvoidHighwaysAndFare;
        } else if ([policy isEqualToString:@"drive_highway_jam_no"]){//不走高速且躲避拥堵
            drivePolicy = AMapDrivingStrategyAvoidHighwaysAndCongestion;
        } else if ([policy isEqualToString:@"drive_fee_jam_no"]){//躲避收费和拥堵
            drivePolicy = AMapDrivingStrategyAvoidFareAndCongestion;
        } else if ([policy isEqualToString:@"drive_highway_fee_jam_no"]){//不走高速躲避收费和拥堵
            drivePolicy = AMapDrivingStrategyAvoidHighwaysAndFareAndCongestion;
        } else {
            drivePolicy = AMapDrivingStrategyFastest;
        }
    } else if (self.routePlanningType == AMapRoutePlanningTypeBus) {//公交
        policy = [paramsDict_ stringValueForKey:@"strategy" defaultValue:@"transit_time_first"];
        if ([policy isEqualToString:@"transit_time_first"]) {
            transitPolicy = AMapTransitStrategyFastest;
        } else if ([policy isEqualToString:@"transit_fee_first"]) {
            transitPolicy = AMapTransitStrategyMinFare;
        } else if ([policy isEqualToString:@"transit_transfer_first"]) {
            transitPolicy = AMapTransitStrategyMinTransfer;
        } else if ([policy isEqualToString:@"transit_walk_first"]) {
            transitPolicy = AMapTransitStrategyMinWalk;
        } else if ([policy isEqualToString:@"transit_comfort_first"]) {
            transitPolicy = AMapTransitStrategyMostComfortable;
        } else if ([policy isEqualToString:@"transit_subway_no"]) {
            transitPolicy = AMapTransitStrategyAvoidSubway;
        } else {
            transitPolicy = AMapTransitStrategyFastest;
        }
    }
    canDraw = NO;
    BOOL nightflag = [paramsDict_ boolValueForKey:@"nightflag" defaultValue:NO];
    NSString *city = [paramsDict_ stringValueForKey:@"city" defaultValue:@"北京"];
    switch (self.routePlanningType) {
        default:
        case AMapRoutePlanningTypeDrive: {//开车
            AMapDrivingRouteSearchRequest *navi = [[AMapDrivingRouteSearchRequest alloc] init];
            /* 返回扩展信息. */
            navi.requireExtension = YES;
            /* 出发点. */
            navi.origin = start;
            /* 途经点. */
            if (waypointsAry.count > 0) {
                navi.waypoints = waypointsAry;
            }
            /* 目的地. */
            navi.destination = end;
            /* 路线策略 */
            navi.strategy = drivePolicy;
            [self.mapSearch AMapDrivingRouteSearch:navi];
        }
        break;
            
        case AMapRoutePlanningTypeBus: {//公交
            AMapTransitRouteSearchRequest *navi = [[AMapTransitRouteSearchRequest alloc] init];
            /* 返回扩展信息. */
            navi.requireExtension = YES;
            /* 所在城市. */
            navi.city = city;
            /* 包含夜班车. */
            navi.nightflag = nightflag;
            /* 出发点. */
            navi.origin = start;
            /* 目的地. */
            navi.destination = end;
            /* 路线策略 */
            navi.strategy = transitPolicy;
            [self.mapSearch AMapTransitRouteSearch:navi];
        }
        break;
            
        case AMapRoutePlanningTypeWalk: {//步行
            AMapWalkingRouteSearchRequest *navi = [[AMapWalkingRouteSearchRequest alloc] init];
            /* 提供备选方案*/
            //navi.multipath = 1;
            /* 出发点. */
            navi.origin = start;
            /* 目的地. */
            navi.destination = end;
            [self.mapSearch AMapWalkingRouteSearch:navi];
        }
        break;
            
        case AMapRoutePlanningTypeRide: {//骑行
            AMapRidingRouteSearchRequest *navi = [[AMapRidingRouteSearchRequest alloc] init];
            /* 提供备选方案*/
            //navi.multipath = 1;
            /* 出发点. */
            navi.origin = start;
            /* 目的地. */
            navi.destination = end;
            [self.mapSearch AMapRidingRouteSearch:navi];
        }
            break;
    }
}

- (void)drawRoute:(NSDictionary *)paramsDict_ {
    if (!self.routePlans) {
        return;
    }
    if (!canDraw) {
        return;
    }
    NSString *routeId = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (routeId.length == 0) {
        return;
    }
    {//若路线已经添加，则移除先
        NSDictionary *target = [self.allRoutes objectForKey:routeId];
        if (target) {
            //移除路线
            NSArray *routePolylines = [target arrayValueForKey:@"routePolylines" defaultValue:@[]];
            [self.mapView removeOverlays:routePolylines];
            //移除路线标注
            NSArray *routeAnnotatioins = [target arrayValueForKey:@"routeAnnotatioins" defaultValue:@[]];
            [self.mapView removeAnnotations:routeAnnotatioins];
            //移除起终点
            MAPointAnnotation *destinationAnn = [target objectForKey:@"routeEnd"];
            MAPointAnnotation *startAnn = [target objectForKey:@"routeStart"];
            [self.mapView removeAnnotation:destinationAnn];
            [self.mapView removeAnnotation:startAnn];
            //移除从句柄里
            [self.allRoutes removeObjectForKey:routeId];
        }
    }
    BOOL isAutoFit = [paramsDict_ boolValueForKey:@"autoresizing" defaultValue:YES];
    NSInteger planIndex = [paramsDict_ integerValueForKey:@"index" defaultValue:0];
    //路线样式参数读取
    routeStyles = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    //添加路线
    if (self.routePlanningType == AMapRoutePlanningTypeBus) {//公交
        if (planIndex > self.routePlans.transits.count) {
            planIndex = self.routePlans.transits.count - 1;
        }
        if (planIndex < 0) {
            planIndex = 0;
        }
        AMapTransit *transits = self.routePlans.transits[planIndex];
        self.naviRoute = [MANaviRoute naviRouteForTransit:transits];
    } else {//步行、自驾
//        MANaviAnnotationType type = self.routePlanningType == AMapRoutePlanningTypeDrive ? MANaviAnnotationTypeDrive : MANaviAnnotationTypeWalking;
        
        MANaviAnnotationType type;
        if (self.routePlanningType == AMapRoutePlanningTypeDrive) {
            type = MANaviAnnotationTypeDrive;
        }else if (self.routePlanningType == AMapRoutePlanningTypeWalk) {
            type = MANaviAnnotationTypeWalking;
        }else {
            type = MANaviAnnotationTypeRide;
        }
        
        if (planIndex > self.routePlans.paths.count) {
            planIndex = self.routePlans.paths.count - 1;
        }
        if (planIndex < 0) {
            planIndex = 0;
        }
        AMapPath *path = self.routePlans.paths[planIndex];
        self.naviRoute = [MANaviRoute naviRouteForPath:path withNaviType:type];
    }
    //将路线添加到地图上
    NSMutableDictionary *routeOne = [NSMutableDictionary dictionary];
    if ([self.naviRoute.routePolylines count] > 0) {//线
        [self.mapView addOverlays:self.naviRoute.routePolylines];
        [routeOne setObject:self.naviRoute.routePolylines forKey:@"routePolylines"];
    }
    if ([self.naviRoute.naviAnnotations count] > 0) {//结点
        [self.mapView addAnnotations:self.naviRoute.naviAnnotations];
        [routeOne setObject:self.naviRoute.naviAnnotations forKey:@"routeAnnotatioins"];
    }
    //添加起点终点
    MANaviAnnotation *startAnnotation = [[MANaviAnnotation alloc] init];
    CLLocationCoordinate2D startAnnLoc = CLLocationCoordinate2DMake(self.routePlans.origin.latitude, self.routePlans.origin.longitude);
    startAnnotation.coordinate = startAnnLoc;
    startAnnotation.title = @"起点";
    startAnnotation.type = MANaviAnnotationTypeStart;
    MANaviAnnotation *destinationAnnotation = [[MANaviAnnotation alloc] init];
    CLLocationCoordinate2D destinAnnLoc = CLLocationCoordinate2DMake(self.routePlans.destination.latitude, self.routePlans.destination.longitude);
    destinationAnnotation.coordinate = destinAnnLoc;
    destinationAnnotation.title = @"终点";
    destinationAnnotation.type = MANaviAnnotationTypeEnd;
    [self.mapView addAnnotation:startAnnotation];
    [self.mapView addAnnotation:destinationAnnotation];
    [routeOne setObject:startAnnotation forKey:@"routeStart"];
    [routeOne setObject:destinationAnnotation forKey:@"routeEnd"];
    //将路线放入到allRoutes里
    if (!_allRoutes) {
        self.allRoutes = [NSMutableDictionary dictionary];
    }
    [self.allRoutes setObject:routeOne forKey:routeId];
    //缩放地图使其适应polylines的展示
    if (isAutoFit) {
        MAMapRect rect = [CommonUtility mapRectForOverlays:self.naviRoute.routePolylines];
        UIEdgeInsets edget = UIEdgeInsetsMake(20, 20, 20, 20);
        [self.mapView setVisibleMapRect:rect edgePadding:edget animated:YES];
    }
}

- (void)removeRoute:(NSDictionary *)paramsDict_ {
    NSArray *idAry = [paramsDict_ arrayValueForKey:@"ids" defaultValue:nil];
    if (idAry.count == 0) {
        return;
    }
    for (id idstr in idAry) {
        NSString *idString = [NSString stringWithFormat:@"%@",idstr];
        NSDictionary *target = [self.allRoutes objectForKey:idString];
        if (target) {
            //移除路线
            NSArray *routePolylines = [target arrayValueForKey:@"routePolylines" defaultValue:@[]];
            [self.mapView removeOverlays:routePolylines];
            //移除路线标注
            NSArray *routeAnnotatioins = [target arrayValueForKey:@"routeAnnotatioins" defaultValue:@[]];
            [self.mapView removeAnnotations:routeAnnotatioins];
            //移除起终点
            MANaviAnnotation *destinationAnn = [target objectForKey:@"routeEnd"];
            MANaviAnnotation *startAnn = [target objectForKey:@"routeStart"];
            [self.mapView removeAnnotation:destinationAnn];
            [self.mapView removeAnnotation:startAnn];
            //移除从句柄里
            [self.allRoutes removeObjectForKey:idString];
        }
    }
}

- (void)searchBusRoute:(NSDictionary *)paramsDict_ {
    NSString *city = [paramsDict_ stringValueForKey:@"city" defaultValue:nil];
    if (![city isKindOfClass:[NSString class]] || city.length==0) {
        return;
    }
    NSString *line = [paramsDict_ stringValueForKey:@"line" defaultValue:nil];
    if (![line isKindOfClass:[NSString class]] || line.length==0) {
        return;
    }
    //搜索实例对象
    if (![self initSearchClass]) {
        return;
    }
    NSInteger page = [paramsDict_ integerValueForKey:@"page" defaultValue:1];
    NSInteger offset = [paramsDict_ integerValueForKey:@"offset" defaultValue:20];
    getBusRouteCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    AMapBusLineNameSearchRequest *busSearch = [[AMapBusLineNameSearchRequest alloc] init];
    busSearch.keywords = line;
    busSearch.city = city;
    busSearch.requireExtension = YES;
    busSearch.offset = offset;
    busSearch.page = page;
    [self.mapSearch AMapBusLineNameSearch:busSearch];
}

- (void)drawBusRoute:(NSDictionary *)paramsDict_ {
    NSString *routeId = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    if (routeId.length == 0) {
        return;
    }
    {//若存在路线，则移除先
        NSDictionary *buslineDict = [self.allBusRoutes dictValueForKey:routeId defaultValue:nil];
        if (buslineDict) {
            NSArray *allbusstop = [buslineDict arrayValueForKey:@"annotations" defaultValue:nil];
            if (allbusstop.count > 0) {
                [self.mapView removeAnnotations:allbusstop];
            }
            MABusPolyline *targetPoly = [buslineDict objectForKey:@"polyline"];
            [self.mapView removeOverlay:targetPoly];
        }
    }
    BOOL isAutoFit = [paramsDict_ boolValueForKey:@"autoresizing" defaultValue:YES];
    NSInteger index = [paramsDict_ integerValueForKey:@"index" defaultValue:0];
    busLineStyles = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    if (index > self.allBusLines.count-1) {
        index = self.allBusLines.count - 1;
    }
    if (index < 0) {
        index = 0;
    }
    AMapBusLine *busLine = [self.allBusLines objectAtIndex:index];
    if (busLine == nil) {
        return;
    }
    if (!_allBusRoutes) {
        self.allBusRoutes = [NSMutableDictionary dictionary];
    }
    NSMutableDictionary *busLineInfo = [NSMutableDictionary dictionary];
    //添加路线上的公交站点标注
    NSMutableArray *busStopAnnotations = [NSMutableArray array];
    for (int i=0; i<busLine.busStops.count; i++) {
        AMapBusStop *busStop = [busLine.busStops objectAtIndex:i];
        BusStopAnnotation *annotation = [[BusStopAnnotation alloc] initWithBusStop:busStop];
        annotation.type = 0;
        if (i == 0) {
            annotation.type = 1;
        }
        if (i == busLine.busStops.count-1) {
            annotation.type = 2;
        }
        [busStopAnnotations addObject:annotation];
    }
    [self.mapView addAnnotations:busStopAnnotations];
    [busLineInfo setObject:busStopAnnotations forKey:@"annotations"];
    //添加路线
    MAPolyline *polyline = [CommonUtility polylineForBusLine:busLine];
    MABusPolyline *naviPolyline = [[MABusPolyline alloc] initWithPolyline:polyline];
    [self.mapView addOverlay:naviPolyline];
    [busLineInfo setObject:naviPolyline forKey:@"polyline"];
    [self.allBusRoutes setObject:busLineInfo forKey:routeId];
    //是否自动调整地图
    if (isAutoFit) {
        [self.mapView setVisibleMapRect:polyline.boundingMapRect edgePadding:UIEdgeInsetsMake(20, 20, 20, 20) animated:YES];
    }
}

- (void)removeBusRoute:(NSDictionary *)paramsDict_ {
    NSArray *idAry = [paramsDict_ arrayValueForKey:@"ids" defaultValue:nil];
    if (idAry.count == 0) {
        return;
    }
    for (id idstr in idAry) {
        NSString *idString = [NSString stringWithFormat:@"%@",idstr];
        NSDictionary *buslineDict = [self.allBusRoutes dictValueForKey:idString defaultValue:nil];
        if (buslineDict) {
            NSArray *allbusstop = [buslineDict arrayValueForKey:@"annotations" defaultValue:nil];
            if (allbusstop.count > 0) {
                [self.mapView removeAnnotations:allbusstop];
            }
            MABusPolyline *targetPoly = [buslineDict objectForKey:@"polyline"];
            [self.mapView removeOverlay:targetPoly];
        }
    }
}

- (void)searchInCity:(NSDictionary *)paramsDict_ {
    NSString *city = [paramsDict_ stringValueForKey:@"city" defaultValue:nil];
    if (![city isKindOfClass:[NSString class]] || city.length==0) {
        return;
    }
    NSString *keyword = [paramsDict_ stringValueForKey:@"keyword" defaultValue:nil];
    if (![keyword isKindOfClass:[NSString class]] || keyword.length==0) {
        return;
    }
    if (![self initSearchClass]) {
        return;
    }
    NSInteger pageOffset = [paramsDict_ integerValueForKey:@"offset" defaultValue:20];
    NSInteger pageIndex = [paramsDict_ integerValueForKey:@"page" defaultValue:1];
    int sortType = [paramsDict_ intValueForKey:@"sortrule" defaultValue:0];
    poiSearchCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    //开始搜索
    AMapPOIKeywordsSearchRequest *request = [[AMapPOIKeywordsSearchRequest alloc] init];
    request.keywords = keyword;
    request.city = city;
    request.offset = pageOffset;
    request.page = pageIndex;
    request.sortrule = sortType;
    request.requireExtension = YES;
    [self.mapSearch AMapPOIKeywordsSearch:request];
}

- (void)searchNearby:(NSDictionary *)paramsDict_ {
    NSString *keyword = [paramsDict_ stringValueForKey:@"keyword" defaultValue:nil];
    if (![keyword isKindOfClass:[NSString class]] || keyword.length==0) {
        //return;
    }
    float radius = [paramsDict_ floatValueForKey:@"radius" defaultValue:3000];
    if (radius == 0) {
        return;
    }
    float lon = [paramsDict_ floatValueForKey:@"lon" defaultValue:360];
    float lat = [paramsDict_ floatValueForKey:@"lat" defaultValue:360];
    if (![self isValidLon:lon lat:lat]) {
        return;
    }
    NSInteger pageOffset = [paramsDict_ integerValueForKey:@"offset" defaultValue:20];
    NSInteger pageIndex = [paramsDict_ integerValueForKey:@"page" defaultValue:1];
    int sortType = [paramsDict_ intValueForKey:@"sortrule" defaultValue:0];
    poiSearchCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    if (![self initSearchClass]) {
        return;
    }
    AMapPOIAroundSearchRequest *request = [[AMapPOIAroundSearchRequest alloc] init];
    request.location = [AMapGeoPoint locationWithLatitude:lat longitude:lon];
    request.keywords = keyword;
    request.sortrule = sortType;
    request.requireExtension = YES;
    request.offset = pageOffset;
    request.page = pageIndex;
    request.radius = radius;
    [self.mapSearch AMapPOIAroundSearch:request];
}

- (void)searchInPolygon:(NSDictionary *)paramsDict_ {
    NSString *keyword = [paramsDict_ stringValueForKey:@"keyword" defaultValue:nil];
    if (![keyword isKindOfClass:[NSString class]] || keyword.length==0) {
        return;
    }
    NSArray *pointsAry = [paramsDict_ arrayValueForKey:@"points" defaultValue:@[]];
    if (pointsAry.count == 0) {
        return;
    }
    if (![self initSearchClass]) {
        return;
    }
    NSMutableArray *allpoint = [NSMutableArray array];
    for (NSDictionary *point in pointsAry) {
        float lbLon = [point floatValueForKey:@"lon" defaultValue:360];
        float lbLat = [point floatValueForKey:@"lat" defaultValue:360];
        if (![self isValidLon:lbLon lat:lbLat]) {
            return;
        }
        AMapGeoPoint *pointOne = [AMapGeoPoint locationWithLatitude:lbLat longitude:lbLon];
        [allpoint addObject:pointOne];
    }
    NSInteger pageOffset = [paramsDict_ integerValueForKey:@"offset" defaultValue:20];
    NSInteger pageIndex = [paramsDict_ integerValueForKey:@"page" defaultValue:1];
    int sortType = [paramsDict_ intValueForKey:@"sortrule" defaultValue:0];
    poiSearchCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    AMapGeoPolygon *polygon = [AMapGeoPolygon polygonWithPoints:allpoint];
    AMapPOIPolygonSearchRequest *request = [[AMapPOIPolygonSearchRequest alloc] init];
    request.offset = pageOffset;
    request.page = pageIndex;
    request.polygon = polygon;
    request.keywords = keyword;
    request.requireExtension = YES;
    request.sortrule = sortType;
    [self.mapSearch AMapPOIPolygonSearch:request];
}

- (void)autocomplete:(NSDictionary *)paramsDict_ {
    NSString *keyword = [paramsDict_ stringValueForKey:@"keyword" defaultValue:nil];
    if (![keyword isKindOfClass:[NSString class]] || keyword.length==0) {
        return;
    }
    NSString *city = [paramsDict_ stringValueForKey:@"city" defaultValue:nil];
    if (![city isKindOfClass:[NSString class]] || city.length==0) {
        return;
    }
    if (![self initSearchClass]) {
        return;
    }
    autoComplateCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    AMapInputTipsSearchRequest *tips = [[AMapInputTipsSearchRequest alloc] init];
    tips.keywords = keyword;
    tips.city = city;
    [self.mapSearch AMapInputTipsSearch:tips];
}

- (void)districtSearch:(NSDictionary *)paramsDict_ {
    NSString *keyword = [paramsDict_ stringValueForKey:@"keyword" defaultValue:nil];
    if (![keyword isKindOfClass:[NSString class]] || keyword.length==0) {
        return;
    }
    _districtLineDict = [paramsDict_ dictValueForKey:@"showInMap" defaultValue:nil];
    BOOL showInMap = self.districtLineDict?YES:NO;
    NSInteger disSearchCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    //搜索实例对象
    if (![self initSearchClass]) {
        return;
    }
    ACDistrictSearch *dist = [[ACDistrictSearch alloc] init];
    dist.showInMap = showInMap;
    dist.searchResultCbid = disSearchCbid;
    dist.keywords = keyword;
    dist.requireExtension = YES;
    [self.mapSearch AMapDistrictSearch:dist];
}

#pragma mark 离线地图类
- (void)getProvinces:(NSDictionary *)paramsDict_ {
    NSInteger provinceCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSArray *allProvince = [MAOfflineMap sharedOfflineMap].provinces;
    NSMutableArray *provinceAry = [NSMutableArray array];
    for (MAOfflineProvince *province in allProvince) {
        NSMutableDictionary *provinceInfo = [NSMutableDictionary dictionary];
        NSString *name = province.name;
        if ([name isKindOfClass:[NSString class]] && name.length>0) {
            [provinceInfo setObject:name forKey:@"name"];
        }
        NSString *adcode = province.adcode;
        if ([adcode isKindOfClass:[NSString class]] && adcode.length>0) {
            [provinceInfo setObject:adcode forKey:@"adcode"];
        }
        NSString *jianpin = province.jianpin;
        if ([jianpin isKindOfClass:[NSString class]] && jianpin.length>0) {
            [provinceInfo setObject:jianpin forKey:@"jianpin"];
        }
        NSString *pinyin = province.pinyin;
        if ([pinyin isKindOfClass:[NSString class]] && pinyin.length>0) {
            [provinceInfo setObject:pinyin forKey:@"pinyin"];
        }
        [provinceInfo setObject:@(province.size) forKey:@"size"];
        [provinceInfo setObject:@(province.downloadedSize) forKey:@"downloadedSize"];
        [provinceInfo setObject:@(province.itemStatus) forKey:@"status"];
        [provinceAry addObject:provinceInfo];
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    if (provinceAry.count > 0) {
        [sendDict setObject:provinceAry forKey:@"provinces"];
    } else {
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    }
    [self sendResultEventWithCallbackId:provinceCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)getCitiesByProvince:(NSDictionary *)paramsDict_ {
    NSInteger provinceCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSArray *allProvince = [MAOfflineMap sharedOfflineMap].provinces;
    NSMutableArray *provinceAry = [NSMutableArray array];
    for (MAOfflineProvince *province in allProvince) {
        //省份包含的城市列表
        NSArray *cities = province.cities;
        NSMutableArray *citiesAry = [NSMutableArray array];
        for (MAOfflineItemCommonCity *city in cities) {
            NSMutableDictionary *cityInfo = [NSMutableDictionary dictionary];
            NSString *cityCode = city.cityCode;
            if ([cityCode isKindOfClass:[NSString class]] && cityCode.length>0) {
                [cityInfo setObject:cityCode forKey:@"cityCode"];
            }
            NSString *name = city.name;
            if ([name isKindOfClass:[NSString class]] && name.length>0) {
                [cityInfo setObject:name forKey:@"name"];
            }
            NSString *adcode = city.adcode;
            if ([adcode isKindOfClass:[NSString class]] && adcode.length>0) {
                [cityInfo setObject:adcode forKey:@"adcode"];
            }
            NSString *jianpin = city.jianpin;
            if ([jianpin isKindOfClass:[NSString class]] && jianpin.length>0) {
                [cityInfo setObject:jianpin forKey:@"jianpin"];
            }
            NSString *pinyin = city.pinyin;
            if ([pinyin isKindOfClass:[NSString class]] && pinyin.length>0) {
                [cityInfo setObject:pinyin forKey:@"pinyin"];
            }
            long long size = city.size;
            [cityInfo setObject:[NSNumber numberWithLongLong:size] forKey:@"size"];
            long long downloadSize = city.downloadedSize;
            [cityInfo setObject:[NSNumber numberWithLongLong:downloadSize] forKey:@"downloadedSize"];
            NSInteger status = city.itemStatus;
            [cityInfo setObject:[NSNumber numberWithInteger:status] forKey:@"status"];
            [citiesAry addObject:cityInfo];
        }
        //省份信息
        NSMutableDictionary *provinceInfo = [NSMutableDictionary dictionary];
        NSString *name = province.name;
        if ([name isKindOfClass:[NSString class]] && name.length>0) {
            [provinceInfo setObject:name forKey:@"name"];
        }
        NSString *adcode = province.adcode;
        if ([adcode isKindOfClass:[NSString class]] && adcode.length>0) {
            [provinceInfo setObject:adcode forKey:@"adcode"];
        }
        NSString *jianpin = province.jianpin;
        if ([jianpin isKindOfClass:[NSString class]] && jianpin.length>0) {
            [provinceInfo setObject:jianpin forKey:@"jianpin"];
        }
        NSString *pinyin = province.pinyin;
        if ([pinyin isKindOfClass:[NSString class]] && pinyin.length>0) {
            [provinceInfo setObject:pinyin forKey:@"pinyin"];
        }
        [provinceInfo setObject:@(province.size) forKey:@"size"];
        [provinceInfo setObject:@(province.downloadedSize) forKey:@"downloadedSize"];
        [provinceInfo setObject:@(province.itemStatus) forKey:@"status"];
        
        NSDictionary *provInfo = @{@"province":provinceInfo,@"cities":citiesAry};
        
        [provinceAry addObject:provInfo];
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    if (provinceAry.count > 0) {
        [sendDict setObject:provinceAry forKey:@"provinces"];
    } else {
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    }
    [self sendResultEventWithCallbackId:provinceCbid dataDict:sendDict errDict:nil doDelete:YES];
}
- (void)getMunicipalities:(NSDictionary *)paramsDict_ {
    NSInteger municipalitieCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSArray *allMunicipalities = [MAOfflineMap sharedOfflineMap].municipalities;
    NSMutableArray *municipalitiesAry = [NSMutableArray array];
    for (MAOfflineItemMunicipality *municipalities in allMunicipalities) {
        NSMutableDictionary *municipalitieInfo = [NSMutableDictionary dictionary];
        NSString *cityCode = municipalities.cityCode;
        if ([cityCode isKindOfClass:[NSString class]] && cityCode.length>0) {
            [municipalitieInfo setObject:cityCode forKey:@"cityCode"];
        }
        NSString *name = municipalities.name;
        if ([name isKindOfClass:[NSString class]] && name.length>0) {
            [municipalitieInfo setObject:name forKey:@"name"];
        }
        NSString *adcode = municipalities.adcode;
        if ([adcode isKindOfClass:[NSString class]] && adcode.length>0) {
            [municipalitieInfo setObject:adcode forKey:@"adcode"];
        }
        NSString *jianpin = municipalities.jianpin;
        if ([jianpin isKindOfClass:[NSString class]] && jianpin.length>0) {
            [municipalitieInfo setObject:jianpin forKey:@"jianpin"];
        }
        NSString *pinyin = municipalities.pinyin;
        if ([pinyin isKindOfClass:[NSString class]] && pinyin.length>0) {
            [municipalitieInfo setObject:pinyin forKey:@"pinyin"];
        }
        long long size = municipalities.size;
        [municipalitieInfo setObject:[NSNumber numberWithLongLong:size] forKey:@"size"];
        long long downloadSize = municipalities.downloadedSize;
        [municipalitieInfo setObject:[NSNumber numberWithLongLong:downloadSize] forKey:@"downloadedSize"];
        NSInteger status = municipalities.itemStatus;
        [municipalitieInfo setObject:[NSNumber numberWithInteger:status] forKey:@"status"];
        [municipalitiesAry addObject:municipalitieInfo];
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    if (municipalitiesAry.count > 0) {
        [sendDict setObject:municipalitiesAry forKey:@"municipalities"];
    } else {
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    }
    [self sendResultEventWithCallbackId:municipalitieCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)getNationWide:(NSDictionary *)paramsDict_ {
    NSInteger nationWideCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    MAOfflineItemNationWide *nationWide = [MAOfflineMap sharedOfflineMap].nationWide;
        NSMutableDictionary *nationWideInfo = [NSMutableDictionary dictionary];
        NSString *cityCode = nationWide.cityCode;
        if ([cityCode isKindOfClass:[NSString class]] && cityCode.length>0) {
            [nationWideInfo setObject:cityCode forKey:@"cityCode"];
        }
        NSString *name = nationWide.name;
        if ([name isKindOfClass:[NSString class]] && name.length>0) {
            [nationWideInfo setObject:name forKey:@"name"];
        }
        NSString *adcode = nationWide.adcode;
        if ([adcode isKindOfClass:[NSString class]] && adcode.length>0) {
            [nationWideInfo setObject:adcode forKey:@"adcode"];
        }
        NSString *jianpin = nationWide.jianpin;
        if ([jianpin isKindOfClass:[NSString class]] && jianpin.length>0) {
            [nationWideInfo setObject:jianpin forKey:@"jianpin"];
        }
        NSString *pinyin = nationWide.pinyin;
        if ([pinyin isKindOfClass:[NSString class]] && pinyin.length>0) {
            [nationWideInfo setObject:pinyin forKey:@"pinyin"];
        }
        long long size = nationWide.size;
        [nationWideInfo setObject:[NSNumber numberWithLongLong:size] forKey:@"size"];
        long long downloadSize = nationWide.downloadedSize;
        [nationWideInfo setObject:[NSNumber numberWithLongLong:downloadSize] forKey:@"downloadedSize"];
        NSInteger status = nationWide.itemStatus;
        [nationWideInfo setObject:[NSNumber numberWithInteger:status] forKey:@"status"];
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    if (nationWideInfo.count > 0) {
        [sendDict setObject:nationWideInfo forKey:@"nationWide"];
    } else {
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    }
    [self sendResultEventWithCallbackId:nationWideCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)getAllCities:(NSDictionary *)paramsDict_ {
    NSInteger allCitiesCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSArray *allCities = [MAOfflineMap sharedOfflineMap].cities;
    NSMutableArray *citiesAry = [NSMutableArray array];
    for (MAOfflineCity *cities in allCities) {
        NSMutableDictionary *citieInfo = [NSMutableDictionary dictionary];
        NSString *cityCode = cities.cityCode;
        if ([cityCode isKindOfClass:[NSString class]] && cityCode.length>0) {
            [citieInfo setObject:cityCode forKey:@"cityCode"];
        }
        NSString *name = cities.name;
        if ([name isKindOfClass:[NSString class]] && name.length>0) {
            [citieInfo setObject:name forKey:@"name"];
        }
        NSString *adcode = cities.adcode;
        if ([adcode isKindOfClass:[NSString class]] && adcode.length>0) {
            [citieInfo setObject:adcode forKey:@"adcode"];
        }
        NSString *jianpin = cities.jianpin;
        if ([jianpin isKindOfClass:[NSString class]] && jianpin.length>0) {
            [citieInfo setObject:jianpin forKey:@"jianpin"];
        }
        NSString *pinyin = cities.pinyin;
        if ([pinyin isKindOfClass:[NSString class]] && pinyin.length>0) {
            [citieInfo setObject:pinyin forKey:@"pinyin"];
        }
        long long size = cities.size;
        [citieInfo setObject:[NSNumber numberWithLongLong:size] forKey:@"size"];
        long long downloadSize = cities.downloadedSize;
        [citieInfo setObject:[NSNumber numberWithLongLong:downloadSize] forKey:@"downloadedSize"];
        NSInteger status = cities.itemStatus;
        [citieInfo setObject:[NSNumber numberWithInteger:status] forKey:@"status"];
        [citiesAry addObject:citieInfo];
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    if (citiesAry.count > 0) {
        [sendDict setObject:citiesAry forKey:@"cities"];
    } else {
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    }
    [self sendResultEventWithCallbackId:allCitiesCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)getVersion:(NSDictionary *)paramsDict_ {
    NSInteger versionCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSString *verson = [MAOfflineMap sharedOfflineMap].version;
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    if ([verson isKindOfClass:[NSString class]] && verson.length>0) {
        [sendDict setObject:verson forKey:@"verson"];
    } else {
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    }
    [self sendResultEventWithCallbackId:versionCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)downloadRegion:(NSDictionary *)paramsDict_ {
    NSString *adcode = [paramsDict_ stringValueForKey:@"adcode" defaultValue:@""];
    if (adcode.length == 0) {
        return;
    }
    NSInteger downloadCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    BOOL shouldLoad = [paramsDict_ boolValueForKey:@"shouldContinueWhenAppEntersBackground" defaultValue:NO];
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    //查找目标
    NSArray *allmunicipalities = [MAOfflineMap sharedOfflineMap].cities;
    MAOfflineItem *targetItem ;
    for (MAOfflineItem *target in allmunicipalities) {
        NSString *newAdcod = target.adcode;
        if ([newAdcod isKindOfClass:[NSString class]] && newAdcod.length>0) {
            if ([newAdcod isEqualToString:adcode]) {
                targetItem = target;
                break;
            }
        }
    }
    if (!targetItem) {
        return;
    }
    //开始下载
    [[MAOfflineMap sharedOfflineMap] downloadItem:targetItem shouldContinueWhenAppEntersBackground:shouldLoad downloadBlock:^(MAOfflineItem *targetItem, MAOfflineMapDownloadStatus downloadStatus, id info) {
        /* Manipulations to your application’s user interface must occur on the main thread. */
        dispatch_async(dispatch_get_main_queue(), ^{
            if(downloadStatus == MAOfflineMapDownloadStatusProgress) {
                NSMutableDictionary *sizeInfo = [NSMutableDictionary dictionary];
                NSDictionary *orInfo = (NSDictionary *)info;
                long long expectedSize = [orInfo longlongValueForKey:@"MAOfflineMapDownloadExpectedSizeKey" defaultValue:0];
                long long receivedSize = [orInfo longlongValueForKey:@"MAOfflineMapDownloadReceivedSizeKey" defaultValue:0];
                [sizeInfo setObject:[NSNumber numberWithLongLong:expectedSize] forKey:@"expectedSize"];
                [sizeInfo setObject:[NSNumber numberWithLongLong:receivedSize] forKey:@"receivedSize"];
                [sendDict setObject:sizeInfo forKey:@"info"];
            }
            [sendDict setObject:[NSNumber numberWithInteger:downloadStatus] forKey:@"status"];
            [self sendResultEventWithCallbackId:downloadCbid dataDict:sendDict errDict:nil doDelete:NO];
        });
    }];
}

- (void)isDownloading:(NSDictionary *)paramsDict_ {
    NSString *adcode = [paramsDict_ stringValueForKey:@"adcode" defaultValue:@""];
    if (adcode.length == 0) {
        return;
    }
    NSInteger isdownloadCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    //查找目标
    NSArray *allmunicipalities = [MAOfflineMap sharedOfflineMap].cities;
    MAOfflineItemMunicipality *targetItem ;
    for (MAOfflineItemMunicipality *target in allmunicipalities) {
        NSString *newAdcod = target.adcode;
        if ([newAdcod isKindOfClass:[NSString class]] && newAdcod.length>0) {
            if ([newAdcod isEqualToString:adcode]) {
                targetItem = target;
                break;
            }
        }
    }
    if (!targetItem) {
        return;
    }
    BOOL isDown = [[MAOfflineMap sharedOfflineMap] isDownloadingForItem:targetItem];
    [self sendResultEventWithCallbackId:isdownloadCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:isDown] forKey:@"status"] errDict:nil doDelete:YES];
}

- (void)pauseDownload:(NSDictionary *)paramsDict_ {
    NSString *adcode = [paramsDict_ stringValueForKey:@"adcode" defaultValue:@""];
    if (adcode.length == 0) {
        return;
    }
    //查找目标
    NSArray *allmunicipalities = [MAOfflineMap sharedOfflineMap].cities;
    MAOfflineItemMunicipality *targetItem ;
    for (MAOfflineItemMunicipality *target in allmunicipalities) {
        NSString *newAdcod = target.adcode;
        if ([newAdcod isKindOfClass:[NSString class]] && newAdcod.length>0) {
            if ([newAdcod isEqualToString:adcode]) {
                targetItem = target;
                break;
            }
        }
    }
    if (!targetItem) {
        return;
    }
    [[MAOfflineMap sharedOfflineMap] pauseItem:targetItem];
}

- (void)cancelAllDownload:(NSDictionary *)paramsDict_ {
    [[MAOfflineMap sharedOfflineMap] cancelAll];
}

- (void)clearDisk:(NSDictionary *)paramsDict_ {
    [[MAOfflineMap sharedOfflineMap] clearDisk];
}

- (void)checkNewestVersion:(NSDictionary *)paramsDict_ {
    NSInteger newversionCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    [[MAOfflineMap sharedOfflineMap] checkNewestVersion:^(BOOL hasNewestVersion) {
        /* Manipulations to your application's user interface must occur on the main thread. */
        dispatch_async(dispatch_get_main_queue(), ^{
            [self sendResultEventWithCallbackId:newversionCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:hasNewestVersion] forKey:@"status"] errDict:nil doDelete:YES];
        });
    }];
}

- (void)reloadMap:(NSDictionary *)paramsDict_ {
    if (self.mapView) {
        [self.mapView reloadMap];
    }
}

#pragma mark 经纬度转换、轨迹纠偏

- (void)convertCoordinate:(NSDictionary *)paramsDict_ {
    NSString *locType = [paramsDict_ stringValueForKey:@"type" defaultValue:@"GPS"];
    AMapCoordinateType type = -1;
    if([locType hasPrefix:@"baidu"]) {
        type = AMapCoordinateTypeBaidu;
    } else if([locType hasPrefix:@"GPS"]) {
        type = AMapCoordinateTypeGPS;
    } else if([locType hasPrefix:@"mapBar"]) {
        type = AMapCoordinateTypeMapBar;
    } else if([locType hasPrefix:@"mapABC"]) {
        type = AMapCoordinateTypeMapABC;
    } else if([locType hasPrefix:@"sosoMap"]) {
        type = AMapCoordinateTypeSoSoMap;
    } else if([locType hasPrefix:@"aliYun"]) {
        type = AMapCoordinateTypeAliYun;
    } else if([locType hasPrefix:@"google"]) {
        type = AMapCoordinateTypeGoogle;
    }
    NSDictionary *dict = [paramsDict_ dictValueForKey:@"location" defaultValue:@{}];
    CLLocationCoordinate2D loc = CLLocationCoordinate2DMake([[dict objectForKey:@"lat"] doubleValue], [[dict objectForKey:@"lon"] doubleValue]);
    //目标经纬度转换为高德坐标
    CLLocationCoordinate2D l = AMapCoordinateConvert(loc, type);
    NSInteger convertCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    [self sendResultEventWithCallbackId:convertCbid dataDict:@{@"lat":@(l.latitude),@"lon":@(l.longitude)} errDict:nil doDelete:YES];
}

- (void)processedTrace:(NSDictionary *)paramsDict_ {
    NSString *dataPath = [paramsDict_ stringValueForKey:@"path" defaultValue:@""];
    if (dataPath.length == 0) {
        return;
    }
    NSString *fileFullPath = [self getPathWithUZSchemeURL:dataPath];
    if(![[NSFileManager defaultManager] fileExistsAtPath:fileFullPath]) {
        return;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:fileFullPath];
    NSError *err = nil;
    NSArray *locInfoArr = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if(!locInfoArr) {
        NSLog(@"[Turbo_AMap] Read trace data error: %@", err);
        return;
    }
    NSString *locType = [paramsDict_ stringValueForKey:@"type" defaultValue:@"GPS"];
    AMapCoordinateType type = -1;
    if([locType hasPrefix:@"baidu"]) {
        type = AMapCoordinateTypeBaidu;
    } else if([locType hasPrefix:@"GPS"]) {
        type = AMapCoordinateTypeGPS;
    } else if([locType hasPrefix:@"mapBar"]) {
        type = AMapCoordinateTypeMapBar;
    } else if([locType hasPrefix:@"mapABC"]) {
        type = AMapCoordinateTypeMapABC;
    } else if([locType hasPrefix:@"sosoMap"]) {
        type = AMapCoordinateTypeSoSoMap;
    } else if([locType hasPrefix:@"aliYun"]) {
        type = AMapCoordinateTypeAliYun;
    } else if([locType hasPrefix:@"google"]) {
        type = AMapCoordinateTypeGoogle;
    }
    
    NSMutableArray *mArr = [NSMutableArray array];
    for(NSDictionary *dict in locInfoArr) {
        MATraceLocation *loc = [[MATraceLocation alloc] init];
        if ([dict objectForKey:@"latitude"]) {
            loc.loc = CLLocationCoordinate2DMake([[dict objectForKey:@"latitude"] doubleValue], [[dict objectForKey:@"longitude"] doubleValue]);
        } else {
            loc.loc = CLLocationCoordinate2DMake([[dict objectForKey:@"lat"] doubleValue], [[dict objectForKey:@"lon"] doubleValue]);
        }
        double speed = [[dict objectForKey:@"speed"] doubleValue];
        loc.speed = speed * 3.6; //m/s  转 km/h
        loc.time = [[dict objectForKey:@"loctime"] doubleValue];
        loc.angle = [[dict objectForKey:@"bearing"] doubleValue];;
        [mArr addObject:loc];
    }
    
    NSString *savePath = [paramsDict_ stringValueForKey:@"savePath" defaultValue:@""];
    if (savePath.length > 0) {
        savePath = [self getPathWithUZSchemeURL:savePath];
    } else {
        savePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"aMapProcessedTraceData.txt"];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
    }
    NSInteger processCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    MATraceManager *manageer = [[MATraceManager alloc] init];
    NSMutableArray *processedArr = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    NSOperation *op = [manageer queryProcessedTraceWith:mArr type:type processingCallback:^(int index, NSArray<MATracePoint *> *points) {
        if (points.count > 0) {
            [processedArr addObjectsFromArray:points];
        }
    }  finishCallback:^(NSArray<MATracePoint *> *points, double distance) {
        weakSelf.queryOperation = nil;
        if (points.count > 0) {
            [processedArr addObjectsFromArray:points];
        }
        NSMutableArray *allProcessedPoint = [NSMutableArray array];
        for (MATracePoint *point in processedArr) {
            NSDictionary *pointInfo = @{@"longitude":@(point.longitude),@"latitude":@(point.latitude)};
            [allProcessedPoint addObject:pointInfo];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *jsonError = nil;
            NSData *procData = [NSJSONSerialization dataWithJSONObject:allProcessedPoint options:NSJSONWritingPrettyPrinted error:&jsonError];
            if ([procData length] > 0 && jsonError == nil){
                BOOL suc = [procData writeToFile:savePath atomically:YES];
                if (suc) {
                    [weakSelf sendResultEventWithCallbackId:processCbid dataDict:@{@"status":@(YES),@"path":savePath} errDict:nil doDelete:YES];
                } else {
                    [weakSelf sendResultEventWithCallbackId:processCbid dataDict:@{@"status":@(NO)} errDict:@{@"code":@(-2),@"msg":@"unknow error"} doDelete:YES];
                }
            } else {
                [weakSelf sendResultEventWithCallbackId:processCbid dataDict:@{@"status":@(NO)} errDict:@{@"code":@(-1),@"msg":@"unknow error"} doDelete:YES];
            }
        });
    } failedCallback:^(int errorCode, NSString *errorDesc) {
        if(![errorDesc isKindOfClass:[NSString class]] || errorDesc.length==0) {
            errorDesc = @"";
        }
        [weakSelf sendResultEventWithCallbackId:processCbid dataDict:@{@"status":@(NO)} errDict:@{@"code":@(errorCode),@"msg":errorDesc} doDelete:YES];
        weakSelf.queryOperation = nil;
    }];
    self.queryOperation = op;
}

- (void)cancelProcessedTrace:(NSDictionary *)paramsDict_ {
    if(self.queryOperation) {
        [self.queryOperation cancel];
        self.queryOperation = nil;
    }
}

#pragma mark - AMapSearchDelegate -

- (void)onGeocodeSearchDone:(AMapGeocodeSearchRequest *)request response:(AMapGeocodeSearchResponse *)response {//根据地址搜经纬度
    if(response.geocodes.count == 0) {
        NSMutableDictionary *cbDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [cbDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
        [self sendResultEventWithCallbackId:getLoctionByAddrCbid dataDict:cbDict errDict:[NSDictionary dictionaryWithObject:@"搜索关键字模糊" forKey:@"msg"]  doDelete:YES];
        return ;
    }
    AMapGeocode *placeMark = [response.geocodes firstObject];
    NSMutableDictionary *cbDict = [NSMutableDictionary dictionaryWithCapacity:2];
    [cbDict setObject:[NSNumber numberWithFloat:placeMark.location.longitude] forKey:@"lon"];
    [cbDict setObject:[NSNumber numberWithFloat:placeMark.location.latitude] forKey:@"lat"];
    [cbDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    [self sendResultEventWithCallbackId:getLoctionByAddrCbid dataDict:cbDict errDict:nil  doDelete:YES];
}

- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response {//根据经纬度搜地址
    AMapReGeocode *target = response.regeocode;
    if (!target) {
       [self sendResultEventWithCallbackId:getAddrByLocationCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"status"] errDict:nil  doDelete:YES];
       
        return;
    }
    AMapAddressComponent *placemark = target.addressComponent;
    NSString *city = placemark.city;
    NSString *name = placemark.township;
    NSString *street = placemark.streetNumber.street;
    NSString *state = placemark.province;
    NSString *subLocality = placemark.district;
    NSString *subThoroughfare = placemark.streetNumber.number;
    NSString *thoroughfare = placemark.neighborhood;
    NSMutableDictionary *cbDict = [NSMutableDictionary dictionaryWithCapacity:2];
    if ([city isKindOfClass:[NSString class]] && city.length>0) {
    } else {
        city = @"";
    }
    [cbDict setObject:city forKey:@"city"];
    if ([name isKindOfClass:[NSString class]] && name.length>0) {
    } else {
        name = @"";
    }
    [cbDict setObject:name forKey:@"township"];
    if ([street isKindOfClass:[NSString class]] && street.length>0) {
    } else {
        street = @"";
    }
    [cbDict setObject:street forKey:@"street"];
    if ([state isKindOfClass:[NSString class]] && state.length>0) {
    } else {
        state = @"";
    }
    [cbDict setObject:state forKey:@"state"];
    if ([subLocality isKindOfClass:[NSString class]] && subLocality.length>0) {
    } else {
        subLocality = @"";
    }
    [cbDict setObject:subLocality forKey:@"district"];
    if ([subThoroughfare isKindOfClass:[NSString class]] && subThoroughfare.length>0) {
    } else {
        subThoroughfare = @"";
    }
    [cbDict setObject:subThoroughfare forKey:@"number"];
    if (![thoroughfare isKindOfClass:[NSString class]] || thoroughfare.length==0) {
        thoroughfare = @"";
    }
    [cbDict setObject:thoroughfare forKey:@"thoroughfare"];
    NSString *addrStr = [NSString stringWithFormat:@"%@%@%@%@%@%@",state,city,subLocality,name,street,subThoroughfare];
    if (![addrStr isKindOfClass:[NSString class]] || addrStr.length==0) {
        addrStr = @"";
    }
    [cbDict setObject:addrStr forKey:@"address"];
    
    NSString *building = placemark.building;
    if (![building isKindOfClass:[NSString class]] || building.length==0) {
        building = @"";
    }
    [cbDict setObject:building forKey:@"building"];
    NSString *adcode = placemark.adcode;
    if (![adcode isKindOfClass:[NSString class]] || adcode.length==0) {
        adcode = @"";
    }
    [cbDict setObject:adcode forKey:@"adcode"];
    NSString *citycode = placemark.citycode;
    if (![citycode isKindOfClass:[NSString class]] || citycode.length==0) {
        citycode = @"";
    }
    [cbDict setObject:citycode forKey:@"citycode"];
    NSString *towncode = placemark.towncode;
    if (![towncode isKindOfClass:[NSString class]] || towncode.length==0) {
        towncode = @"";
    }
    [cbDict setObject:towncode forKey:@"towncode"];
    [cbDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    [self sendResultEventWithCallbackId:getAddrByLocationCbid dataDict:cbDict errDict:nil  doDelete:YES];
   
}

- (void)onInputTipsSearchDone:(AMapInputTipsSearchRequest *)request response:(AMapInputTipsSearchResponse *)response {//输入提示回调
    if (autoComplateCbid < 0) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    if (response.count > 0) {
        [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
        NSArray *tipsAry = response.tips;
        if (tipsAry.count > 0) {
            NSMutableArray *allTips = [NSMutableArray array];
            for (AMapTip *mapTip in tipsAry) {
                NSMutableDictionary *tipsInfo = [NSMutableDictionary dictionary];
                NSString *uid = mapTip.uid;
                if ([uid isKindOfClass:[NSString class]] && uid.length>0) {
                    [tipsInfo setObject:uid forKey:@"uid"];
                }
                NSString *name = mapTip.name;
                if ([name isKindOfClass:[NSString class]] && name.length>0) {
                    [tipsInfo setObject:name forKey:@"name"];
                }
                NSString *adcode = mapTip.adcode;
                if ([adcode isKindOfClass:[NSString class]] && adcode.length>0) {
                    [tipsInfo setObject:adcode forKey:@"adcode"];
                }
                NSString *district = mapTip.district;
                if ([district isKindOfClass:[NSString class]] && district.length>0) {
                    [tipsInfo setObject:district forKey:@"district"];
                }
                float lon = mapTip.location.longitude;
                float lat = mapTip.location.latitude;
                [tipsInfo setObject:[NSNumber numberWithFloat:lat] forKey:@"lat"];
                [tipsInfo setObject:[NSNumber numberWithFloat:lon] forKey:@"lon"];
                [allTips addObject:tipsInfo];
            }
            [sendDict setObject:allTips forKey:@"tips"];
        }
    } else {
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    }
    [self sendResultEventWithCallbackId:autoComplateCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)onPOISearchDone:(AMapPOISearchBaseRequest *)request response:(AMapPOISearchResponse *)response {//POI 搜索回调
    if (poiSearchCbid < 0) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    if (response.pois.count == 0) {
        //建议列表
        AMapSuggestion *suggestion = response.suggestion;
        if (suggestion) {
            NSMutableDictionary *suggestDict = [NSMutableDictionary dictionary];
            NSArray *keywordsAry = suggestion.keywords;
            if (keywordsAry.count > 0) {
                NSMutableArray *keyAry = [NSMutableArray array];
                for (NSString *keyStr in keywordsAry) {
                    if ([keyStr isKindOfClass:[NSString class]] && keyStr.length>0) {
                        [keyAry addObject:keyStr];
                    }
                }
                [suggestDict setObject:keyAry forKey:@"keywords"];
            }
            NSArray *citiesAry = suggestion.cities;
            if (citiesAry.count > 0) {
                NSMutableArray *cityAry = [NSMutableArray array];
                for (AMapCity *city in citiesAry) {
                    NSString *cityStr = city.city;
                    if ([cityStr isKindOfClass:[NSString class]] && cityStr.length>0) {
                        [cityAry addObject:cityStr];
                    }
                }
                [suggestDict setObject:cityAry forKey:@"cities"];
            }
            if (suggestDict.count > 0) {
                [sendDict setObject:suggestDict forKey:@"suggestion"];
            }
        }
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    } else {
        [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
        NSArray *poiTargetAry = response.pois;
        if (poiTargetAry.count > 0) {
            NSMutableArray *poiAry = [NSMutableArray array];
            for (AMapPOI *mapPoi in poiTargetAry) {
                NSMutableDictionary *poiInfo = [NSMutableDictionary dictionary];
                NSString *uid = mapPoi.uid;
                if ([uid isKindOfClass:[NSString class]] && uid.length>0) {
                    [poiInfo setObject:uid forKey:@"uid"];
                }
                NSString *name = mapPoi.name;
                if ([name isKindOfClass:[NSString class]] && name.length>0) {
                    [poiInfo setObject:name forKey:@"name"];
                }
                NSString *type = mapPoi.type;
                if ([type isKindOfClass:[NSString class]] && type.length>0) {
                    [poiInfo setObject:type forKey:@"type"];
                }
                NSString *address = mapPoi.address;
                if ([address isKindOfClass:[NSString class]] && address.length>0) {
                    [poiInfo setObject:address forKey:@"address"];
                }
                // 省
                NSString * province = mapPoi.province;
                if ([province isKindOfClass:[NSString class]] && province.length>0) {
                    [poiInfo setObject:province forKey:@"province"];
                }
                // 市
                NSString * city = mapPoi.city;
                if ([city isKindOfClass:[NSString class]] && city.length>0) {
                    [poiInfo setObject:city forKey:@"city"];
                }
                // 区域
                NSString * district = mapPoi.district;
                if ([district isKindOfClass:[NSString class]] && district.length>0) {
                    [poiInfo setObject:district forKey:@"district"];
                }
                
                NSString *tel = mapPoi.tel;
                if ([tel isKindOfClass:[NSString class]] && tel.length>0) {
                    [poiInfo setObject:tel forKey:@"tel"];
                }
                float lon = mapPoi.location.longitude;
                float lat = mapPoi.location.latitude;
                [poiInfo setObject:[NSNumber numberWithFloat:lat] forKey:@"lat"];
                [poiInfo setObject:[NSNumber numberWithFloat:lon] forKey:@"lon"];
                [poiInfo setObject:[NSNumber numberWithInteger:mapPoi.distance] forKey:@"distance"];
                [poiAry addObject:poiInfo];
            }
            [sendDict setObject:poiAry forKey:@"pois"];
        }
    }
    [self sendResultEventWithCallbackId:poiSearchCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)onBusLineSearchDone:(AMapBusLineBaseSearchRequest *)request response:(AMapBusLineSearchResponse *)response{//公交路线搜索回调
    if (getBusRouteCbid < 0) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
    if (response.buslines.count != 0) {
        //公交线路列表
        NSArray *buslines = response.buslines;
        self.allBusLines = buslines;
        if (buslines.count > 0) {
            NSMutableArray *buslinesAry = [NSMutableArray array];
            for (AMapBusLine *busLine in buslines) {
                NSMutableDictionary *busLineInfo = [NSMutableDictionary dictionary];
                NSString *uid = busLine.uid;
                if ([uid isKindOfClass:[NSString class]] && uid.length>0) {
                    [busLineInfo setObject:uid forKey:@"uid"];
                }
                NSString *type = busLine.uid;
                if ([type isKindOfClass:[NSString class]] && type.length>0) {
                    [busLineInfo setObject:type forKey:@"type"];
                }
                NSString *name = busLine.name;
                if ([name isKindOfClass:[NSString class]] && name.length>0) {
                    [busLineInfo setObject:name forKey:@"name"];
                }
                NSString *startStop = busLine.startStop;
                if ([startStop isKindOfClass:[NSString class]] && startStop.length>0) {
                    [busLineInfo setObject:startStop forKey:@"startStop"];
                }
                NSString *endStop = busLine.endStop;
                if ([endStop isKindOfClass:[NSString class]] && endStop.length>0) {
                    [busLineInfo setObject:endStop forKey:@"endStop"];
                }
                NSString *startTime = busLine.startTime;
                if ([startTime isKindOfClass:[NSString class]] && startTime.length>0) {
                    [busLineInfo setObject:startTime forKey:@"startTime"];
                }
                NSString *endTime = busLine.endTime;
                if ([endTime isKindOfClass:[NSString class]] && endTime.length>0) {
                    [busLineInfo setObject:endTime forKey:@"endTime"];
                }
                NSString *company = busLine.company;
                if ([company isKindOfClass:[NSString class]] && company.length>0) {
                    [busLineInfo setObject:company forKey:@"company"];
                }
                [busLineInfo setObject:[NSNumber numberWithFloat:busLine.distance] forKey:@"distance"];
                [busLineInfo setObject:[NSNumber numberWithFloat:busLine.basicPrice] forKey:@"basicPrice"];
                [busLineInfo setObject:[NSNumber numberWithFloat:busLine.totalPrice] forKey:@"totalPrice"];
                //途经站点信息
                NSArray *busStops = busLine.busStops;
                if (busStops.count > 0) {
                    NSMutableArray *busStopsAry = [NSMutableArray array];
                    for (AMapBusStop *busStop in buslines) {
                        NSMutableDictionary *busStopInfo = [NSMutableDictionary dictionary];
                        NSString *uid = busStop.uid;
                        if ([uid isKindOfClass:[NSString class]] && uid.length>0) {
                            [busStopInfo setObject:uid forKey:@"uid"];
                        }
                        NSString *name = busStop.name;
                        if ([name isKindOfClass:[NSString class]] && name.length>0) {
                            [busStopInfo setObject:name forKey:@"name"];
                        }
                        AMapGeoPoint *location = busStop.location;
                        [busStopInfo setObject:[NSNumber numberWithFloat:location.latitude] forKey:@"lat"];
                        [busStopInfo setObject:[NSNumber numberWithFloat:location.longitude] forKey:@"lon"];
                        [busStopsAry addObject:busStopInfo];
                    }
                    if (busStopsAry.count > 01) {
                        [busLineInfo setObject:busStopsAry forKey:@"busStops"];
                    }
                }
                if (busLineInfo.count > 0) {
                    [buslinesAry addObject:busLineInfo];
                }
            }
            if (buslinesAry.count > 0) {
                [sendDict setObject:buslinesAry forKey:@"buslines"];
            }
        }
        [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
        [self sendResultEventWithCallbackId:getBusRouteCbid dataDict:sendDict errDict:nil doDelete:YES];
    } else {
        //建议列表
        AMapSuggestion *suggestion = response.suggestion;
        if (suggestion) {
            NSMutableDictionary *suggestDict = [NSMutableDictionary dictionary];
            NSArray *keywordsAry = suggestion.keywords;
            if (keywordsAry.count > 0) {
                NSMutableArray *keyAry = [NSMutableArray array];
                for (NSString *keyStr in keywordsAry) {
                    if ([keyStr isKindOfClass:[NSString class]] && keyStr.length>0) {
                        [keyAry addObject:keyStr];
                    }
                }
                [suggestDict setObject:keyAry forKey:@"keywords"];
            }
            NSArray *citiesAry = suggestion.cities;
            if (citiesAry.count > 0) {
                NSMutableArray *cityAry = [NSMutableArray array];
                for (AMapCity *city in citiesAry) {
                    NSString *cityStr = city.city;
                    if ([cityStr isKindOfClass:[NSString class]] && cityStr.length>0) {
                        [cityAry addObject:cityStr];
                    }
                }
                [suggestDict setObject:cityAry forKey:@"cities"];
            }
            if (suggestDict.count > 0) {
                [sendDict setObject:suggestDict forKey:@"suggestion"];
            }
        }
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
    }
    [self sendResultEventWithCallbackId:getBusRouteCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)onRouteSearchDone:(AMapRouteSearchBaseRequest *)request response:(AMapRouteSearchResponse *)response {//路线规划搜索回调
    AMapRoute *mapRoute = response.route;
    self.routePlans = response.route;
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    if (mapRoute == nil) {
        [sendDict setObject:[NSNumber numberWithBool:NO] forKey:@"status"];
        [self sendResultEventWithCallbackId:searcRouteCbid dataDict:sendDict errDict:nil doDelete:YES];
        canDraw = NO;
        return;
    }
    canDraw = YES;
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    //起始点坐标
    NSMutableDictionary *startNode = [NSMutableDictionary dictionary];
    float startNodeLat = mapRoute.origin.latitude;
    float startNodeLon = mapRoute.origin.longitude;
    [startNode setObject:[NSNumber numberWithFloat:startNodeLat] forKey:@"lat"];
    [startNode setObject:[NSNumber numberWithFloat:startNodeLon] forKey:@"lon"];
    NSMutableDictionary *endNode = [NSMutableDictionary dictionary];
    float endNodeLat = mapRoute.origin.latitude;
    float endNodeLon = mapRoute.origin.longitude;
    [endNode setObject:[NSNumber numberWithFloat:endNodeLat] forKey:@"lat"];
    [endNode setObject:[NSNumber numberWithFloat:endNodeLon] forKey:@"lon"];
    [sendDict setObject:startNode forKey:@"start"];
    [sendDict setObject:endNode forKey:@"end"];
    //出租车费用
    [sendDict setObject:[NSNumber numberWithFloat:mapRoute.taxiCost] forKey:@"taxiCost"];
    //步行、骑行、驾车路线方案
    if (mapRoute.paths.count > 0) {
        NSMutableArray *pathAry = [self getPathInfo:mapRoute.paths];
        if (pathAry.count > 0) {
            [sendDict setObject:pathAry forKey:@"paths"];
        }
    }
    //公交路线方案
    if (mapRoute.transits.count > 0) {
        NSMutableArray *transits = [self getTransitsInfo:mapRoute.transits];
        if (transits.count > 0) {
            [sendDict setObject:transits forKey:@"transits"];
        }
    }
    [self sendResultEventWithCallbackId:searcRouteCbid dataDict:sendDict errDict:nil doDelete:YES];
}

- (void)onDistrictSearchDone:(AMapDistrictSearchRequest *)request response:(AMapDistrictSearchResponse *)response {
    ACDistrictSearch *dist = (ACDistrictSearch *)request;
    if (dist.showInMap && self.mapView) {//显示在地图上
        [self handleDistrictResponse:response];
    }
    //解析response获取行政区划，具体解析见 Demo
    NSDictionary *sendDict = [self getDistrictDict:response];
    [self sendResultEventWithCallbackId:dist.searchResultCbid dataDict:@{@"status":@(YES),@"districtResult":sendDict} errDict:nil doDelete:NO];
}

#pragma mark - MAMapViewDelegate -

#pragma mark 覆盖物类代理

//海量点点击回调
- (void)multiPointOverlayRenderer:(MAMultiPointOverlayRenderer *)renderer didItemTapped:(MAMultiPointItem *)item {
    if (multiPointCbid < 0) {
        return;
    }
    NSMutableDictionary *itemDict = [NSMutableDictionary dictionary];
    CLLocationCoordinate2D coordinate = item.coordinate;
    [itemDict setObject:@(coordinate.latitude) forKey:@"latitude"];
    [itemDict setObject:@(coordinate.longitude) forKey:@"longitude"];
    NSString *customID = item.customID;
    if (![customID isKindOfClass:[NSString class]] || customID.length==0) {
        customID = @"";
    }
    NSString *title = item.title;
    if (![title isKindOfClass:[NSString class]] || title.length==0) {
        title = @"";
    }
    NSString *subtitle = item.subtitle;
    if (![subtitle isKindOfClass:[NSString class]] || subtitle.length==0) {
        subtitle = @"";
    }
    [itemDict setObject:subtitle forKey:@"subtitle"];
    [itemDict setObject:title forKey:@"title"];
    [itemDict setObject:customID forKey:@"customID"];
    [self sendResultEventWithCallbackId:multiPointCbid dataDict:itemDict errDict:nil doDelete:NO];
}

- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id <MAOverlay>)overlay {
    if ([overlay isKindOfClass:[MATileOverlay class]]) {
        MATileOverlayRenderer *render = [[MATileOverlayRenderer alloc] initWithTileOverlay:overlay];
        return render;
    }
    if ([overlay isKindOfClass:[MAMultiPointOverlay class]]) {
        MAMultiPointOverlayRenderer *renderer = [[MAMultiPointOverlayRenderer alloc] initWithMultiPointOverlay:overlay];
        NSString *iconPath = [multiPointStyles stringValueForKey:@"icon" defaultValue:@""];
        renderer.icon = [UIImage imageWithContentsOfFile:[self getPathWithUZSchemeURL:iconPath]];
        NSDictionary *pointSize = [multiPointStyles dictValueForKey:@"pointSize" defaultValue:nil];
        if (pointSize) {
            float w = [pointSize floatValueForKey:@"w" defaultValue:10];
            float h = [pointSize floatValueForKey:@"h" defaultValue:10];
            renderer.pointSize = CGSizeMake(w, h);
        }
        NSDictionary *anchor = [multiPointStyles dictValueForKey:@"anchor" defaultValue:nil];
        if (anchor) {
            float x = [pointSize floatValueForKey:@"x" defaultValue:0.5];
            float y = [pointSize floatValueForKey:@"y" defaultValue:0.5];
            renderer.anchor = CGPointMake(x, y);
        }
        renderer.delegate = self;
        return renderer;
    }
    UZMultiPolyline *target = (UZMultiPolyline *)overlay;
    if ([target isKindOfClass:[UZMultiPolyline class]]) {
        float borderWidth = target.locusWidth;
        NSMutableArray *colors = target.colorsAry;
        
        MAMultiColoredPolylineRenderer *polylineRenderer = [[MAMultiColoredPolylineRenderer alloc] initWithMultiPolyline:overlay];
        
        polylineRenderer.lineWidth = borderWidth;
        polylineRenderer.strokeColors = colors;
        polylineRenderer.gradient = YES;
        
        return polylineRenderer;
    }
    if ([overlay isKindOfClass:[MACircle class]]) {//圆
        MACircleRenderer *circleView = [[MACircleRenderer alloc] initWithCircle:overlay];
        circleView.lineWidth  = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2];
        NSString *stroke = [overlayStyles stringValueForKey:@"borderColor" defaultValue:@"#000"];
        NSString *fill = [overlayStyles stringValueForKey:@"fillColor" defaultValue:@"rgba(1,0.8,0,0.8)"];
        circleView.strokeColor = [UZAppUtils colorFromNSString:stroke];
        circleView.fillColor = [UZAppUtils colorFromNSString:fill];
        if ([overlayStyles boolValueForKey:@"lineDash" defaultValue:NO]) {
            circleView.lineDashType = kMALineDashTypeDot;
        } else {
            circleView.lineDashType = kMALineDashTypeNone;
        }
        return circleView;
    } else if ([overlay isKindOfClass:[MAPolygon class]]) {//多边形
        MAPolygonRenderer *polygonView = [[MAPolygonRenderer alloc] initWithPolygon:overlay];
        polygonView.lineWidth = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2];
        NSString *stroke = [overlayStyles stringValueForKey:@"borderColor" defaultValue:@"#000"];
        NSString *fill = [overlayStyles stringValueForKey:@"fillColor" defaultValue:@"rgba(1,0.8,0,0.8)"];
        polygonView.strokeColor = [UZAppUtils colorFromNSString:stroke];
        polygonView.fillColor = [UZAppUtils colorFromNSString:fill];
        polygonView.lineJoinType = kMALineJoinRound;
        if ([overlayStyles boolValueForKey:@"lineDash" defaultValue:NO]) {
            polygonView.lineDashType = kMALineDashTypeDot;
        } else {
            polygonView.lineDashType = kMALineDashTypeNone;
        }
        return polygonView;
    } else if ([overlay isKindOfClass:[ACDistrictLine class]]) {
        MAPolylineRenderer *polylineView = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        NSString *strokeImage = [self.districtLineDict stringValueForKey:@"strokeImg" defaultValue:@""];
        if ([strokeImage isKindOfClass:[NSString class]] && strokeImage.length>0) {//文理图片线条
            polylineView.lineWidth = [self.districtLineDict floatValueForKey:@"borderWidth" defaultValue:2.0];
            NSString *realStrokeImgPath = [self getPathWithUZSchemeURL:strokeImage];
            polylineView.strokeImage = [UIImage imageWithContentsOfFile:realStrokeImgPath];
        } else {//线
            polylineView.lineWidth = [self.districtLineDict floatValueForKey:@"borderWidth" defaultValue:2.0];
            NSString *color = [self.districtLineDict stringValueForKey:@"borderColor" defaultValue:@"#000"];
            polylineView.strokeColor = [UZAppUtils colorFromNSString:color];
            polylineView.lineJoinType = kMALineJoinRound;
            NSString *typeStr = [self.districtLineDict stringValueForKey:@"type" defaultValue:@"round"];
            if ([typeStr isEqualToString:@"round"]) {
                polylineView.lineCapType  = kMALineCapRound;
            } else if ([typeStr isEqualToString:@"square"]) {
                polylineView.lineCapType  = kMALineCapSquare;
            } else {
                polylineView.lineCapType  = kMALineCapArrow;
            }
            if ([self.districtLineDict boolValueForKey:@"lineDash" defaultValue:NO]) {
                polylineView.lineDashType = kMALineDashTypeDot;
            } else {
                polylineView.lineDashType = kMALineDashTypeNone;
            }
        }
        return polylineView;
    } else if ([overlay isKindOfClass:[MAPolyline class]]) {//线
        MAPolylineRenderer *polylineView = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        NSString *strokeImage = [overlayStyles stringValueForKey:@"strokeImg" defaultValue:@""];
        if ([strokeImage isKindOfClass:[NSString class]] && strokeImage.length>0) {//文理图片线条
            polylineView.lineWidth = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2.0];

            NSString *realStrokeImgPath = [self getPathWithUZSchemeURL:strokeImage];
            polylineView.strokeImage = [UIImage imageWithContentsOfFile:realStrokeImgPath];
            
        }else {//线
            polylineView.lineWidth = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2.0];
            NSString *color = [overlayStyles stringValueForKey:@"borderColor" defaultValue:@"#000"];
            polylineView.strokeColor = [UZAppUtils colorFromNSString:color];
            
            polylineView.lineJoinType = kMALineJoinRound;
            NSString *typeStr = [overlayStyles stringValueForKey:@"type" defaultValue:@"round"];
            if ([typeStr isEqualToString:@"round"]) {
                polylineView.lineCapType  = kMALineCapRound;
            } else if ([typeStr isEqualToString:@"square"]) {
                polylineView.lineCapType  = kMALineCapSquare;
            } else {
                polylineView.lineCapType  = kMALineCapArrow;
            }
            if ([overlayStyles boolValueForKey:@"lineDash" defaultValue:NO]) {
                polylineView.lineDashType = kMALineDashTypeDot;
            } else {
                polylineView.lineDashType = kMALineDashTypeNone;
            }

        }
        return polylineView;
    } else if ([overlay isKindOfClass:[MAGeodesicPolyline class]]) {//弧形
        MAPolylineRenderer *polylineView = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        polylineView.lineWidth = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2.0];
        NSString *color = [overlayStyles stringValueForKey:@"borderColor" defaultValue:@"#000"];
        polylineView.strokeColor = [UZAppUtils colorFromNSString:color];
        if ([overlayStyles boolValueForKey:@"lineDash" defaultValue:NO]) {
            polylineView.lineDashType = kMALineDashTypeDot;
        } else {
            polylineView.lineDashType = kMALineDashTypeNone;
        }
        return polylineView;
    } else if ([overlay isKindOfClass:[MAGroundOverlay class]]) {//图片
        MAGroundOverlayRenderer *groundOverlayView = [[MAGroundOverlayRenderer alloc] initWithGroundOverlay:overlay];
        return groundOverlayView;
    }
    //路线规划
    if ([overlay isKindOfClass:[MANaviPolyline class]]) {
        MANaviPolyline *naviPolyline = (MANaviPolyline *)overlay;
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:naviPolyline.polyline];
        if (naviPolyline.type == MANaviAnnotationTypeWalking) {//步行路线样式
            NSDictionary *walkStyle = [routeStyles dictValueForKey:@"walkLine" defaultValue:@{}];
            polylineRenderer.lineWidth = [walkStyle floatValueForKey:@"width" defaultValue:3];
            NSString *colorStr = [walkStyle stringValueForKey:@"color" defaultValue:@"#0000ee"];
            polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
            if ([walkStyle boolValueForKey:@"lineDash" defaultValue:NO]) {
                polylineRenderer.lineDashType = kMALineDashTypeDot;
            } else {
                polylineRenderer.lineDashType = kMALineDashTypeNone;
            }
            NSString *strokeImg = [walkStyle stringValueForKey:@"strokeImg" defaultValue:nil];
            if (strokeImg.length > 0) {
                strokeImg = [self getPathWithUZSchemeURL:strokeImg];
                UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
                polylineRenderer.strokeImage = strokeImage;
            }
        } else if (naviPolyline.type == MANaviAnnotationTypeBus) {//公交路线样式
            NSDictionary *busStyle = [routeStyles dictValueForKey:@"busLine" defaultValue:@{}];
            polylineRenderer.lineWidth = [busStyle floatValueForKey:@"width" defaultValue:4];
            NSString *colorStr = [busStyle stringValueForKey:@"color" defaultValue:@"#00BFFF"];
            polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
            if ([busStyle boolValueForKey:@"lineDash" defaultValue:NO]) {
                polylineRenderer.lineDashType = kMALineDashTypeDot;
            } else {
                polylineRenderer.lineDashType = kMALineDashTypeNone;
            }
            NSString *strokeImg = [busStyle stringValueForKey:@"strokeImg" defaultValue:nil];
            if (strokeImg.length > 0) {
                strokeImg = [self getPathWithUZSchemeURL:strokeImg];
                UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
                polylineRenderer.strokeImage = strokeImage;
            }
        } else if (naviPolyline.type == MANaviAnnotationTypeDrive){//驾车路线样式
            NSDictionary *driveStyle = [routeStyles dictValueForKey:@"driveLine" defaultValue:@{}];
            polylineRenderer.lineWidth = [driveStyle floatValueForKey:@"width" defaultValue:5];
            NSString *colorStr = [driveStyle stringValueForKey:@"color" defaultValue:@"#00868B"];
            polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
            if ([driveStyle boolValueForKey:@"lineDash" defaultValue:NO]) {
                polylineRenderer.lineDashType = kMALineDashTypeDot;
            } else {
                polylineRenderer.lineDashType = kMALineDashTypeNone;
            }
            NSString *strokeImg = [driveStyle stringValueForKey:@"strokeImg" defaultValue:nil];
            if (strokeImg.length > 0) {
                strokeImg = [self getPathWithUZSchemeURL:strokeImg];
                UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
                polylineRenderer.strokeImage = strokeImage;
            }
        } else {//骑行路线样式
            NSDictionary * rideStyle = [routeStyles dictValueForKey:@"rideLine" defaultValue:@{}];
            polylineRenderer.lineWidth = [rideStyle floatValueForKey:@"width" defaultValue:3];
            NSString *colorStr = [rideStyle stringValueForKey:@"color" defaultValue:@"#698B22"];
            polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
            if ([rideStyle boolValueForKey:@"lineDash" defaultValue:NO]) {
                polylineRenderer.lineDashType = kMALineDashTypeDot;
            } else {
                polylineRenderer.lineDashType = kMALineDashTypeNone;
            }
            NSString *strokeImg = [rideStyle stringValueForKey:@"strokeImg" defaultValue:nil];
            if (strokeImg.length > 0) {
                strokeImg = [self getPathWithUZSchemeURL:strokeImg];
                UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
                polylineRenderer.strokeImage = strokeImage;
            }
        }
        return polylineRenderer;
    }
    if ([overlay isKindOfClass:[LineDashPolyline class]]) {//红绿灯时，左转弯路线断开部分
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:((LineDashPolyline *)overlay).polyline];
        NSDictionary *driveStyle = [routeStyles dictValueForKey:@"driveLine" defaultValue:@{}];
        polylineRenderer.lineWidth = [driveStyle floatValueForKey:@"width" defaultValue:5];
        NSString *colorStr = [driveStyle stringValueForKey:@"color" defaultValue:@"#00868B"];
        polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
        if ([driveStyle boolValueForKey:@"lineDash" defaultValue:NO]) {
            polylineRenderer.lineDashType = kMALineDashTypeDot;
        } else {
            polylineRenderer.lineDashType = kMALineDashTypeNone;
        }
        NSString *strokeImg = [driveStyle stringValueForKey:@"strokeImg" defaultValue:nil];
        if (strokeImg.length > 0) {
            strokeImg = [self getPathWithUZSchemeURL:strokeImg];
            UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
            polylineRenderer.strokeImage = strokeImage;
        }
        return polylineRenderer;
    }
    //公交路线规划
    if ([overlay isKindOfClass:[MABusPolyline class]]) {
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:((MABusPolyline *)overlay).polyline];
        NSDictionary *lineStyle = [busLineStyles dictValueForKey:@"line" defaultValue:@{}];
        polylineRenderer.lineWidth = [lineStyle floatValueForKey:@"width" defaultValue:4];
        NSString *colorStr = [lineStyle stringValueForKey:@"color" defaultValue:@"#00BFFF"];
        polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
        if ([lineStyle boolValueForKey:@"lineDash" defaultValue:NO]) {
            polylineRenderer.lineDashType = kMALineDashTypeDot;
        } else {
            polylineRenderer.lineDashType = kMALineDashTypeNone;
        }
        NSString *strokeImg = [lineStyle stringValueForKey:@"strokeImg" defaultValue:nil];
        if (strokeImg.length > 0) {
            strokeImg = [self getPathWithUZSchemeURL:strokeImg];
            UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
            polylineRenderer.strokeImage = strokeImage;
        }
        return polylineRenderer;
    }
    return nil;
}

#pragma mark 标注、气泡类代理
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation {
    if ([annotation isKindOfClass:[MAUserLocation class]]) {
        return nil;
    }
    ACGDAnnotaion *targetAnnot = (ACGDAnnotaion *) annotation;
    if ([targetAnnot isKindOfClass:[ACGDAnnotaion class]]) {
        static NSString *pointReuseIndetifier = @"pointReuseIndetifier";
        //标注应该开启重用机制，后期待优化
        //NSString *pointReuseIndetifier = [NSString stringWithFormat:@"%zi",targetAnnot.annotId];
        AnimatedAnnotationView *annotationView = (AnimatedAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndetifier];
        if (annotationView == nil) {
            annotationView = [[AnimatedAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndetifier];
        }
        annotationView.draggable = targetAnnot.draggable;
        //设置标注、布告牌
        [self processAnnotationView:targetAnnot withView:annotationView];
        //若已设置设置气泡则开始加载气泡
        if (targetAnnot.haveBubble) {
            [self setBubbleView:targetAnnot withView:annotationView];
        }
        return annotationView;
    }
    else if ([annotation isKindOfClass:[MAPointAnnotation class]]) {
        static NSString *routePlanningCellIdentifier = @"RoutePlanningCellIdentifier";
        MAAnnotationView *poiAnnotationView = (MAAnnotationView*)[self.mapView dequeueReusableAnnotationViewWithIdentifier:routePlanningCellIdentifier];
        if (poiAnnotationView == nil) {
            poiAnnotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation
                                                             reuseIdentifier:routePlanningCellIdentifier];
        }
        poiAnnotationView.canShowCallout = YES;
        NSDictionary *iconsInfo = [routeStyles dictValueForKey:@"icons" defaultValue:@{}];
        if ([annotation isKindOfClass:[MANaviAnnotation class]])  {
            switch (((MANaviAnnotation*)annotation).type)
            {
                default:
                case MANaviAnnotationTypeBus: {
                    NSString *path = [iconsInfo stringValueForKey:@"bus" defaultValue:nil];
                    if (path.length > 0) {
                        path = [self getPathWithUZSchemeURL:path];
                    } else {
                        path = [[NSBundle mainBundle]pathForResource:@"res_aMap/bus" ofType:@"png"];
                    }
                    UIImage *img = [UIImage imageWithContentsOfFile:path];
                    img = [self scaleImage:img];
                    poiAnnotationView.image = img;
                }
                break;
                    
                case MANaviAnnotationTypeDrive:{
                    NSString *path = [iconsInfo stringValueForKey:@"car" defaultValue:nil];
                    if (path.length > 0) {
                        path = [self getPathWithUZSchemeURL:path];
                    } else {
                        path = [[NSBundle mainBundle]pathForResource:@"res_aMap/car" ofType:@"png"];
                    }
                    UIImage *img = [UIImage imageWithContentsOfFile:path];
                    img = [self scaleImage:img];
                    poiAnnotationView.image = img;
                }
                break;
                    
                case MANaviAnnotationTypeWalking:{
                    NSString *path = [iconsInfo stringValueForKey:@"man" defaultValue:nil];
                    if (path.length > 0) {
                        path = [self getPathWithUZSchemeURL:path];
                    } else {
                        path = [[NSBundle mainBundle]pathForResource:@"res_aMap/man" ofType:@"png"];
                    }
                    UIImage *img = [UIImage imageWithContentsOfFile:path];
                    img = [self scaleImage:img];
                    poiAnnotationView.image = img;
                }
                break;
                    
                case MANaviAnnotationTypeRide:{
                    NSString *path = [iconsInfo stringValueForKey:@"ride" defaultValue:nil];
                    if (path.length > 0) {
                        path = [self getPathWithUZSchemeURL:path];
                    } else {
                        path = [[NSBundle mainBundle]pathForResource:@"res_aMap/man" ofType:@"png"];
                    }
                    UIImage *img = [UIImage imageWithContentsOfFile:path];
                    img = [self scaleImage:img];
                    poiAnnotationView.image = img;
                }
                    break;
                    
                case MANaviAnnotationTypeStart:{
                    NSString *path = [iconsInfo stringValueForKey:@"start" defaultValue:nil];
                    if (path.length > 0) {
                        path = [self getPathWithUZSchemeURL:path];
                    } else {
                        path = [[NSBundle mainBundle]pathForResource:@"res_aMap/start" ofType:@"png"];
                    }
                    UIImage *img = [UIImage imageWithContentsOfFile:path];
                    img = [self scaleImage:img];
                    poiAnnotationView.image = img;
                }
                break;
                    
                case MANaviAnnotationTypeEnd:{
                    NSString *path = [iconsInfo stringValueForKey:@"end" defaultValue:nil];
                    if (path.length > 0) {
                        path = [self getPathWithUZSchemeURL:path];
                    } else {
                        path = [[NSBundle mainBundle]pathForResource:@"res_aMap/end" ofType:@"png"];
                    }
                    UIImage *img = [UIImage imageWithContentsOfFile:path];
                    img = [self scaleImage:img];
                    poiAnnotationView.image = img;
                }
                break;
            }
        }
        return poiAnnotationView;
    }
    else if ([annotation isKindOfClass:[BusStopAnnotation class]]) {
        static NSString *busStopIdentifier = @"busStopIdentifier";
        MAPinAnnotationView *poiAnnotationView = (MAPinAnnotationView*)[self.mapView dequeueReusableAnnotationViewWithIdentifier:busStopIdentifier];
        if (poiAnnotationView == nil) {
            poiAnnotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:busStopIdentifier];
        }
        poiAnnotationView.canShowCallout = YES;
        NSDictionary *iconsInfo = [busLineStyles dictValueForKey:@"icons" defaultValue:@{}];
        switch (((BusStopAnnotation*)annotation).type)
        {
            default:
            case 0: {
                NSString *path = [iconsInfo stringValueForKey:@"bus" defaultValue:nil];
                if (path.length > 0) {
                    path = [self getPathWithUZSchemeURL:path];
                } else {
                    path = [[NSBundle mainBundle]pathForResource:@"res_aMap/bus" ofType:@"png"];
                }
                UIImage *img = [UIImage imageWithContentsOfFile:path];
                img = [self scaleImage:img];
                poiAnnotationView.image = img;
            }
                break;
                
            case 1:{
                NSString *path = [iconsInfo stringValueForKey:@"start" defaultValue:nil];
                if (path.length > 0) {
                    path = [self getPathWithUZSchemeURL:path];
                } else {
                    path = [[NSBundle mainBundle]pathForResource:@"res_aMap/start" ofType:@"png"];
                }
                UIImage *img = [UIImage imageWithContentsOfFile:path];
                img = [self scaleImage:img];
                poiAnnotationView.image = img;
            }
                break;
                
            case 2:{
                NSString *path = [iconsInfo stringValueForKey:@"end" defaultValue:nil];
                if (path.length > 0) {
                    path = [self getPathWithUZSchemeURL:path];
                } else {
                    path = [[NSBundle mainBundle]pathForResource:@"res_aMap/end" ofType:@"png"];
                }
                UIImage *img = [UIImage imageWithContentsOfFile:path];
                img = [self scaleImage:img];
                poiAnnotationView.image = img;
            }
                break;
        }
        return poiAnnotationView;
    }
    return nil;
}

- (void)processAnnotationView:(ACGDAnnotaion *)annotation withView:(AnimatedAnnotationView *)annotationView {//标注，自定义，动态标注
    switch (annotation.type) {
        default:
            //设置标注为自定义图标（动态）
        case ANNOTATION_MARKE: {
            //若当前为选中状态，且存在选中后的图标
            if (annotationView.isSelected && annotation.selPinIcons.count>0) {
                NSArray *pinIconPaths = annotation.selPinIcons;
                if (pinIconPaths.count == 1) {
                    NSString *path = [pinIconPaths firstObject];
                    UIImage *pinImage = [UIImage imageWithContentsOfFile:path];
                    pinImage = [self scaleImage:pinImage];//2倍图缩放图片
                    annotationView.animationView.hidden = YES;//动画标注隐藏
                    annotationView.image = [self imageResize:pinImage andResizeTo:CGSizeMake((annotation.w == -1)?pinImage.size.width:annotation.w, (annotation.h == -1)?pinImage.size.height:annotation.h)];
                
                } else {//动画标注
                    self.placeholdImage = [UIImage imageNamed:@"res_aMap/mobile.png"];
                    NSString *animationFirstFramePath = [pinIconPaths firstObject];
                    UIImage *firstImage = [UIImage imageWithContentsOfFile:animationFirstFramePath];
                    CGSize firstImageSize = firstImage.size;
                    float sclW = firstImageSize.width/2.0;
                    float sclH = firstImageSize.height/2.0;
                    //重设标注的image
                    [self resetAnnotationViewImage:annotationView withSize:CGSizeMake((annotation.w == -1)?sclW:annotation.w, (annotation.h == -1)?sclH:annotation.h)];
                    [annotationView refreshAnimatedPin:annotation];
                    annotationView.animationView.hidden = NO;
                }
                annotationView.centerOffset = CGPointMake(0, -annotationView.bounds.size.height/2.0);
                annotationView.billboardView.hidden = YES;//避免与布告牌错乱
                annotationView.mobileIcon.hidden = YES;//可移动标注隐藏
                annotationView.webBillboardView.hidden = YES;
                break;
            }
            NSArray *pinIconPaths = annotation.pinIcons;
            NSString *pinIconPath = nil;
            if (pinIconPaths.count == 0) {//默认大头针图标
                pinIconPath = [[NSBundle mainBundle]pathForResource:@"res_aMap/redPin" ofType:@"png"];
            } else if (pinIconPaths.count == 1) {//自定义标注图标
                pinIconPath = [pinIconPaths firstObject];
            }
            UIImage *pinImage = [UIImage imageWithContentsOfFile:pinIconPath];
            pinImage = [self scaleImage:pinImage];//2倍图缩放图片
            //避免与可移动的标注的冲突
            if (pinImage) {//普通标注
                
                annotationView.animationView.hidden = YES;//动画标注隐藏
            
                annotationView.image = [self imageResize:pinImage andResizeTo:CGSizeMake((annotation.w == -1)?pinImage.size.width:annotation.w, (annotation.h == -1)?pinImage.size.height:annotation.h)];
//                annotationView.image = pinImage;
            } else {//动画标注
                self.placeholdImage = [UIImage imageNamed:@"res_aMap/mobile.png"];
                NSString *animationFirstFramePath = [pinIconPaths firstObject];
                UIImage *firstImage = [UIImage imageWithContentsOfFile:animationFirstFramePath];
                CGSize firstImageSize = firstImage.size;
                float sclW = firstImageSize.width/2.0;
                float sclH = firstImageSize.height/2.0;
                //重设标注的image
//                [self resetAnnotationViewImage:annotationView withSize:CGSizeMake(sclW, sclH)];
                [self resetAnnotationViewImage:annotationView withSize:CGSizeMake((annotation.w == -1)?sclW:annotation.w, (annotation.h == -1)?sclH:annotation.h)];
                [annotationView refreshAnimatedPin:annotation];
                annotationView.animationView.hidden = NO;
            }
            annotationView.centerOffset = CGPointMake(0, -annotationView.bounds.size.height/2.0);
            annotationView.billboardView.hidden = YES;//避免与布告牌错乱
            annotationView.mobileIcon.hidden = YES;//可移动标注隐藏
        }
            break;
            //设置标注为布告牌
        case ANNOTATION_BILLBOARD: {
            if (annotationView.webBillboardView) {
                [self refreshBillboardView:annotation withAnnotationView:annotationView];
            } else {
                [self addBillboardView:annotation withAnnotationView:annotationView];
            }
            //避免与布告牌和可移动标注的冲突
            annotationView.billboardView.hidden = NO;
            annotationView.webBillboardView.hidden = YES;
            annotationView.animationView.hidden = YES;//动画标注隐藏
            annotationView.mobileIcon.hidden = YES;//可移动标注隐藏
            NSDictionary *stylesInfo = annotation.stylesDict;
            NSDictionary *billboardSize = [stylesInfo dictValueForKey:@"size" defaultValue:@{}];
            float sclW = [billboardSize floatValueForKey:@"width" defaultValue:160];
            float sclH = [billboardSize floatValueForKey:@"height" defaultValue:75];
            //重设标注的image
            [self resetAnnotationViewImage:annotationView withSize:CGSizeMake(sclW, sclH)];
            annotationView.centerOffset = CGPointMake(0, -annotationView.bounds.size.height/2.0);
        }
            break;
        //设置网页布告牌
        case ANNOTATION_WEBBOARD: {
            if (annotationView.billboardView) {
                [self refreshWebBillboardView:annotation withAnnotationView:annotationView];
            } else {
                [self addWebBillboardView:annotation withAnnotationView:annotationView];
            }
            //避免与布告牌和可移动标注的冲突
            annotationView.webBillboardView.hidden = NO;
            annotationView.billboardView.hidden = YES;
            annotationView.animationView.hidden = YES;//动画标注隐藏
            annotationView.mobileIcon.hidden = YES;//可移动标注隐藏
            NSDictionary *stylesInfo = annotation.stylesDict;
            NSDictionary *billboardSize = [stylesInfo dictValueForKey:@"size" defaultValue:@{}];
            float sclW = [billboardSize floatValueForKey:@"width" defaultValue:160];
            float sclH = [billboardSize floatValueForKey:@"height" defaultValue:75];
            //重设标注的image
            [self resetAnnotationViewImage:annotationView withSize:CGSizeMake(sclW, sclH)];
            annotationView.centerOffset = CGPointMake(0, -annotationView.bounds.size.height/2.0);
        }
        break;
            //设置标注为可移动对象
        case ANNOTATION_MOBILEGD: {
            self.placeholdImage = [UIImage imageNamed:@"res_aMap/mobile.png"];
            annotationView.image = self.placeholdImage;
            NSString *mobilePath = annotation.mobileBgImg;
            UIImage *mbileImage = [UIImage imageWithContentsOfFile:[self getPathWithUZSchemeURL:mobilePath]];
            CGRect mobileRect = CGRectMake(0, 0, mbileImage.size.width/2.0, mbileImage.size.height/2.0);
            if (annotationView.mobileIcon) {
                annotationView.mobileIcon.frame = mobileRect;
                annotationView.mobileIcon.image = mbileImage;
            } else {
                UIImageView *mobileIcon = [[UIImageView alloc]init];
                mobileIcon.frame = mobileRect;
                mobileIcon.image = mbileImage;
                [annotationView addSubview:mobileIcon];
                annotationView.mobileIcon = mobileIcon;
            }
            annotationView.mobileIcon.center = CGPointMake(annotationView.bounds.size.width/2.0, annotationView.bounds.size.height/2.0);
            annotationView.mobileIcon.tag = ANNOTATION_MOBILETAG;
            annotationView.centerOffset = CGPointMake(0, 0);
            annotationView.billboardView.hidden = YES;//避免与布告牌错乱
            annotationView.animationView.hidden = YES;//避免与动画标注错乱
            annotationView.webBillboardView.hidden = YES;
            annotationView.mobileIcon.hidden = NO;
        }
            break;
    }
}

//点击标注
- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view {
    ACGDAnnotaion *target = (ACGDAnnotaion *)view.annotation;
    if (![target isKindOfClass:[ACGDAnnotaion class]]) {
        return;
    }
    if ([view isSelected] && !target.haveBubble) {//若没有被设置气泡则取消标注选中状态
        //[mapView deselectAnnotation:target animated:NO];//取消标注选中状态
        //之前加的，不知道为了解决什么问题，现在注释掉会有什么问题
    }
    AnimatedAnnotationView *annotationView = (AnimatedAnnotationView *)view;
  
    //若存在选中后的图标，且annotation 为AnimatedAnnotationView
    if (target.selPinIcons.count>0 && [annotationView isKindOfClass:[AnimatedAnnotationView class]]) {
        NSArray *pinIconPaths = target.selPinIcons;
        if (pinIconPaths.count == 1) {
            NSString *path = [pinIconPaths firstObject];
            UIImage *pinImage = [UIImage imageWithContentsOfFile:path];
            pinImage = [self scaleImage:pinImage];//2倍图缩放图片
            annotationView.animationView.hidden = YES;//动画标注隐藏
            annotationView.image = [self imageResize:pinImage andResizeTo:CGSizeMake((target.w == -1)?pinImage.size.width:target.w, (target.h == -1)?pinImage.size.height:target.h)];
//            annotationView.image = pinImage;
        } else {//动画标注
            self.placeholdImage = [UIImage imageNamed:@"res_aMap/mobile.png"];
            NSString *animationFirstFramePath = [pinIconPaths firstObject];
            UIImage *firstImage = [UIImage imageWithContentsOfFile:animationFirstFramePath];
            CGSize firstImageSize = firstImage.size;
            float sclW = firstImageSize.width/2.0;
            float sclH = firstImageSize.height/2.0;
            //重设标注的image
//            [self resetAnnotationViewImage:annotationView withSize:CGSizeMake(sclW, sclH)];
            [self resetAnnotationViewImage:annotationView withSize:CGSizeMake((target.w == -1)?sclW:target.w, (target.h == -1)?sclH:target.h)];
            [annotationView refreshAnimatedPin:target];
            annotationView.animationView.hidden = NO;
        }
        annotationView.centerOffset = CGPointMake(0, -annotationView.bounds.size.height/2.0);
        annotationView.billboardView.hidden = YES;//避免与布告牌错乱
        annotationView.mobileIcon.hidden = YES;//可移动标注隐藏
    }
    
    
    
    if (target.clickCbId < 0) {//标注点击事件回调
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [sendDict setObject:[NSNumber numberWithInteger:target.annotId] forKey:@"id"];
    [sendDict setObject:@"click" forKey:@"eventType"];
    [self sendResultEventWithCallbackId:target.clickCbId dataDict:sendDict errDict:nil doDelete:NO];
}
//取消点击状态
- (void)mapView:(MAMapView *)mapView didDeselectAnnotationView:(MAAnnotationView *)view {
    ACGDAnnotaion *annotation = (ACGDAnnotaion *)view.annotation;
    if (![annotation isKindOfClass:[ACGDAnnotaion class]]) {
        return;
    }
    AnimatedAnnotationView *annotationView = (AnimatedAnnotationView *)view;
    NSArray *pinIconPaths = annotation.pinIcons;
    NSString *pinIconPath = nil;
    if (pinIconPaths.count == 0) {//默认大头针图标
        pinIconPath = [[NSBundle mainBundle]pathForResource:@"res_aMap/redPin" ofType:@"png"];
    } else if (pinIconPaths.count == 1) {//自定义标注图标
        pinIconPath = [pinIconPaths firstObject];
    }
    UIImage *pinImage = [UIImage imageWithContentsOfFile:pinIconPath];
    pinImage = [self scaleImage:pinImage];//2倍图缩放图片
    //避免与可移动的标注的冲突
    if (pinImage) {//普通标注
        annotationView.animationView.hidden = YES;//动画标注隐藏
//        annotationView.image = pinImage;
        annotationView.image = [self imageResize:pinImage andResizeTo:CGSizeMake((annotation.w == -1)?pinImage.size.width:annotation.w, (annotation.h == -1)?pinImage.size.height:annotation.h)];
    } else {//动画标注
        self.placeholdImage = [UIImage imageNamed:@"res_aMap/mobile.png"];
        NSString *animationFirstFramePath = [pinIconPaths firstObject];
        UIImage *firstImage = [UIImage imageWithContentsOfFile:animationFirstFramePath];
        CGSize firstImageSize = firstImage.size;
        float sclW = firstImageSize.width/2.0;
        float sclH = firstImageSize.height/2.0;
        //重设标注的image
//        [self resetAnnotationViewImage:annotationView withSize:CGSizeMake(sclW, sclH)];
        [self resetAnnotationViewImage:annotationView withSize:CGSizeMake((annotation.w == -1)?sclW:annotation.w, (annotation.h == -1)?sclH:annotation.h)];
        [annotationView refreshAnimatedPin:annotation];
        annotationView.animationView.hidden = NO;
    }
    annotationView.centerOffset = CGPointMake(0, -annotationView.bounds.size.height/2.0);
    annotationView.billboardView.hidden = YES;//避免与布告牌错乱
    annotationView.mobileIcon.hidden = YES;//可移动标注隐藏
    
    
}
- (void)mapView:(MAMapView *)mapView annotationView:(MAAnnotationView *)view didChangeDragState:(MAAnnotationViewDragState)newState fromOldState:(MAAnnotationViewDragState)oldState {
    NSString *state = @"none";
    switch (newState) {
        case MAAnnotationViewDragStateNone:
            state = @"none";
            break;
            
        case MAAnnotationViewDragStateStarting:
            state = @"starting";
            break;
            
        case MAAnnotationViewDragStateDragging:
            state = @"dragging";
            break;
            
        case MAAnnotationViewDragStateCanceling:
            state = @"canceling";
            break;
            
        case MAAnnotationViewDragStateEnding:
            state = @"ending";
            break;
            
        default:
            state = @"none";
            break;
    }
    ACGDAnnotaion *target = (ACGDAnnotaion *)view.annotation;
    if (![target isKindOfClass:[ACGDAnnotaion class]]) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [sendDict setObject:[NSNumber numberWithInteger:target.annotId] forKey:@"id"];
    NSInteger sendId ;
    switch (target.type) {
        default:
        case ANNOTATION_MARKE:
        {
            ACGDAnnotaion *target = (ACGDAnnotaion *)view.annotation;
            if (![target isKindOfClass:[ACGDAnnotaion class]]) {
                sendId = -1;
            }
            sendId = target.clickCbId;
            [sendDict setObject:@"drag" forKey:@"eventType"];
        }
            break;
            
        case ANNOTATION_BILLBOARD:
            sendId = target.addBillboardCbid;
            [sendDict setObject:@"drag" forKey:@"eventType"];
            break;
            
        case ANNOTATION_MOBILEGD:
            sendId = target.moveAnnoCbid;
            break;
    }
    [sendDict setObject:state forKeyedSubscript:@"dragState"];
    [self sendResultEventWithCallbackId:sendId dataDict:sendDict errDict:nil doDelete:NO];
}
#pragma mark 可移动的标注代理
- (void)didMovingAnimationFinished:(ACGDAnnotaion *)anno {
    anno.delegate = nil;
    anno.timeOffset = 0;
    NSString *moveId= [NSString stringWithFormat:@"%d",(int)anno.annotId];
    [_allMovingAnno removeObjectForKey:moveId];
    [self sendResultEventWithCallbackId:anno.moveAnnoEndCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:anno.annotId] forKey:@"id"] errDict:nil doDelete:NO];
}

#pragma mark 基础类代理

/**
 *  地图缩放结束后调用此接口
 *
 *  @param mapView       地图view
 *  @param wasUserAction 标识是否是用户动作
 */
- (void)mapView:(MAMapView *)mapView mapDidZoomByUser:(BOOL)wasUserAction {
    if (zoomLisCbid < 0) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:3];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.centerCoordinate.latitude] forKey:@"lat"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.centerCoordinate.longitude] forKey:@"lon"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.zoomLevel] forKey:@"zoom"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.rotationDegree] forKey:@"rotate"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.cameraDegree] forKey:@"overlook"];
    [self sendResultEventWithCallbackId:zoomLisCbid dataDict:sendDict errDict:nil doDelete:NO];
}

- (void)mapView:(MAMapView *)mapView didLongPressedAtCoordinate:(CLLocationCoordinate2D)coordinate {
    if (longPressCbid < 0) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:3];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    [sendDict setObject:[NSNumber numberWithFloat:coordinate.latitude] forKey:@"lat"];
    [sendDict setObject:[NSNumber numberWithFloat:coordinate.longitude] forKey:@"lon"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.zoomLevel] forKey:@"zoom"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.rotationDegree] forKey:@"rotate"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.cameraDegree] forKey:@"overlook"];
    [self sendResultEventWithCallbackId:longPressCbid dataDict:sendDict errDict:nil doDelete:NO];
}

- (void)mapView:(MAMapView *)mapView didSingleTappedAtCoordinate:(CLLocationCoordinate2D)coordinate {
    if (singleTapCbid < 0) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:3];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    [sendDict setObject:[NSNumber numberWithFloat:coordinate.latitude] forKey:@"lat"];
    [sendDict setObject:[NSNumber numberWithFloat:coordinate.longitude] forKey:@"lon"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.zoomLevel] forKey:@"zoom"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.rotationDegree] forKey:@"rotate"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.cameraDegree] forKey:@"overlook"];
    [self sendResultEventWithCallbackId:singleTapCbid dataDict:sendDict errDict:nil doDelete:NO];
}

- (void)mapView:(MAMapView *)mapView didChangeUserTrackingMode:(MAUserTrackingMode)mode animated:(BOOL)animated {
    if (trackingModeCbid < 0) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:3];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.centerCoordinate.latitude] forKey:@"lat"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.centerCoordinate.longitude] forKey:@"lon"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.zoomLevel] forKey:@"zoom"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.rotationDegree] forKey:@"rotate"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.cameraDegree] forKey:@"overlook"];
    switch (mode) {
        case 0:
            [sendDict setObject:@"none" forKey:@"trackingMode"];
            break;
            
        case 1:
            [sendDict setObject:@"follow" forKey:@"trackingMode"];
            break;
            
        case 2:
            [sendDict setObject:@"heading" forKey:@"trackingMode"];
            break;
            
        default:
            [sendDict setObject:@"none" forKey:@"trackingMode"];
            break;
    }
    [self sendResultEventWithCallbackId:trackingModeCbid dataDict:sendDict errDict:nil doDelete:NO];
}
- (void)mapView:(MAMapView *)mapView regionWillChangeAnimated:(BOOL)animated {

}

/**
 *  地图将要发生移动时调用此接口
 *
 *  @param mapView       地图view
 *  @param wasUserAction 标识是否是用户动作
 */
- (void)mapView:(MAMapView *)mapView mapWillMoveByUser:(BOOL)wasUserAction {

}

/**
 *  地图移动结束后调用此接口
 *
 *  @param mapView       地图view
 *  @param wasUserAction 标识是否是用户动作
 */
- (void)mapView:(MAMapView *)mapView mapDidMoveByUser:(BOOL)wasUserAction {
    if (viewChangeCbid < 0) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:3];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.centerCoordinate.latitude] forKey:@"lat"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.centerCoordinate.longitude] forKey:@"lon"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.zoomLevel] forKey:@"zoom"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.rotationDegree] forKey:@"rotate"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.cameraDegree] forKey:@"overlook"];
    [self sendResultEventWithCallbackId:viewChangeCbid dataDict:sendDict errDict:nil doDelete:NO];
}
- (void)mapView:(MAMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    /*
    if (viewChangeCbid < 0) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:3];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.centerCoordinate.latitude] forKey:@"lat"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.centerCoordinate.longitude] forKey:@"lon"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.zoomLevel] forKey:@"zoom"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.rotationDegree] forKey:@"rotate"];
    [sendDict setObject:[NSNumber numberWithFloat:mapView.cameraDegree] forKey:@"overlook"];
    [self sendResultEventWithCallbackId:viewChangeCbid dataDict:sendDict errDict:nil doDelete:NO];
     */
}

- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation {
    if (firstShowLocation) {
        self.mapView.centerCoordinate = self.mapView.userLocation.location.coordinate;
        firstShowLocation = NO;
    }
    if (!updatingLocation) {
        return;
    }
    currentUserLocation = userLocation;
    if (getLocationCbid < 0) {
        return;
    }
    if (getLocationAutostop) {
        [self locationCallback];
        getLocationCbid = -1;
    }
    if (!getLocationAutostop) {
        [self locationCallback];
    }
}

- (void)locationCallback {
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionary];
    [sendDict setObject:[NSNumber numberWithFloat:currentUserLocation.location.coordinate.latitude] forKey:@"lat"];
    [sendDict setObject:[NSNumber numberWithFloat:currentUserLocation.location.coordinate.longitude] forKey:@"lon"];
    [sendDict setObject:[NSNumber numberWithFloat:currentUserLocation.heading.trueHeading] forKey:@"heading"];
    double acur = currentUserLocation.location.horizontalAccuracy;
    [sendDict setObject:@(acur) forKey:@"accuracy"];
    double altitud = currentUserLocation.location.altitude;
    [sendDict setObject:@(altitud) forKey:@"altitude"];
    long long timestamp = (long long)([currentUserLocation.location.timestamp timeIntervalSince1970] * 1000);
    [sendDict setObject:[NSNumber numberWithLongLong:timestamp] forKey:@"timestamp"];
    [sendDict setObject:[NSNumber numberWithBool:YES] forKey:@"status"];
    
    //lgg
    [sendDict setObject:@(currentUserLocation.location.verticalAccuracy) forKey:@"verticalAccuracy"];
    [sendDict setObject:@(currentUserLocation.location.horizontalAccuracy) forKey:@"horizontalAccuracy"];
    [sendDict setObject:@(currentUserLocation.location.course) forKey:@"course"];
    [sendDict setObject:@(currentUserLocation.location.speed) forKey:@"speed"];
    if (currentUserLocation.location.floor) {
        [sendDict setObject:@(currentUserLocation.location.floor.level) forKey:@"floor"];
    }
    
    [self sendResultEventWithCallbackId:getLocationCbid dataDict:sendDict errDict:nil doDelete:NO];
}

- (void)mapView:(MAMapView *)mapView didFailToLocateUserWithError:(NSError *)error {
    currentUserLocation = nil;
}

#pragma mark - utility -

- (ACBubbleView *)allocBubbleView:(ACGDAnnotaion *)annotaion {//创建气泡视图
    NSDictionary *contentInfo = [NSDictionary dictionaryWithDictionary:annotaion.contentDict];
    NSDictionary *stylesInfo = annotaion.stylesDict;
    //样式参数读取
    NSString *aligment = [stylesInfo stringValueForKey:@"illusAlign" defaultValue:@"left"];
    NSString *titleColor = [stylesInfo stringValueForKey:@"titleColor" defaultValue:@"#000"];
    NSString *subTitleColor = [stylesInfo stringValueForKey:@"subTitleColor" defaultValue:@"#000"];
    float titleSize = [stylesInfo floatValueForKey:@"titleSize" defaultValue:16];
    float subtitleSize = [stylesInfo floatValueForKey:@"subTitleSize" defaultValue:12];
    //内容参数读取
    NSString *illusPath = [contentInfo stringValueForKey:@"illus" defaultValue:nil];
    NSString *title = [contentInfo stringValueForKey:@"title" defaultValue:@""];
    NSString *subTitle = [contentInfo stringValueForKey:@"subTitle" defaultValue:@""];
    float bubbleLong = 160;
    NSString *bgImgPathStr = annotaion.bubbleBgImg;
    if (bgImgPathStr.length == 0) {//若使用默认气泡背景，则根据内容文字大小自适应，最小160
        CGSize feelSize = [title sizeWithFont:[UIFont systemFontOfSize:titleSize] constrainedToSize:CGSizeMake(400,100)];
        bubbleLong = feelSize.width;
        if (bubbleLong > _mapView.bounds.size.width-64) {
            bubbleLong = _mapView.bounds.size.width - 64;
        }
        if (bubbleLong < 160) {
            bubbleLong = 160;
        }
    }
    //背景图片
    UIImageView *popView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, bubbleLong, 90)];
    popView.tag = BUBBLEVIEW_PAOVIEW;
    UIImage *imageBg = nil;
    if (bgImgPathStr.length > 0) {
        imageBg = [UIImage imageWithContentsOfFile:bgImgPathStr];
    } else {//默认气泡背景
        //右边气泡
        NSString *leftBubble = [[NSBundle mainBundle]pathForResource:@"res_aMap/bubble_left" ofType:@"png"];
        UIImage *leftImage = [UIImage imageWithContentsOfFile:leftBubble];
        UIEdgeInsets inset1 = UIEdgeInsetsMake(10, 10, 16, 16);
        leftImage = [leftImage resizableImageWithCapInsets:inset1 resizingMode:UIImageResizingModeStretch];
        UIImageView *leftImg = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, bubbleLong/2.0, 90)];
        leftImg.image = leftImage;
        leftImg.tag = BUBBLEVIEW_LEFTPAO;
        [popView addSubview:leftImg];
        //右边气泡
        NSString *rightBubble = [[NSBundle mainBundle]pathForResource:@"res_aMap/bubble_right" ofType:@"png"];
        UIImage *rightImage = [UIImage imageWithContentsOfFile:rightBubble];
        UIEdgeInsets inset2 = UIEdgeInsetsMake(10, 16, 16, 10);
        rightImage = [rightImage resizableImageWithCapInsets:inset2 resizingMode:UIImageResizingModeStretch];
        UIImageView *rightImg = [[UIImageView alloc]initWithFrame:CGRectMake(bubbleLong/2.0, 0, bubbleLong/2.0, 90)];
        rightImg.image = rightImage;
        rightImg.tag = BUBBLEVIEW_RIGHTPAO;
        [popView addSubview:rightImg];
    }
    popView.image = imageBg;
    popView.userInteractionEnabled = YES;
    //位置参数
    float labelW, labelH, labelX ,labelY;
    labelY = 18;
    labelH = 20;
    labelW = bubbleLong - 55;
    //插图
    if (illusPath.length > 0) {
        CGRect rect;
        if ([illusPath hasPrefix:@"http"]) {
            UIImageView *asyImg = [[UIImageView alloc]init];
            NSURL *urlpath = [NSURL URLWithString:illusPath];
            [asyImg sd_setImageWithURL:urlpath];
            if (aligment.length>0 && [aligment isEqualToString:@"right"]) {
                rect = CGRectMake(bubbleLong-40, labelY, 30, 40);
                labelX = 10;
            } else {
                rect = CGRectMake(10, labelY, 30, 40);
                labelX = 45;
            }
            asyImg.frame = rect;
            asyImg.userInteractionEnabled = YES;
            asyImg.tag = BUBBLEVIEW_ILLUSAS;
            [popView addSubview:asyImg];
            //添加插图单击事件
            ACAMButton *tap = [ACAMButton buttonWithType:UIButtonTypeCustom];
            tap.frame = asyImg.bounds;
            tap.btnId = annotaion.annotId;
            tap.bubbleCbid = annotaion.bubbleClickCbid;
            [tap addTarget:self action:@selector(selectBubbleIllus:) forControlEvents:UIControlEventTouchDown];
            tap.tag = BUBBLEVIEW_ILLUSASBTN;
            [asyImg addSubview:tap];
        } else {
            NSString *realIllusPath = [self getPathWithUZSchemeURL:illusPath];
            UIImageView *illusImg = [[UIImageView alloc]init];
            illusImg.image = [UIImage imageWithContentsOfFile:realIllusPath];
            if (aligment.length>0 && [aligment isEqualToString:@"right"]) {
                rect = CGRectMake(bubbleLong-40, labelY, 30, 40);
                labelX = 10;
            } else {
                rect = CGRectMake(10, labelY, 30, 40);
                labelX = 45;
            }
            illusImg.frame = rect;
            illusImg.userInteractionEnabled = YES;
            illusImg.tag = BUBBLEVIEW_ILLUSIM;
            [popView addSubview:illusImg];
            //添加插图单击事件
            ACAMButton *tap = [ACAMButton buttonWithType:UIButtonTypeCustom];
            tap.frame = illusImg.bounds;
            tap.btnId = annotaion.annotId;
            tap.bubbleCbid = annotaion.bubbleClickCbid;
            [tap addTarget:self action:@selector(selectBubbleIllus:) forControlEvents:UIControlEventTouchDown];
            tap.tag = BUBBLEVIEW_ILLUSIMBTN;
            [illusImg addSubview:tap];
        }
        //添加气泡单击事件
        ACAMButton *tapContent = [ACAMButton buttonWithType:UIButtonTypeCustom];
        CGRect tapRect = CGRectMake(labelX, 10, 140, 60);
        tapContent.frame = tapRect;
        tapContent.btnId = annotaion.annotId;
        tapContent.bubbleCbid = annotaion.bubbleClickCbid;
        [tapContent addTarget:self action:@selector(selectBubble:) forControlEvents:UIControlEventTouchDown];
        tapContent.tag = BUBBLEVIEW_CONTENTCK;
        [popView addSubview:tapContent];
    } else {
        labelX = 10;
        labelW = bubbleLong - 20;
        //添加气泡单击事件
        ACAMButton *tap = [ACAMButton buttonWithType:UIButtonTypeCustom];
        tap.frame = popView.bounds;
        tap.btnId = annotaion.annotId;
        tap.bubbleCbid = annotaion.bubbleClickCbid;
        [tap addTarget:self action:@selector(selectBubble:) forControlEvents:UIControlEventTouchDown];
        tap.tag = BUBBLEVIEW_CONTENTCK;
        [popView addSubview:tap];
    }
    //标题
    UILabel *titleLab = [[UILabel alloc]initWithFrame:CGRectMake(labelX, labelY, labelW, labelH)];
    titleLab.text = title;
    titleLab.backgroundColor = [UIColor clearColor];
    titleLab.font = [UIFont systemFontOfSize:titleSize];
    titleLab.textColor = [UZAppUtils colorFromNSString:titleColor];
    titleLab.tag = BUBBLEVIEW_TITLE;
    [popView addSubview:titleLab];
    //子标题
    UILabel *subTitleLab = [[UILabel alloc]initWithFrame:CGRectMake(labelX, labelY+labelH+5, labelW, labelH)];
    subTitleLab.text = subTitle;
    subTitleLab.backgroundColor = [UIColor clearColor];
    subTitleLab.font = [UIFont systemFontOfSize:subtitleSize];
    subTitleLab.textColor = [UZAppUtils colorFromNSString:subTitleColor];
    subTitleLab.tag = BUBBLEVIEW_SUBTITLE;
    [popView addSubview:subTitleLab];
    ACBubbleView *bubble = [[ACBubbleView alloc]initWithFrame:popView.bounds];
    [bubble addSubview:popView];
    if (illusPath.length == 0) {
        titleLab.textAlignment = NSTextAlignmentCenter;
        subTitleLab.textAlignment = NSTextAlignmentCenter;
    }
    return bubble;
}

- (void)refreshBubbleView:(ACGDAnnotaion *)annotaion withBubble:(ACBubbleView *)bubbleView {//刷新气泡视图
    NSDictionary *contentInfo = [NSDictionary dictionaryWithDictionary:annotaion.contentDict];
    NSDictionary *stylesInfo = annotaion.stylesDict;
    //样式参数读取
    NSString *aligment = [stylesInfo stringValueForKey:@"illusAlign" defaultValue:@"left"];
    NSString *titleColor = [stylesInfo stringValueForKey:@"titleColor" defaultValue:@"#000"];
    NSString *subTitleColor = [stylesInfo stringValueForKey:@"subTitleColor" defaultValue:@"#000"];
    float titleSize = [stylesInfo floatValueForKey:@"titleSize" defaultValue:16];
    float subtitleSize = [stylesInfo floatValueForKey:@"subTitleSize" defaultValue:12];
    //内容参数读取
    NSString *illusPath = [contentInfo stringValueForKey:@"illus" defaultValue:nil];
    NSString *title = [contentInfo stringValueForKey:@"title" defaultValue:@""];
    NSString *subTitle = [contentInfo stringValueForKey:@"subTitle" defaultValue:@""];
    float bubbleLong = 160;
    NSString *bgImgPathStr = annotaion.bubbleBgImg;
    if (bgImgPathStr.length == 0) {
        CGSize feelSize = [title sizeWithFont:[UIFont systemFontOfSize:titleSize] constrainedToSize:CGSizeMake(400,100)];
        bubbleLong = feelSize.width;
        if (bubbleLong > _mapView.bounds.size.width-64) {
            bubbleLong = _mapView.bounds.size.width - 64;
        }
        if (bubbleLong < 160) {
            bubbleLong = 160;
        }
    }
    //背景图片
    UIImageView *popView = (UIImageView *)[bubbleView viewWithTag:BUBBLEVIEW_PAOVIEW];
    CGRect popRect = CGRectMake(0, 0, bubbleLong, 90);
    popView.frame = popRect;
    UIImage *imageBg = nil;
    if (bgImgPathStr.length > 0) {
        imageBg = [UIImage imageWithContentsOfFile:bgImgPathStr];
    } else {
        //右边气泡
        NSString *leftBubble = [[NSBundle mainBundle]pathForResource:@"res_aMap/bubble_left" ofType:@"png"];
        UIImage *leftImage = [UIImage imageWithContentsOfFile:leftBubble];
        UIEdgeInsets inset1 = UIEdgeInsetsMake(10, 10, 16, 16);
        leftImage = [leftImage resizableImageWithCapInsets:inset1 resizingMode:UIImageResizingModeStretch];
        UIImageView *leftImg = [popView viewWithTag:BUBBLEVIEW_LEFTPAO];
        CGRect leftRect = CGRectMake(0, 0, bubbleLong/2.0, 90);
        leftImg.frame = leftRect;
        leftImg.image = leftImage;
        //右边气泡
        NSString *rightBubble = [[NSBundle mainBundle]pathForResource:@"res_aMap/bubble_right" ofType:@"png"];
        UIImage *rightImage = [UIImage imageWithContentsOfFile:rightBubble];
        UIEdgeInsets inset2 = UIEdgeInsetsMake(10, 16, 16, 10);
        rightImage = [rightImage resizableImageWithCapInsets:inset2 resizingMode:UIImageResizingModeStretch];
        UIImageView *rightImg = [popView viewWithTag:BUBBLEVIEW_RIGHTPAO];
        CGRect rightRect = CGRectMake(bubbleLong/2.0, 0, bubbleLong/2.0, 90);
        rightImg.frame = rightRect;
        rightImg.image = rightImage;
    }
    popView.image = imageBg;
    //位置参数
    float labelW, labelH, labelX ,labelY;
    labelY = 18;
    labelH = 20;
    labelW = bubbleLong - 55;
    //插图
    if (illusPath.length > 0) {
        CGRect rect;
        if ([illusPath hasPrefix:@"http"]) {
            UIImageView *asyImg = [popView viewWithTag:BUBBLEVIEW_ILLUSAS];
            NSURL *urlpath = [NSURL URLWithString:illusPath];
            [asyImg sd_setImageWithURL:urlpath];
            if (aligment.length>0 && [aligment isEqualToString:@"right"]) {
                rect = CGRectMake(bubbleLong-40, labelY, 30, 40);
                labelX = 10;
            } else {
                rect = CGRectMake(10, labelY, 30, 40);
                labelX = 45;
            }
            asyImg.frame = rect;
            //添加单击事件
            ACAMButton *tap = [asyImg viewWithTag:BUBBLEVIEW_ILLUSASBTN];
            tap.frame = asyImg.bounds;
            tap.btnId = annotaion.annotId;
            tap.bubbleCbid = annotaion.bubbleClickCbid;
            [tap addTarget:self action:@selector(selectBubbleIllus:) forControlEvents:UIControlEventTouchDown];
        } else {
            NSString *realIllusPath = [self getPathWithUZSchemeURL:illusPath];
            UIImageView *illusImg = [popView viewWithTag:BUBBLEVIEW_ILLUSIM];
            illusImg.image = [UIImage imageWithContentsOfFile:realIllusPath];
            if (aligment.length>0 && [aligment isEqualToString:@"right"]) {
                rect = CGRectMake(bubbleLong-40, labelY, 30, 40);
                labelX = 10;
            } else {
                rect = CGRectMake(10, labelY, 30, 40);
                labelX = 45;
            }
            illusImg.frame = rect;
            //添加单击事件
            ACAMButton *tap = [illusImg viewWithTag:BUBBLEVIEW_ILLUSIMBTN];
            tap.frame = illusImg.bounds;
            tap.btnId = annotaion.annotId;
            tap.bubbleCbid = annotaion.bubbleClickCbid;
            [tap addTarget:self action:@selector(selectBubbleIllus:) forControlEvents:UIControlEventTouchDown];
        }
        //添加气泡单击事件
        ACAMButton *tapContent = [popView viewWithTag:BUBBLEVIEW_CONTENTCK];
        CGRect tapRect = CGRectMake(labelX, 10, 140, 60);
        tapContent.frame = tapRect;
        tapContent.btnId = annotaion.annotId;
        tapContent.bubbleCbid = annotaion.bubbleClickCbid;
        [tapContent addTarget:self action:@selector(selectBubble:) forControlEvents:UIControlEventTouchDown];
    } else {
        labelX = 10;
        labelW = bubbleLong - 20;
        //添加气泡单击事件
        ACAMButton *tap = [popView viewWithTag:BUBBLEVIEW_CONTENTCK];
        tap.frame = popView.bounds;
        tap.btnId = annotaion.annotId;
        tap.bubbleCbid = annotaion.bubbleClickCbid;
        [tap addTarget:self action:@selector(selectBubble:) forControlEvents:UIControlEventTouchDown];
    }
    //标题
    UILabel *titleLab = [popView viewWithTag:BUBBLEVIEW_TITLE];
    CGRect titleRect = CGRectMake(labelX, labelY, labelW, labelH);
    titleLab.frame = titleRect;
    titleLab.text = title;
    titleLab.backgroundColor = [UIColor clearColor];
    titleLab.font = [UIFont systemFontOfSize:titleSize];
    titleLab.textColor = [UZAppUtils colorFromNSString:titleColor];
    //子标题
    UILabel *subTitleLab = [popView viewWithTag:BUBBLEVIEW_SUBTITLE];
    CGRect subTitleRect = CGRectMake(labelX, labelY+labelH+5, labelW, labelH);
    subTitleLab.frame = subTitleRect;
    subTitleLab.text = subTitle;
    subTitleLab.backgroundColor = [UIColor clearColor];
    subTitleLab.font = [UIFont systemFontOfSize:subtitleSize];
    subTitleLab.textColor = [UZAppUtils colorFromNSString:subTitleColor];
    if (illusPath.length == 0) {
        titleLab.textAlignment = NSTextAlignmentCenter;
        subTitleLab.textAlignment = NSTextAlignmentCenter;
    }
}

- (void)refreshWebBubbleView:(NSDictionary *)paramsDict_ withBubbleView:(ACBubbleView *)reBubbleView {
    NSString *bubbleWebUrl = [paramsDict_ stringValueForKey:@"url" defaultValue:@""];
    NSString *bubbleWebData = [paramsDict_ stringValueForKey:@"data" defaultValue:@""];
    NSDictionary *sizeDict = [paramsDict_ dictValueForKey:@"size" defaultValue:@{}];
    float bubbleW = [sizeDict floatValueForKey:@"width" defaultValue:50];
    float bubbleH = [sizeDict floatValueForKey:@"height" defaultValue:50];
    //NSInteger setWebBubbleCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSString *bubbleBg = [paramsDict_ stringValueForKey:@"bg" defaultValue:nil];
    reBubbleView.frame = CGRectMake(0, 0, bubbleW, bubbleH);
    if ([UZAppUtils isValidColor:bubbleBg]) {
        reBubbleView.backgroundColor = [UZAppUtils colorFromNSString:bubbleBg];
    } else {
        reBubbleView.backgroundColor = [UIColor clearColor];
    }
    //添加背景图片，若不存在则无
    NSString *realImgPath = [self getPathWithUZSchemeURL:bubbleBg];
    UIImage *bubbleImage = [UIImage imageWithContentsOfFile:realImgPath];
    if (bubbleImage) {
        reBubbleView.bubblleBgImgView.image = bubbleImage;
        reBubbleView.bubblleBgImgView.frame = reBubbleView.bounds;
        reBubbleView.bubblleBgImgView.hidden = NO;
    } else {
        reBubbleView.bubblleBgImgView.hidden = YES;
    }
    UIWebView *webView = reBubbleView.webBubbleView;
    webView.frame = reBubbleView.bounds;
    NSURL *url = nil;
    if ([bubbleWebUrl hasPrefix:@"http"]) {
        url = [NSURL URLWithString:bubbleWebUrl];//创建URL
    } else {
        bubbleWebUrl = [self getPathWithUZSchemeURL:bubbleWebUrl];
        url = [NSURL fileURLWithPath:bubbleWebUrl];//创建URL
    }
    if (bubbleWebData.length <=0 ) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url];//创建NSURLRequest
        [webView loadRequest:request];//加载
    }else {
        [webView loadHTMLString:bubbleWebData baseURL:nil];
    }
}

- (void)setBubbleView:(ACGDAnnotaion *)annotation withView:(AnimatedAnnotationView *)annotationView {//自定义气泡
    ACBubbleView *popBubbleView = annotationView.bubbleView;
    NSDictionary *paramsDict_ = annotation.webBubbleDict;
    if (!popBubbleView) {//没有bubbleView则创建
        popBubbleView = [[ACBubbleView alloc]init];
    }
    if (paramsDict_) {//网页气泡
        popBubbleView.normalBgImgView.hidden = YES;//隐藏普通气泡上的背景
        //网页气泡的背景图片
        if (!popBubbleView.bubblleBgImgView) {
            UIImageView *bubblleBgImgView = [[UIImageView alloc]init];
            [popBubbleView addSubview:bubblleBgImgView];
            popBubbleView.bubblleBgImgView = bubblleBgImgView;
        } else {
            popBubbleView.bubblleBgImgView.hidden = NO;
        }
        //气泡上的网页
        if (!popBubbleView.webBubbleView) {
            UIWebView *webView = [[UIWebView alloc]init];
            webView.scalesPageToFit = NO;//自动对页面进行缩放以适应屏幕
            webView.scrollView.bounces = NO;
            [webView setBackgroundColor:[UIColor clearColor]];
            [webView setOpaque:NO];
            [popBubbleView addSubview:webView];//加载内容
            popBubbleView.webBubbleView = webView;
            
            UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(handleSingleTap:)];
            tapGesture.delegate = self;
            tapGesture.cancelsTouchesInView = NO;
            [webView addGestureRecognizer:tapGesture];
        } else {
            popBubbleView.webBubbleView.hidden = NO;
        }
        //刷新网页气泡内容
        [self refreshWebBubbleView:paramsDict_ withBubbleView:popBubbleView];
        popBubbleView.webBubbleView.tag = annotation.annotId;
    } else {//普通气泡
        popBubbleView.webBubbleView.hidden = YES;//隐藏气泡上的网页
        popBubbleView.bubblleBgImgView.hidden = YES;//隐藏气泡上的背景
        
        //背景图片
        NormalBubbleBgImgView *norBubbleView = popBubbleView.normalBgImgView;
        if (!norBubbleView) {
            NormalBubbleBgImgView *normalBubbleView = [[NormalBubbleBgImgView alloc]init];
            popBubbleView.normalBgImgView = normalBubbleView;
            [popBubbleView addSubview:normalBubbleView];
            //打开背景图片试图的用户交互
            normalBubbleView.userInteractionEnabled = YES;
            //背景气泡拆分成左右两部分
            UIImageView *leftImg = [[UIImageView alloc]init];
            [normalBubbleView addSubview:leftImg];
            normalBubbleView.leftBgImgView = leftImg;
            UIImageView *rightImg = [[UIImageView alloc]init];
            [normalBubbleView addSubview:rightImg];
            normalBubbleView.rightBgImgView = rightImg;
            //添加网络插图
            UIImageView *asyImg = [[UIImageView alloc]init];
            asyImg.userInteractionEnabled = YES;
            [normalBubbleView addSubview:asyImg];
            normalBubbleView.illusImgNetwork = asyImg;
            //添加本地插图
            UIImageView *locImg = [[UIImageView alloc]init];
            locImg.userInteractionEnabled = YES;
            [normalBubbleView addSubview:locImg];
            normalBubbleView.illusImgLocal = locImg;
            //添加网络插图单击事件
            ACAMButton *tap = [ACAMButton buttonWithType:UIButtonTypeCustom];
            [tap addTarget:self action:@selector(selectBubbleIllus:) forControlEvents:UIControlEventTouchDown];
            [asyImg addSubview:tap];
            normalBubbleView.illusNetTap = tap;
            //添加本地插图单击事件
            ACAMButton *loctap = [ACAMButton buttonWithType:UIButtonTypeCustom];
            [loctap addTarget:self action:@selector(selectBubbleIllus:) forControlEvents:UIControlEventTouchDown];
            [locImg addSubview:loctap];
            normalBubbleView.illusLocTap = loctap;
            //添加标题
            UILabel *titleLab = [[UILabel alloc]init];
            titleLab.backgroundColor = [UIColor clearColor];
            [normalBubbleView addSubview:titleLab];
            normalBubbleView.titleLab = titleLab;
            //添加子标题
            UILabel *subtitleLab = [[UILabel alloc]init];
            subtitleLab.backgroundColor = [UIColor clearColor];
            [normalBubbleView addSubview:subtitleLab];
            normalBubbleView.subtitleLab = subtitleLab;
            //添加气泡单击事件
            ACAMButton *bubtap = [ACAMButton buttonWithType:UIButtonTypeCustom];
            [bubtap addTarget:self action:@selector(selectBubble:) forControlEvents:UIControlEventTouchDown];
            tap.tag = BUBBLEVIEW_CONTENTCK;
            [normalBubbleView addSubview:bubtap];
            normalBubbleView.bubbleTap = bubtap;
        } else {
            popBubbleView.normalBgImgView.hidden = NO;//显示背景
        }
        //刷新气泡
        [self refreshBubbleView:annotation withBubbleView:popBubbleView];
//        if (annotationView.bubbleView) {//若已经存在气泡则刷新气泡
//            [self refreshBubbleView:annotation withBubble:annotationView.bubbleView];
//        } else {//若不存在气泡则创建气泡
//            ACBubbleView *bubble = [self allocBubbleView:annotation];
//            annotationView.bubbleView = bubble;
//        }
    }
    annotationView.bubbleView = popBubbleView;
    popBubbleView.hidden = YES;
    annotationView.canShowCallout = NO;
}
- (void)refreshBubbleView:(ACGDAnnotaion *)annotaion withBubbleView:(ACBubbleView *)popBubbleView {//创建气泡视图
    NSDictionary *contentInfo = [NSDictionary dictionaryWithDictionary:annotaion.contentDict];
    NSDictionary *stylesInfo = annotaion.stylesDict;
    //样式参数读取
    NSString *aligment = [stylesInfo stringValueForKey:@"illusAlign" defaultValue:@"left"];
    NSString *titleColor = [stylesInfo stringValueForKey:@"titleColor" defaultValue:@"#000"];
    NSString *subTitleColor = [stylesInfo stringValueForKey:@"subTitleColor" defaultValue:@"#000"];
    float titleSize = [stylesInfo floatValueForKey:@"titleSize" defaultValue:16];
    float subtitleSize = [stylesInfo floatValueForKey:@"subTitleSize" defaultValue:12];
    //内容参数读取
    NSString *illusPath = [contentInfo stringValueForKey:@"illus" defaultValue:nil];
    NSString *title = [contentInfo stringValueForKey:@"title" defaultValue:@""];
    NSString *subTitle = [contentInfo stringValueForKey:@"subTitle" defaultValue:@""];
    
    float bubbleWidth = [stylesInfo floatValueForKey:@"w" defaultValue:-1];
    float bubbleHeight = [stylesInfo floatValueForKey:@"h" defaultValue:90];
    
    float bubbleLong = 160;
    NSString *bgImgPathStr = annotaion.bubbleBgImg;
    if (bgImgPathStr.length == 0) {//若使用默认气泡背景，则根据内容文字大小自适应，最小160
        CGSize feelSize = [title sizeWithFont:[UIFont systemFontOfSize:titleSize] constrainedToSize:CGSizeMake(400,100)];
        bubbleLong = feelSize.width;
        if (bubbleLong > _mapView.bounds.size.width-64) {
            bubbleLong = _mapView.bounds.size.width - 64;
        }
        if (bubbleLong < 160) {
            bubbleLong = 160;
        }
    }
    if (bubbleWidth >= 0) {
        bubbleLong = bubbleWidth;
    }
    //背景图片
    NormalBubbleBgImgView *norBubbleBgView = popBubbleView.normalBgImgView;
//    popBubbleView.frame = CGRectMake(0, 0, bubbleLong, 90);
//    norBubbleBgView.frame = CGRectMake(0, 0, bubbleLong, 90);
    popBubbleView.frame = CGRectMake(0, 0, bubbleLong, bubbleHeight);
    norBubbleBgView.frame = CGRectMake(0, 0, bubbleLong, bubbleHeight);
    
    UIImage *imageBg = nil;
    if (bgImgPathStr.length > 0) {//自定义气泡背景
        imageBg = [UIImage imageWithContentsOfFile:bgImgPathStr];
        norBubbleBgView.image = imageBg;
        //隐藏默认气泡背景
        norBubbleBgView.leftBgImgView.hidden = YES;
        norBubbleBgView.rightBgImgView.hidden = YES;
    } else {//默认气泡背景
        //显示默认气泡背景
        norBubbleBgView.leftBgImgView.hidden = NO;
        norBubbleBgView.rightBgImgView.hidden = NO;
        //右边气泡
        NSString *leftBubble = [[NSBundle mainBundle]pathForResource:@"res_aMap/bubble_left" ofType:@"png"];
        UIImage *leftImage = [UIImage imageWithContentsOfFile:leftBubble];
        UIEdgeInsets inset1 = UIEdgeInsetsMake(10, 10, 16, 16);
        leftImage = [leftImage resizableImageWithCapInsets:inset1 resizingMode:UIImageResizingModeStretch];
        UIImageView *leftImg = norBubbleBgView.leftBgImgView;
        leftImg.frame = CGRectMake(0, 0, bubbleLong/2.0, bubbleHeight);
        leftImg.image = leftImage;
        //右边气泡
        NSString *rightBubble = [[NSBundle mainBundle]pathForResource:@"res_aMap/bubble_right" ofType:@"png"];
        UIImage *rightImage = [UIImage imageWithContentsOfFile:rightBubble];
        UIEdgeInsets inset2 = UIEdgeInsetsMake(10, 16, 16, 10);
        rightImage = [rightImage resizableImageWithCapInsets:inset2 resizingMode:UIImageResizingModeStretch];
        UIImageView *rightImg = norBubbleBgView.rightBgImgView;
        rightImg.frame = CGRectMake(bubbleLong/2.0, 0, bubbleLong/2.0, bubbleHeight);
        rightImg.image = rightImage;
    }
    //位置参数
    float labelW, labelH, labelX ,labelY;
    labelY = 18;
    labelH = 20;
    labelW = bubbleLong - 55;
    //插图
    if (illusPath.length > 0) {
        CGRect rect;
        if ([illusPath hasPrefix:@"http"]) {//网络图片
            norBubbleBgView.illusImgNetwork.hidden = NO;//显示网络插图视图
            norBubbleBgView.illusImgLocal.hidden = YES;//隐藏本地插图视图
            UIImageView *asyImg = norBubbleBgView.illusImgNetwork;
            NSURL *urlpath = [NSURL URLWithString:illusPath];
            [asyImg sd_setImageWithURL:urlpath];
            if (aligment.length>0 && [aligment isEqualToString:@"right"]) {
                rect = CGRectMake(bubbleLong-40, labelY, 30, 40);
                labelX = 10;
            } else {
                rect = CGRectMake(10, labelY, 30, 40);
                labelX = 45;
            }
            asyImg.frame = rect;
            //添加插图单击事件
            ACAMButton *tap = norBubbleBgView.illusNetTap;
            tap.frame = asyImg.bounds;
            tap.btnId = annotaion.annotId;
            tap.bubbleCbid = annotaion.bubbleClickCbid;
        } else {//本地插图图片
            norBubbleBgView.illusImgNetwork.hidden = YES;//隐藏网络插图视图
            norBubbleBgView.illusImgLocal.hidden = NO;//显示本地插图视图
            NSString *realIllusPath = [self getPathWithUZSchemeURL:illusPath];
            UIImageView *illusImg = norBubbleBgView.illusImgLocal;
            illusImg.image = [UIImage imageWithContentsOfFile:realIllusPath];
            if (aligment.length>0 && [aligment isEqualToString:@"right"]) {
                rect = CGRectMake(bubbleLong-40, labelY, 30, 40);
                labelX = 10;
            } else {
                rect = CGRectMake(10, labelY, 30, 40);
                labelX = 45;
            }
            illusImg.frame = rect;
            //添加插图单击事件
            ACAMButton *tap = norBubbleBgView.illusLocTap;
            tap.frame = illusImg.bounds;
            tap.btnId = annotaion.annotId;
            tap.bubbleCbid = annotaion.bubbleClickCbid;
        }
        //添加气泡单击事件
        ACAMButton *tapContent = norBubbleBgView.bubbleTap;
        CGRect tapRect = CGRectMake(labelX, 10, 140, 60);
        tapContent.frame = tapRect;
        tapContent.btnId = annotaion.annotId;
        tapContent.bubbleCbid = annotaion.bubbleClickCbid;
    } else {
        labelX = 10;
        labelW = bubbleLong - 20;
        //添加气泡单击事件
        ACAMButton *tap = norBubbleBgView.bubbleTap;
        tap.frame = norBubbleBgView.bounds;
        tap.btnId = annotaion.annotId;
        tap.bubbleCbid = annotaion.bubbleClickCbid;
    }
    if (subTitle.length == 0) {
//        labelY = 28;
        labelY = (bubbleHeight - labelH) / 2 ;
    } else {
        labelY = 18;
    }
    //标题
    UILabel *titleLab = norBubbleBgView.titleLab;
    titleLab.frame = CGRectMake(labelX, labelY, labelW, labelH);
    titleLab.text = title;
    titleLab.backgroundColor = [UIColor clearColor];
    titleLab.font = [UIFont systemFontOfSize:titleSize];
    titleLab.textColor = [UZAppUtils colorFromNSString:titleColor];
    //子标题
    UILabel *subTitleLab = norBubbleBgView.subtitleLab;
    subTitleLab.frame = CGRectMake(labelX, labelY+labelH+5, labelW, labelH);
    subTitleLab.text = subTitle;
    subTitleLab.backgroundColor = [UIColor clearColor];
    subTitleLab.font = [UIFont systemFontOfSize:subtitleSize];
    subTitleLab.textColor = [UZAppUtils colorFromNSString:subTitleColor];
    //标题子标题位置配置
    if (illusPath.length == 0) {
        titleLab.textAlignment = NSTextAlignmentCenter;
        subTitleLab.textAlignment = NSTextAlignmentCenter;
    } else {
        titleLab.textAlignment = NSTextAlignmentLeft;
        subTitleLab.textAlignment = NSTextAlignmentLeft;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(nonnull UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}
- (void)handleWebBillboardSingleTap:(UITapGestureRecognizer *)sender {
    if (!self.webBoardListener) {
        return;
    }
    if (sender.numberOfTapsRequired==1) {
        UIView *tempView = [sender.view superview];
        NSInteger annoid = tempView.tag;
        [self.webBoardListener callbackWithRet:@{@"id":@(annoid)} err:nil delete:NO];
    }
}
- (void)handleSingleTap:(UITapGestureRecognizer *)sender {
    if (sender.numberOfTapsRequired==1 && webBubbleCbid>=0) {
        NSInteger annoid = sender.view.tag;
        [self sendResultEventWithCallbackId:webBubbleCbid dataDict:@{@"id":@(annoid)} errDict:nil doDelete:NO];
    }
}

- (void)selectBubble:(UIButton *)btn {//点击气泡上的内容图事件
    ACAMButton *targetBtn = (ACAMButton *)btn;
    NSInteger setBubbleCbid = targetBtn.bubbleCbid;
    if (setBubbleCbid >= 0) {
        NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [sendDict setObject:[NSNumber numberWithInteger:targetBtn.btnId] forKey:@"id"];
        [sendDict setObject:@"clickContent" forKey:@"eventType"];
        [self sendResultEventWithCallbackId:setBubbleCbid dataDict:sendDict errDict:nil doDelete:NO];
    }
}

- (void)selectBubbleIllus:(UIButton *)btn {//点击气泡上的插图事件
    ACAMButton *targetBtn = (ACAMButton *)btn;
    NSInteger setBubbleCbid = targetBtn.bubbleCbid;
    if (setBubbleCbid >= 0) {
        NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [sendDict setObject:[NSNumber numberWithInteger:targetBtn.btnId] forKey:@"id"];
        [sendDict setObject:@"clickIllus" forKey:@"eventType"];
        [self sendResultEventWithCallbackId:setBubbleCbid dataDict:sendDict errDict:nil doDelete:NO];
    }
}

- (void)addWebBillboardView:(ACGDAnnotaion *)annotation withAnnotationView:(AnimatedAnnotationView *)annotationView {
    //样式参数获取
    NSDictionary *sizeDict = annotation.sizeDict;
    float billWidth = [sizeDict floatValueForKey:@"w" defaultValue:160];
    float billHeight = [sizeDict floatValueForKey:@"h" defaultValue:75];
    //背景图片（160*75）
    UIView *mainBoard = [[UIView alloc]initWithFrame:CGRectMake(0, 0, billWidth, billHeight)];
    mainBoard.backgroundColor = [UIColor clearColor];
    UIImageView *bgView = [[UIImageView alloc]init];
    bgView.frame = mainBoard.bounds;
    bgView.tag = WEBBILLBOARD_BGIMG;
    [mainBoard addSubview:bgView];
    
    if ([UZAppUtils isValidColor:annotation.bgStr]) {
        mainBoard.backgroundColor = [UZAppUtils colorFromNSString:annotation.bgStr];
    } else {
        UIImage *bgImg = [UIImage imageWithContentsOfFile:annotation.bgStr];
        bgView.image = bgImg;
    }
    annotationView.webBillboardView = mainBoard;
    
    //内容
    UIWebView *webView = [[UIWebView alloc]init];
    webView.scalesPageToFit = NO;//自动对页面进行缩放以适应屏幕
    webView.scrollView.bounces = NO;
    [webView setBackgroundColor:[UIColor clearColor]];
    [webView setOpaque:NO];
    webView.tag = WEBBILLBOARD_BGWEB;
    webView.frame = mainBoard.bounds;
    [mainBoard addSubview:webView];//加载内容
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(handleWebBillboardSingleTap:)];
    tapGesture.delegate = self;
    tapGesture.cancelsTouchesInView = NO;
    [webView addGestureRecognizer:tapGesture];
    
    NSString *billboardWebUrl = annotation.urlStr;
    NSString *dataWebData = annotation.dataStr;
    NSURL *url = nil;
    if ([billboardWebUrl hasPrefix:@"http"]) {
        url = [NSURL URLWithString:billboardWebUrl];//创建URL
    } else if (billboardWebUrl.length == 0) {
        url = nil;//创建URL
    } else {
        billboardWebUrl = [self getPathWithUZSchemeURL:billboardWebUrl];
        url = [NSURL fileURLWithPath:billboardWebUrl];//创建URL
    }
    if (dataWebData.length <=0 ) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url];//创建NSURLRequest
        [webView loadRequest:request];//加载
    } else {
        [webView loadHTMLString:dataWebData baseURL:nil];
    }
    mainBoard.tag = annotation.annotId;
}


- (void)addBillboardView:(ACGDAnnotaion *)annotation withAnnotationView:(AnimatedAnnotationView *)annotationView {
    //样式参数获取
    NSDictionary *stylesInfo = annotation.stylesDict;
    NSDictionary *billboardSize = [stylesInfo dictValueForKey:@"size" defaultValue:@{}];
    float billWidth = [billboardSize floatValueForKey:@"width" defaultValue:160];
    float billHeight = [billboardSize floatValueForKey:@"height" defaultValue:75];
    //背景图片（160*75）
    UIView *mainBoard = [[UIView alloc]initWithFrame:CGRectMake(0, 0, billWidth, billHeight)];
    mainBoard.backgroundColor = [UIColor clearColor];
    NSString *billImgPath = annotation.billBgImg;
    if (annotation.billboardSelected) {
        NSString *seleBillBg = [annotation.selectedBillStyle stringValueForKey:@"bgImg" defaultValue:nil];
        if (seleBillBg.length > 0) {
            billImgPath = seleBillBg;
        }
    }
    if (billImgPath.length > 0) {
        NSString *billealImg = [self getPathWithUZSchemeURL:billImgPath];
        UIImage *bgImg = [UIImage imageWithContentsOfFile:billealImg];
        UIImageView *bgView = [[UIImageView alloc]init];
        bgView.frame = mainBoard.bounds;
        bgView.image = bgImg;
        bgView.tag = BILLBOARD_BGIMG;
        [mainBoard addSubview:bgView];
    }
    annotationView.billboardView = mainBoard;
    //内容
    NSDictionary *contentInfo = [NSDictionary dictionaryWithDictionary:annotation.contentDict];
    NSString *illusPath = [contentInfo stringValueForKey:@"illus" defaultValue:nil];
    
    NSString *illusaligment = [stylesInfo stringValueForKey:@"illusAlign" defaultValue:@"left"];
    NSString *titleColor = [stylesInfo stringValueForKey:@"titleColor" defaultValue:@"#000"];
    NSString *subTitleColor = [stylesInfo stringValueForKey:@"subTitleColor" defaultValue:@"#000"];
    if (annotation.billboardSelected) {
        NSString *selecillusPath = [annotation.selectedBillStyle stringValueForKey:@"illus" defaultValue:nil];
        if (selecillusPath.length > 0) {
            illusPath = selecillusPath;
        }
        NSString *selectitleColor = [stylesInfo stringValueForKey:@"titleColor" defaultValue:nil];
        if (selectitleColor.length > 0) {
            titleColor = selectitleColor;
        }
        NSString *selecsubTitleColor = [stylesInfo stringValueForKey:@"subTitleColor" defaultValue:nil];
        if (selecsubTitleColor.length > 0) {
            subTitleColor = selecsubTitleColor;
        }
    }
    float titleSize = [stylesInfo floatValueForKey:@"titleSize" defaultValue:16];
    float subtitleSize = [stylesInfo floatValueForKey:@"subTitleSize" defaultValue:10];
    
    
    float titleMarginT = [stylesInfo floatValueForKey:@"marginT" defaultValue:10];
    float subtitleMarginB = [stylesInfo floatValueForKey:@"marginB" defaultValue:15];
    
    NSString *alignment = [stylesInfo stringValueForKey:@"alignment" defaultValue:@"left"];
    NSTextAlignment lableAlignment = NSTextAlignmentRight;
    if ([alignment isEqualToString:@"left"]) {
        lableAlignment = NSTextAlignmentLeft;
    } else if ([alignment isEqualToString:@"center"]){
        lableAlignment = NSTextAlignmentCenter;
    }
    //标题子标题间距
    float titleMarginLeft = [stylesInfo floatValueForKey:@"titleMarginLeft" defaultValue:10];
    float titleMarginRight = [stylesInfo floatValueForKey:@"titleMarginRight" defaultValue:10];
    float subTitleMarginLeft = [stylesInfo floatValueForKey:@"subTitleMarginLeft" defaultValue:10];
    float subTitleMarginRight = [stylesInfo floatValueForKey:@"subTitleMarginRight" defaultValue:10];
    float titleMaxLines = [stylesInfo floatValueForKey:@"titleMaxLines" defaultValue:1];
    float subTitleMaxLines = [stylesInfo floatValueForKey:@"subTitleMaxLines" defaultValue:1];
    //位置参数
    float titlelabelW, subtitlelabelW, titleLabelY, titleLableH, subtitleLabelY, subtitleLableH;
    //计算标题高度
    if (titleMaxLines <= 1) {
        titleLableH = titleSize + 2.0;
    } else {
        titleLableH = titleSize * titleMaxLines + (titleMaxLines-1)*2.0 + 2.0;
    }
    //计算子标题高度
    if (subTitleMaxLines <= 1) {
        subtitleLableH = subtitleSize + 2;
    } else {
        subtitleLableH = subtitleSize * subTitleMaxLines + (subTitleMaxLines-1)*2.0 + 2.0;
    }
    //标题y坐标
    titleLabelY = titleMarginT;
    subtitleLabelY = billHeight - subtitleMarginB - subtitleLableH;
    //标题宽度
    titlelabelW = billWidth - titleMarginLeft - titleMarginRight;
    subtitlelabelW = billWidth - subTitleMarginLeft - subTitleMarginRight;
    //有插图时标题和插图的布局
    if (illusPath.length > 0) {
        CGRect illusrect;
        NSDictionary *illusRectDict = [stylesInfo dictValueForKey:@"illusRect" defaultValue:nil];
        BOOL hasIllusRec = NO;
        if (illusRectDict) {
            hasIllusRec = YES;
        } else {
            illusRectDict = @{};
        }
        float illusX = [illusRectDict floatValueForKey:@"x" defaultValue:10];
        float illusY = [illusRectDict floatValueForKey:@"y" defaultValue:5];
        float illusW = [illusRectDict floatValueForKey:@"w" defaultValue:35];
        float illusH = [illusRectDict floatValueForKey:@"h" defaultValue:50];
        illusrect = CGRectMake(illusX, illusY, illusW, illusH);
        if (!hasIllusRec) {//插图的aligment
            if (illusaligment.length>0 && [illusaligment isEqualToString:@"right"]) {//右插图
                illusrect = CGRectMake(115, 5, 35, 50);
                titlelabelW = billWidth - titleMarginLeft - titleMarginRight - illusrect.size.width;
                subtitlelabelW = billWidth - subTitleMarginLeft - subTitleMarginRight - illusrect.size.width;
            } else {//左插图
                titleMarginLeft = illusX + illusW + titleMarginLeft;//插图和文字间距10.0
                subTitleMarginLeft = illusX + illusW + subTitleMarginLeft;//插图和文字间距10.0
                titlelabelW = billWidth - titleMarginLeft - titleMarginRight;
                subtitlelabelW = billWidth - subTitleMarginLeft - subTitleMarginRight;
            }
        } else {//插图rect
            if (illusX > (billWidth-illusW)/2.0) {//文字在左边，插图在右边（右边插图）
                titlelabelW = billWidth - titleMarginLeft - titleMarginRight - illusrect.size.width;
                subtitlelabelW = billWidth - subTitleMarginLeft - subTitleMarginRight - illusrect.size.width;
            } else {//文字在右边，插图在左边（左插图）
                titleMarginLeft = illusX + illusW + titleMarginLeft;//插图和文字间距10.0
                subTitleMarginLeft = illusX + illusW + subTitleMarginLeft;//插图和文字间距10.0
                titlelabelW = billWidth - titleMarginLeft - titleMarginRight;
                subtitlelabelW = billWidth - subTitleMarginLeft - subTitleMarginRight;
            }
        }
        if ([illusPath hasPrefix:@"http"]) {//网络图片
            UIImageView *asyImg = [[UIImageView alloc]init];
            NSURL *urlpath = [NSURL URLWithString:illusPath];
            [asyImg sd_setImageWithURL:urlpath];
            asyImg.tag = BILLBOARD_ILLUS;
            asyImg.frame = illusrect;
            [mainBoard addSubview:asyImg];
        } else {//本地图片
            NSString *realIllusPath = [self getPathWithUZSchemeURL:illusPath];
            UIImageView *illusImg = [[UIImageView alloc]init];
            illusImg.image = [UIImage imageWithContentsOfFile:realIllusPath];
            illusImg.tag = BILLBOARD_ILLUS;
            illusImg.frame = illusrect;
            [mainBoard addSubview:illusImg];
        }
    }
    
    NSString *titleStr = [contentInfo stringValueForKey:@"title" defaultValue:@""];
    
    AMapBillboardLabel *titleLab = [[AMapBillboardLabel alloc]initWithFrame:CGRectMake(titleMarginLeft, titleLabelY, titlelabelW, titleLableH)];
    titleLab.text = titleStr;
    titleLab.numberOfLines = 0;//表示label可以多行显示
    //[self changeLineSpaceForLabel:titleLab WithSpace:1.0];
    titleLab.tag = BILLBOARD_TITLE;
    titleLab.backgroundColor = [UIColor clearColor];
    titleLab.font = [UIFont systemFontOfSize:titleSize];
    titleLab.textColor = [UZAppUtils colorFromNSString:titleColor];
    titleLab.textAlignment = lableAlignment;
    [mainBoard addSubview:titleLab];
    //子标题
    NSString *subTitle = [contentInfo stringValueForKey:@"subTitle" defaultValue:nil];
    AMapBillboardLabel *subTitleLab = [[AMapBillboardLabel alloc]initWithFrame:CGRectMake(subTitleMarginLeft, subtitleLabelY, subtitlelabelW, subtitleLableH)];
    subTitleLab.numberOfLines = 0;//表示label可以多行显示
    //[self changeLineSpaceForLabel:subTitleLab WithSpace:2.0];
    subTitleLab.text = subTitle;
    subTitleLab.tag = BILLBOARD_SUBTITLE;
    subTitleLab.backgroundColor = [UIColor clearColor];
    subTitleLab.font = [UIFont systemFontOfSize:subtitleSize];
    subTitleLab.textColor = [UZAppUtils colorFromNSString:subTitleColor];
    subTitleLab.textAlignment = lableAlignment;
    [mainBoard addSubview:subTitleLab];
    if (illusPath.length == 0) {
        //titleLab.textAlignment = NSTextAlignmentCenter;
        //subTitleLab.textAlignment = NSTextAlignmentCenter;
    }
    //添加插图单击事件
    ACAMButton *tap = [ACAMButton buttonWithType:UIButtonTypeCustom];
    tap.frame = mainBoard.bounds;
    tap.btnId = annotation.annotId;
    tap.tag = BILLBOARD_BUTTON;
    tap.billboardCbid = annotation.addBillboardCbid;
    [tap addTarget:self action:@selector(selectBillboard:) forControlEvents:UIControlEventTouchDown];
    [mainBoard addSubview:tap];
}
- (void)refreshWebBillboardView:(ACGDAnnotaion *)annotation withAnnotationView:(AnimatedAnnotationView *)annotationView {
    //样式参数获取
    NSDictionary *sizeDict = annotation.sizeDict;
    float billWidth = [sizeDict floatValueForKey:@"w" defaultValue:160];
    float billHeight = [sizeDict floatValueForKey:@"h" defaultValue:75];
    //背景图片（160*75）
    UIView *mainBoard = annotationView.webBillboardView;
    mainBoard.tag = annotation.annotId;
    mainBoard.frame = CGRectMake(0, 0, billWidth, billHeight);
    NSString *billImgPath = annotation.bgStr;
    
    UIImageView *bgView = [(UIImageView *)mainBoard viewWithTag:WEBBILLBOARD_BGIMG];
    if ([UZAppUtils isValidColor:billImgPath]) {
        mainBoard.backgroundColor = [UZAppUtils colorFromNSString:billImgPath];
        bgView.image = nil;
    } else {
        mainBoard.backgroundColor = [UIColor clearColor];
        UIImage *bgImg = [UIImage imageWithContentsOfFile:billImgPath];
        bgView.image = bgImg;
    }
    
    //内容
    UIWebView *webView = [(UIWebView *)mainBoard viewWithTag:WEBBILLBOARD_BGWEB];
    webView.frame = mainBoard.bounds;
    NSString *billboardWebUrl = annotation.urlStr;
    NSString *dataWebData = annotation.dataStr;
    NSURL *url = nil;
    if ([billboardWebUrl hasPrefix:@"http"]) {
        url = [NSURL URLWithString:billboardWebUrl];//创建URL
    } else if (billboardWebUrl.length == 0) {
        url = nil;//创建URL
    } else {
        billboardWebUrl = [self getPathWithUZSchemeURL:billboardWebUrl];
        url = [NSURL fileURLWithPath:billboardWebUrl];//创建URL
    }
    if (dataWebData.length <=0 ) {
        NSURLRequest *request = [NSURLRequest requestWithURL:url];//创建NSURLRequest
        [webView loadRequest:request];//加载
    } else {
        [webView loadHTMLString:dataWebData baseURL:nil];
    }
}

- (void)refreshBillboardView:(ACGDAnnotaion *)annotation withAnnotationView:(AnimatedAnnotationView *)annotationView {
    //背景图片（160*75）
    UIView *mainBoard = annotationView.billboardView;
    NSString *billImgPath = annotation.billBgImg;
    if (annotation.billboardSelected) {
        NSString *seleBillBg = [annotation.selectedBillStyle stringValueForKey:@"bgImg" defaultValue:nil];
        if (seleBillBg.length > 0) {
            billImgPath = seleBillBg;
        }
    }
    if (billImgPath.length > 0) {
        NSString *billealImg = [self getPathWithUZSchemeURL:billImgPath];
        UIImage *bgImg = [UIImage imageWithContentsOfFile:billealImg];
        UIImageView *bgView = [mainBoard viewWithTag:BILLBOARD_BGIMG];
        bgView.frame = mainBoard.bounds;
        bgView.image = bgImg;
    }
    
    //内容
    NSDictionary *contentInfo = [NSDictionary dictionaryWithDictionary:annotation.contentDict];
    NSString *illusPath = [contentInfo stringValueForKey:@"illus" defaultValue:nil];
    float billWidth = mainBoard.bounds.size.width;
    float billHeight = mainBoard.bounds.size.height;
    NSDictionary *stylesInfo = annotation.stylesDict;
    NSString *illusaligment = [stylesInfo stringValueForKey:@"illusAlign" defaultValue:@"left"];
    NSString *titleColor = [stylesInfo stringValueForKey:@"titleColor" defaultValue:@"#000"];
    NSString *subTitleColor = [stylesInfo stringValueForKey:@"subTitleColor" defaultValue:@"#000"];
    if (annotation.billboardSelected) {
        NSString *selecillusPath = [annotation.selectedBillStyle stringValueForKey:@"illus" defaultValue:nil];
        if (selecillusPath.length > 0) {
            illusPath = selecillusPath;
        }
        NSString *selectitleColor = [stylesInfo stringValueForKey:@"titleColor" defaultValue:nil];
        if (selectitleColor.length > 0) {
            titleColor = selectitleColor;
        }
        NSString *selecsubTitleColor = [stylesInfo stringValueForKey:@"subTitleColor" defaultValue:nil];
        if (selecsubTitleColor.length > 0) {
            subTitleColor = selecsubTitleColor;
        }
    }
    float titleSize = [stylesInfo floatValueForKey:@"titleSize" defaultValue:16];
    float subtitleSize = [stylesInfo floatValueForKey:@"subTitleSize" defaultValue:12];
    float titleMarginT = [stylesInfo floatValueForKey:@"marginT" defaultValue:10];
    float subtitleMarginB = [stylesInfo floatValueForKey:@"marginB" defaultValue:15];
    NSString *alignment = [stylesInfo stringValueForKey:@"alignment" defaultValue:@"left"];
    NSTextAlignment lableAlignment = NSTextAlignmentRight;
    if ([alignment isEqualToString:@"left"]) {
        lableAlignment = NSTextAlignmentLeft;
    } else if ([alignment isEqualToString:@"center"]){
        lableAlignment = NSTextAlignmentCenter;
    }
    ////位置参数
    //float labelW, labelX, titleLableH ,titleLabelY, subtitleLabelY, subtitleLableH;
    ////无插图时标题的布局
    //labelX = 10;
    //labelW = billWidth - 20;
    //titleLabelY = titleMarginT;
    //titleLableH = titleSize + 2;
    //subtitleLableH = subtitleSize + 2;
    //subtitleLabelY = billHeight - subtitleMarginB - subtitleLableH;
    
    //标题子标题间距
    float titleMarginLeft = [stylesInfo floatValueForKey:@"titleMarginLeft" defaultValue:10];
    float titleMarginRight = [stylesInfo floatValueForKey:@"titleMarginRight" defaultValue:10];
    float subTitleMarginLeft = [stylesInfo floatValueForKey:@"subTitleMarginLeft" defaultValue:10];
    float subTitleMarginRight = [stylesInfo floatValueForKey:@"subTitleMarginRight" defaultValue:10];
    float titleMaxLines = [stylesInfo floatValueForKey:@"titleMaxLines" defaultValue:1];
    float subTitleMaxLines = [stylesInfo floatValueForKey:@"subTitleMaxLines" defaultValue:1];
    //位置参数
    float titlelabelW, subtitlelabelW, titleLabelY, titleLableH, subtitleLabelY, subtitleLableH;
    //计算标题高度
    if (titleMaxLines <= 1) {
        titleLableH = titleSize + 2.0;
    } else {
        titleLableH = titleSize * titleMaxLines + (titleMaxLines-1)*2.0;
    }
    //计算子标题高度
    if (subTitleMaxLines <= 1) {
        subtitleLableH = subtitleSize + 2;
    } else {
        subtitleLableH = subtitleSize * subTitleMaxLines + (subTitleMaxLines-1)*2.0;
    }
    //标题y坐标
    titleLabelY = titleMarginT;
    subtitleLabelY = billHeight - subtitleMarginB - subtitleLableH;
    //标题宽度
    titlelabelW = billWidth - titleMarginLeft - titleMarginRight;
    subtitlelabelW = billWidth - subTitleMarginLeft - subTitleMarginRight;
    //有插图时标题和插图的布局
    if (illusPath.length > 0) {
        CGRect illusrect;
        NSDictionary *illusRectDict = [stylesInfo dictValueForKey:@"illusRect" defaultValue:nil];
        BOOL hasIllusRec = NO;
        if (illusRectDict) {
            hasIllusRec = YES;
        } else {
            illusRectDict = @{};
        }
        float illusX = [illusRectDict floatValueForKey:@"x" defaultValue:10];
        float illusY = [illusRectDict floatValueForKey:@"y" defaultValue:5];
        float illusW = [illusRectDict floatValueForKey:@"w" defaultValue:35];
        float illusH = [illusRectDict floatValueForKey:@"h" defaultValue:50];
        illusrect = CGRectMake(illusX, illusY, illusW, illusH);
        if (!hasIllusRec) {//插图的aligment
            if (illusaligment.length>0 && [illusaligment isEqualToString:@"right"]) {//右插图
                illusrect = CGRectMake(115, 5, 35, 50);
                titlelabelW = billWidth - titleMarginLeft - titleMarginRight - illusrect.size.width;
                subtitlelabelW = billWidth - subTitleMarginLeft - subTitleMarginRight - illusrect.size.width;
            } else {//左插图
                titleMarginLeft = illusX + illusW + titleMarginLeft;//插图和文字间距10.0
                subTitleMarginLeft = illusX + illusW + subTitleMarginLeft;//插图和文字间距10.0
                titlelabelW = billWidth - titleMarginLeft - titleMarginRight;
                subtitlelabelW = billWidth - subTitleMarginLeft - subTitleMarginRight;
            }
        } else {//插图rect
            if (illusX > (billWidth-illusW)/2.0) {//文字在左边，插图在右边（右边插图）
                titlelabelW = billWidth - titleMarginLeft - titleMarginRight - illusrect.size.width;
                subtitlelabelW = billWidth - subTitleMarginLeft - subTitleMarginRight - illusrect.size.width;
            } else {//文字在右边，插图在左边（左插图）
                titleMarginLeft = illusX + illusW + titleMarginLeft;//插图和文字间距10.0
                subTitleMarginLeft = illusX + illusW + subTitleMarginLeft;//插图和文字间距10.0
                titlelabelW = billWidth - titleMarginLeft - titleMarginRight;
                subtitlelabelW = billWidth - subTitleMarginLeft - subTitleMarginRight;
            }
        }
        if ([illusPath hasPrefix:@"http"]) {//网络图片
            UIImageView *asyImg = [mainBoard viewWithTag:BILLBOARD_ILLUS];
            NSURL *urlpath = [NSURL URLWithString:illusPath];
            [asyImg sd_setImageWithURL:urlpath];
            asyImg.frame = illusrect;
        } else {//本地图片
            NSString *realIllusPath = [self getPathWithUZSchemeURL:illusPath];
            UIImageView *illusImg = [mainBoard viewWithTag:BILLBOARD_ILLUS];
            illusImg.image = [UIImage imageWithContentsOfFile:realIllusPath];
            illusImg.frame = illusrect;
        }
    }

    //标题
    NSString *titleStr = [contentInfo stringValueForKey:@"title" defaultValue:@""];
    AMapBillboardLabel *titleLab = [mainBoard viewWithTag:BILLBOARD_TITLE];
    titleLab.numberOfLines = 0;//表示label可以多行显示
    [self changeLineSpaceForLabel:titleLab WithSpace:2.0];
    titleLab.frame = CGRectMake(titleMarginLeft, titleLabelY, titlelabelW, titleLableH);
    titleLab.text = titleStr;
    titleLab.backgroundColor = [UIColor clearColor];
    titleLab.font = [UIFont systemFontOfSize:titleSize];
    titleLab.textAlignment = lableAlignment;
    titleLab.textColor = [UZAppUtils colorFromNSString:titleColor];
    //子标题
    NSString *subTitle = [contentInfo stringValueForKey:@"subTitle" defaultValue:nil];
    AMapBillboardLabel *subTitleLab = [mainBoard viewWithTag:BILLBOARD_SUBTITLE];
    subTitleLab.numberOfLines = 0;//表示label可以多行显示
    [self changeLineSpaceForLabel:subTitleLab WithSpace:2.0];
    subTitleLab.frame = CGRectMake(subTitleMarginLeft, subtitleLabelY, subtitlelabelW, subtitleLableH);
    subTitleLab.text = subTitle;
    subTitleLab.backgroundColor = [UIColor clearColor];
    subTitleLab.font = [UIFont systemFontOfSize:subtitleSize];
    subTitleLab.textColor = [UZAppUtils colorFromNSString:subTitleColor];
    subTitleLab.textAlignment = lableAlignment;
    if (illusPath.length == 0) {
        //titleLab.textAlignment = NSTextAlignmentCenter;
        //subTitleLab.textAlignment = NSTextAlignmentCenter;
    }
    //添加插图单击事件
    ACAMButton *tap = [mainBoard viewWithTag:BILLBOARD_BUTTON];
    tap.frame = mainBoard.bounds;
    tap.btnId = annotation.annotId;
}

- (void)selectBillboard:(ACAMButton *)btn {
    ACAMButton *targetBtn = (ACAMButton *)btn;
    ACGDAnnotaion *targetBillAnno = nil;
    for (ACGDAnnotaion *temp in [self.mapView annotations]) {
        if ([temp isKindOfClass:[ACGDAnnotaion class]] && temp.annotId==targetBtn.btnId) {
            targetBillAnno = temp;
            break;
        }
    }
    targetBillAnno.billboardSelected = YES;
    NSDictionary *selectedBillDict = targetBillAnno.selectedBillStyle;
    if (targetBillAnno && selectedBillDict) {
        UIView *mainBoard = [targetBtn superview];
        //更改背景
        NSString *selectedBg = [selectedBillDict stringValueForKey:@"bgImg" defaultValue:nil];
        if (selectedBg.length > 0) {
            UIImageView *bgView = [mainBoard viewWithTag:BILLBOARD_BGIMG];
            NSString *billealImg = [self getPathWithUZSchemeURL:selectedBg];
            UIImage *bgImg = [UIImage imageWithContentsOfFile:billealImg];
            bgView.image = bgImg;
        }
        //更改插图
        NSString *selectedIllus = [selectedBillDict stringValueForKey:@"illus" defaultValue:nil];
        if (selectedIllus.length > 0) {
            if ([selectedIllus hasPrefix:@"http"]) {//网络图片
                UIImageView *asyImg = [mainBoard viewWithTag:BILLBOARD_ILLUS];
                NSURL *urlpath = [NSURL URLWithString:selectedIllus];
                [asyImg sd_setImageWithURL:urlpath];
            } else {//本地图片
                NSString *realIllusPath = [self getPathWithUZSchemeURL:selectedIllus];
                UIImageView *illusImg = [mainBoard viewWithTag:BILLBOARD_ILLUS];
                illusImg.image = [UIImage imageWithContentsOfFile:realIllusPath];
            }
        }
        //更改标题颜色
        NSString *selectedTitleColor = [selectedBillDict stringValueForKey:@"titleColor" defaultValue:nil];
        if (selectedTitleColor.length > 0) {
            UILabel *titleLab = [mainBoard viewWithTag:BILLBOARD_TITLE];
            titleLab.textColor = [UZAppUtils colorFromNSString:selectedTitleColor];
        }
        //更改子标题
        NSString *selectedSubTitleColor = [selectedBillDict stringValueForKey:@"subTitleColor" defaultValue:nil];
        UILabel *subTitleLab = [mainBoard viewWithTag:BILLBOARD_SUBTITLE];
        subTitleLab.textColor = [UZAppUtils colorFromNSString:selectedSubTitleColor];
    }
    if (currentSelectedBillboard != targetBillAnno) {
        if (currentSelectedBillboard) {
            currentSelectedBillboard.billboardSelected = NO;
            [self.mapView removeAnnotation:currentSelectedBillboard];
            [self.mapView addAnnotation:currentSelectedBillboard];
        }
        currentSelectedBillboard = targetBillAnno;
    }
    
    NSInteger addBillboardCbid = targetBtn.billboardCbid;
    if (addBillboardCbid >= 0) {
        NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [sendDict setObject:@(targetBtn.btnId) forKey:@"id"];
        [sendDict setObject:@"click" forKey:@"eventType"];
        [self sendResultEventWithCallbackId:addBillboardCbid dataDict:sendDict errDict:nil doDelete:NO];
    }
}

- (void)doStep {
    if (_allMovingAnno.count == 0) {//如果需要移动的标注为0，则停止计时器
        [timerAnnoMove invalidate];
        self.timerAnnoMove = nil;
        return;
    }
    NSArray *allKey = [_allMovingAnno allKeys];
    for (NSString *annoKey in allKey) {
        ACGDAnnotaion *anno = [self.allMovingAnno objectForKey:annoKey];
        [anno moveStep];
    }
}

- (UIImage *)scaleImage:(UIImage *)img {//缩放图片
    if (!img) {
        return nil;
    }
    CGSize bImgSize = img.size;
    //NSLog(@"scaleImage转换之前图片大小：%f,%f",bImgSize.width,bImgSize.height);
    CGSize size = CGSizeMake(img.size.width/2.0, img.size.height/2.0);
    // 创建一个bitmap的context
    // 并把它设置成为当前正在使用的context
    //UIGraphicsBeginImageContext(size);
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    // 绘制改变大小的图片
    [img drawInRect:CGRectMake(0,0, size.width, size.height)];
    // 从当前context中创建一个改变大小后的图片
    UIImage *scaledImage =UIGraphicsGetImageFromCurrentImageContext();
    bImgSize = scaledImage.size;
    //NSLog(@"scaleImage转换之后图片大小：%f,%f",bImgSize.width,bImgSize.height);
    // 使当前的context出堆栈
    UIGraphicsEndImageContext();
    //返回新的改变大小后的图片
    return scaledImage;
}

- (void)resetAnnotationViewImage:(AnimatedAnnotationView *)annotationView withSize:(CGSize)size {
    float scale = [UIScreen mainScreen].scale;
    CGSize bImgSize = self.placeholdImage.size;
    //NSLog(@"1转换之前图片大小：%f,%f",bImgSize.width,bImgSize.height);
    UIImage *scaleImage = [self OriginImage:self.placeholdImage scaleToSize:CGSizeMake(size.width*scale, size.height*scale)];
    bImgSize = scaleImage.size;
    //NSLog(@"1转换之后图片大小：%f,%f",bImgSize.width,bImgSize.height);
    UIImage *finalImage = [UIImage imageWithData:UIImagePNGRepresentation(scaleImage) scale:scale];
    bImgSize = finalImage.size;
    //NSLog(@"2转换之后图片大小：%f,%f",bImgSize.width,bImgSize.height);
    annotationView.image = finalImage;
}

- (UIImage*)OriginImage:(UIImage*)image scaleToSize:(CGSize)size {
    UIGraphicsBeginImageContext(size);//size为CGSize类型，即你所需要的图片尺寸
    [image drawInRect:CGRectMake(0,0, size.width, size.height)];
    UIImage *scaledImage =UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}

- (BOOL)initSearchClass {
    if (!_mapSearch) {
        NSDictionary *feature_location = [self getFeatureByName:@"aMap"];
        NSString *ios_api_key = [feature_location stringValueForKey:@"ios_api_key" defaultValue:nil];
        if (ios_api_key.length > 0) {
            [[AMapServices sharedServices] setEnableHTTPS:YES];
            [AMapServices sharedServices].apiKey = ios_api_key;
            self.mapSearch = [[AMapSearchAPI alloc]init];
            self.mapSearch.delegate = self;
            return YES;
        } else {
            return NO;
        }
    }
    return YES;
}

- (BOOL)isValidLon:(float)lon lat:(float)lat {//判断经纬度是否合法
    if (ABS(lon)>180 || ABS(lat)>90) {
        return NO;
    }
    return YES;
}

- (CLLocationCoordinate2D *)coordinatesForString:(NSString *)string coordinateCount:(NSUInteger *)coordinateCount parseToken:(NSString *)token {
    if (string == nil) {
        return NULL;
    }
    if (token == nil) {
        token = @",";
    }
    NSString *str = @"";
    if (![token isEqualToString:@","]) {
        str = [string stringByReplacingOccurrencesOfString:token withString:@","];
    } else {
        str = [NSString stringWithString:string];
    }
    NSArray *components = [str componentsSeparatedByString:@","];
    NSUInteger count = [components count] / 2;
    if (coordinateCount != NULL) {
        *coordinateCount = count;
    }
    CLLocationCoordinate2D *coordinates = (CLLocationCoordinate2D*)malloc(count * sizeof(CLLocationCoordinate2D));
    for (int i = 0; i < count; i++) {
        coordinates[i].longitude = [[components objectAtIndex:2 * i]     doubleValue];
        coordinates[i].latitude  = [[components objectAtIndex:2 * i + 1] doubleValue];
    }
    return coordinates;
}

- (NSMutableArray *)getTransitsInfo:(NSArray *)allTransits {
    NSMutableArray *transitAry = [NSMutableArray array];
    for (AMapTransit *mapTransit in allTransits) {
        NSMutableDictionary *transitInfo = [NSMutableDictionary dictionary];
        [transitInfo setObject:[NSNumber numberWithBool:mapTransit.nightflag] forKey:@"nightflag"];
        [transitInfo setObject:[NSNumber numberWithFloat:mapTransit.cost] forKey:@"cost"];
        [transitInfo setObject:[NSNumber numberWithInteger:mapTransit.duration] forKey:@"duration"];
        [transitInfo setObject:[NSNumber numberWithInteger:mapTransit.walkingDistance] forKey:@"walkingDistance"];
        if (mapTransit.segments.count > 0) {
            NSMutableArray *segmentsAry = [NSMutableArray array];
            for (AMapSegment *segment in mapTransit.segments) {
                NSMutableDictionary *segmentInfo = [NSMutableDictionary dictionary];
                NSString *enterName = segment.enterName;
                if ([enterName isKindOfClass:[NSString class]] && enterName.length>0) {
                    [segmentInfo setObject:enterName forKey:@"enterName"];
                }
                NSString *exitName = segment.exitName;
                if ([exitName isKindOfClass:[NSString class]] && exitName.length>0) {
                    [segmentInfo setObject:exitName forKey:@"exitName"];
                }
                //该路段公交路线
                if (segment.buslines.count > 0) {
                    AMapBusLine *mapBusLine = segment.buslines[0];
                    NSMutableDictionary *busInfo = [NSMutableDictionary dictionary];
                    NSString *uid = mapBusLine.uid;
                    if ([uid isKindOfClass:[NSString class]]&& uid.length>0) {
                        [busInfo setObject:uid forKey:@"uid"];
                    }
                    NSString *type = mapBusLine.type;
                    if ([type isKindOfClass:[NSString class]]&& type.length>0) {
                        [busInfo setObject:type forKey:@"type"];
                    }
                    NSString *name = mapBusLine.name;
                    if ([name isKindOfClass:[NSString class]]&& name.length>0) {
                        [busInfo setObject:name forKey:@"name"];
                    }
                    [segmentInfo setObject:busInfo forKey:@"busline"];
                }
                //该路段入口出口坐标点
                float enterLat = segment.enterLocation.latitude;
                float enterLon = segment.enterLocation.longitude;
                float exitLat = segment.exitLocation.latitude;
                float exitLon = segment.exitLocation.longitude;
                NSMutableDictionary *enterInfo = [NSMutableDictionary dictionary];
                [enterInfo setObject:[NSNumber numberWithFloat:enterLat] forKey:@"lat"];
                [enterInfo setObject:[NSNumber numberWithFloat:enterLon] forKey:@"lon"];
                NSMutableDictionary *exitInfo = [NSMutableDictionary dictionary];
                [exitInfo setObject:[NSNumber numberWithFloat:exitLat] forKey:@"lat"];
                [exitInfo setObject:[NSNumber numberWithFloat:exitLon] forKey:@"lon"];
                [segmentInfo setObject:enterInfo forKey:@"enterLoc"];
                [segmentInfo setObject:exitInfo forKey:@"exitLoc"];
                //该路段步行信息
                NSInteger walkDist = segment.walking.distance;
                NSInteger walkDur = segment.walking.duration;
                NSMutableDictionary *wallkInfo = [NSMutableDictionary dictionary];
                [wallkInfo setObject:[NSNumber numberWithInteger:walkDist] forKey:@"distance"];
                [wallkInfo setObject:[NSNumber numberWithInteger:walkDur] forKey:@"duration"];
                [segmentInfo setObject:wallkInfo forKey:@"walking"];
                
                [segmentsAry addObject:segmentInfo];
            }
            [transitInfo setObject:segmentsAry forKey:@"segments"];
        }
        [transitAry addObject:transitInfo];
    }
    return transitAry;
}

- (NSMutableArray *)getPathInfo:(NSArray *)allPath {
    NSMutableArray *pathAry = [NSMutableArray array];
    for (AMapPath *path in allPath) {
        NSMutableDictionary *pathInfo = [NSMutableDictionary dictionary];
        [pathInfo setObject:[NSNumber numberWithInteger:path.distance] forKey:@"distance"];
        [pathInfo setObject:[NSNumber numberWithInteger:path.duration] forKey:@"duration"];
        [pathInfo setObject:[NSNumber numberWithFloat:path.tolls] forKey:@"tolls"];
        [pathInfo setObject:[NSNumber numberWithInteger:path.tollDistance] forKey:@"tollDistance"];
        NSString *strategy = path.strategy;
        if ([strategy isKindOfClass:[NSString class]] && strategy.length>0) {
            [pathInfo setObject:strategy forKey:@"strategy"];
        }
        //NSLog(@"******************:%zi",path.steps.count);
        if (path.steps.count > 0) {
            NSMutableArray *stepsAry = [NSMutableArray array];
            for (AMapStep *step in path.steps) {
                NSMutableDictionary *stepInfo = [NSMutableDictionary dictionary];
                NSString *instuction = step.instruction;
                if ([instuction isKindOfClass:[NSString class]] && instuction.length>0) {
                    [stepInfo setObject:instuction forKey:@"instruction"];
                }
                NSString *orientation = step.orientation;
                if ([orientation isKindOfClass:[NSString class]] && orientation.length>0) {
                    [stepInfo setObject:orientation forKey:@"orientation"];
                }
                NSString *road = step.road;
                if ([road isKindOfClass:[NSString class]] && road.length>0) {
                    [stepInfo setObject:road forKey:@"orientation"];
                }
                NSString *action = step.action;
                if ([action isKindOfClass:[NSString class]] && action.length>0) {
                    [stepInfo setObject:action forKey:@"orientation"];
                }
                NSString *assistantAction = step.assistantAction;
                if ([assistantAction isKindOfClass:[NSString class]] && assistantAction.length>0) {
                    [stepInfo setObject:assistantAction forKey:@"orientation"];
                }
                NSString *tollRoad = step.tollRoad;
                if ([tollRoad isKindOfClass:[NSString class]] && tollRoad.length>0) {
                    [stepInfo setObject:tollRoad forKey:@"orientation"];
                }
                [stepInfo setObject:[NSNumber numberWithInteger:step.distance] forKey:@"distance"];
                [stepInfo setObject:[NSNumber numberWithInteger:step.duration] forKey:@"duration"];
                [stepInfo setObject:[NSNumber numberWithInteger:step.tolls] forKey:@"tolls"];
                [stepInfo setObject:[NSNumber numberWithInteger:step.tollDistance] forKey:@"tollDistance"];
                //路段起终点
                NSString *polyline = step.polyline;
                if ([polyline isKindOfClass:[NSString class]] && polyline.length>0) {
                    NSUInteger count = 0;
                    CLLocationCoordinate2D *coordinates = [self coordinatesForString:polyline
                                                                     coordinateCount:&count
                                                                          parseToken:@";"];
                    CLLocationCoordinate2D startCoor = coordinates[0];
                    CLLocationCoordinate2D endCoor = coordinates[count-1];
                    NSMutableDictionary *startInfo = [NSMutableDictionary dictionary];
                    float startLat = startCoor.latitude;
                    float startLon = startCoor.longitude;
                    [startInfo setObject:[NSNumber numberWithFloat:startLat] forKey:@"lat"];
                    [startInfo setObject:[NSNumber numberWithFloat:startLon] forKey:@"lon"];
                    [stepInfo setObject:startInfo forKey:@"enterLoc"];
                    NSMutableDictionary *endInfo = [NSMutableDictionary dictionary];
                    float endLat = endCoor.latitude;
                    float endLon = endCoor.longitude;
                    [endInfo setObject:[NSNumber numberWithFloat:endLat] forKey:@"lat"];
                    [endInfo setObject:[NSNumber numberWithFloat:endLon] forKey:@"lon"];
                    [stepInfo setObject:endInfo forKey:@"exitLoc"];
                }
                [stepsAry addObject:stepInfo];
            }
            [pathInfo setObject:stepsAry forKey:@"steps"];
        }
        [pathAry addObject:pathInfo];
    }
    return pathAry;
}

-(UIImage *)imageResize:(UIImage*)img andResizeTo:(CGSize)newSize
{
    CGFloat scale = [[UIScreen mainScreen]scale];
    UIGraphicsBeginImageContext(newSize);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, scale);
    [img drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (NSMutableDictionary *)getDistrictDict:(AMapDistrictSearchResponse *)response {
    NSMutableDictionary *returnDict = [NSMutableDictionary dictionary];
    [returnDict setObject:@(response.count) forKey:@"count"];
    NSMutableArray *allDistrict = [self getDistrictAry:response.districts];
    
    [returnDict setObject:allDistrict forKey:@"districts"];
    return returnDict;
}

- (NSMutableArray *)getDistrictAry:(NSArray *)districts {
    NSMutableArray *returnAry = [NSMutableArray array];
    for (AMapDistrict *district in districts) {
        NSMutableDictionary *disDict = [self getDistrictInfo:district];
        [returnAry addObject:disDict];
    }
    return returnAry;
}
- (NSMutableDictionary *)getDistrictInfo:(AMapDistrict *)district {
    NSMutableDictionary *districtDict = [NSMutableDictionary dictionary];
    
    ///区域编码
    NSString     *adcode = district.adcode;
    if (![adcode isKindOfClass:[NSString class]] || adcode.length==0) {
        adcode = @"";
    }
    [districtDict setObject:adcode forKey:@"adcode"];
    ///城市编码
    NSString     *citycode = district.citycode;
    if (![citycode isKindOfClass:[NSString class]] || citycode.length==0) {
        citycode = @"";
    }
    [districtDict setObject:citycode forKey:@"citycode"];
    ///行政区名称
    NSString     *name = district.name;
    if (![name isKindOfClass:[NSString class]] || name.length==0) {
        name = @"";
    }
    [districtDict setObject:name forKey:@"name"];
    ///级别
    NSString     *level = district.level;
    if (![level isKindOfClass:[NSString class]] || level.length==0) {
        level = @"";
    }
    [districtDict setObject:level forKey:@"level"];
    ///城市中心点
    AMapGeoPoint *center = district.center;
    NSDictionary *centerDict = @{};
    if (center) {
        centerDict = @{@"latitude":@(center.latitude),@"longitude":@(center.longitude)};
    }
    [districtDict setObject:centerDict forKey:@"center"];
    NSArray *polylines = district.polylines;
    if (![polylines isKindOfClass:[NSArray class]] || polylines.count<=0) {
        polylines = @[];
    }
    [districtDict setObject:polylines forKey:@"polylines"];
    
    ///下级行政区域数组
    NSArray<AMapDistrict *> *districts = district.districts;
    if ([districts isKindOfClass:[NSArray class]] && districts.count>0) {
        NSMutableArray *allDistrict = [self getDistrictAry:districts];
        [districtDict setObject:allDistrict forKey:@"districts"];
    } else {
        [districtDict setObject:@[] forKey:@"districts"];
    }
    return districtDict;
}

- (void)handleDistrictResponse:(AMapDistrictSearchResponse *)response {
    if (response == nil) {
        return;
    }
    if (!self.allOverlays) {
        self.allOverlays = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    NSArray *allPolyline = [self.allOverlays objectForKey:@"districtLineKey"];
    if ([allPolyline isKindOfClass:[NSArray class]] && allPolyline.count>0) {
        for (MAPolyline *pline in allPolyline) {
            if (pline) {
                [self.mapView removeOverlay:pline];
            }
        }
    }
    for (AMapDistrict *dist in response.districts) {
        //在子区域中点添加标注
        //MAPointAnnotation *poiAnnotation = [[MAPointAnnotation alloc] init];
        //poiAnnotation.coordinate = CLLocationCoordinate2DMake(dist.center.latitude, dist.center.longitude);
        //poiAnnotation.title      = dist.name;
        //poiAnnotation.subtitle   = dist.adcode;
        //[self.mapView addAnnotation:poiAnnotation];
        
        if (dist.polylines.count > 0) {
            MAMapRect bounds = MAMapRectZero;
            NSMutableArray *plineAry = [NSMutableArray array];
            for (NSString *polylineStr in dist.polylines) {
                ACDistrictLine *polyline = [self polylineForCoordinateString:polylineStr];
                [self.mapView addOverlay:polyline];
                [plineAry addObject:polyline];
                bounds = MAMapRectUnion(bounds, polyline.boundingMapRect);
            }
            [self.allOverlays setObject:plineAry forKey:@"districtLineKey"];
            
            /*
             //如果要显示带填充色的polygon，打开此开关
             for (NSString *polylineStr in dist.polylines)
             {
             NSUInteger tempCount = 0;
             CLLocationCoordinate2D *coordinates = [CommonUtility coordinatesForString:polylineStr
             coordinateCount:&tempCount
             parseToken:@";"];
             
             
             MAPolygon *polygon = [MAPolygon polygonWithCoordinates:coordinates count:tempCount];
             free(coordinates);
             [self.mapView addOverlay:polygon];
             }*/
            
            [self.mapView setVisibleMapRect:bounds animated:YES];
        }
        
        /*
         // 子区域
         for (AMapDistrict *subdist in dist.districts) {
         MAPointAnnotation *subAnnotation = [[MAPointAnnotation alloc] init];
         subAnnotation.coordinate = CLLocationCoordinate2DMake(subdist.center.latitude, subdist.center.longitude);
         subAnnotation.title      = subdist.name;
         subAnnotation.subtitle   = subdist.adcode;
         [self.mapView addAnnotation:subAnnotation];
         }
         */
    }
    
}
- (ACDistrictLine *)polylineForCoordinateString:(NSString *)coordinateString {
    if (coordinateString.length == 0) {
        return nil;
    }
    NSUInteger count = 0;
    CLLocationCoordinate2D *coordinates = [self coordinatesForString:coordinateString
                                                     coordinateCount:&count
                                                          parseToken:@";"];
    
    ACDistrictLine *polyline = [ACDistrictLine polylineWithCoordinates:coordinates count:count];
    
    free(coordinates), coordinates = NULL;
    
    return polyline;
}
- (void)changeLineSpaceForLabel:(UILabel *)label WithSpace:(float)space {
    NSString *labelText = label.text;
    if (labelText.length == 0) {
        return;
    }
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:labelText];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing:space];
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [labelText length])];
    label.attributedText = attributedString;
    [label sizeToFit];
}
- (void)changeLineSpaceForTextView:(UITextView *)textView WithSpace:(float)space andSize:(float)fontSize {
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    
    paragraphStyle.lineSpacing = space;// 字体的行间距
    
    NSDictionary *attributes = @{
                                 NSFontAttributeName:[UIFont systemFontOfSize:fontSize],
                                 NSParagraphStyleAttributeName:paragraphStyle
                                 };
    textView.typingAttributes = attributes;
}
@end
