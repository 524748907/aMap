//
//  GDMap.m
//  UZEngine
//
//  Created by zhengcuan on 15/10/26.
//  Copyright © 2015年 APICloud. All rights reserved.
//

#import "GDMap.h"
//#import <AMapNaviKit/MAMapKit.h>
#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import "NSDictionaryUtils.h"
#import "UZAppUtils.h"
#import <CoreLocation/CoreLocation.h>
#import "ACGDAnnotaion.h"
#import "AnimatedAnnotationView.h"
#import "AMapAsyncImageView.h"
#import "ACAMButton.h"
#import <AMapSearchKit/AMapSearchKit.h>
#import "MANaviRoute.h"
#import "CommonUtility.h"
#import "BusStopAnnotation.h"
#import "MABusPolyline.h"
#import "UZMultiPolyline.h"

typedef NS_ENUM(NSInteger, AMapRoutePlanningType) {
    AMapRoutePlanningTypeDrive = 0, //驾车
    AMapRoutePlanningTypeWalk,      //步行
    AMapRoutePlanningTypeBus        //公交
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
#define ANNOTATION_MOBILETAG     1060

@interface GDMap ()
<MAMapViewDelegate, CanMovingAnimationDelegate, AMapSearchDelegate> {
    MAMapView *_mapView;
    BOOL firstShowLocation;
    //定位
    NSInteger getLocationCbid;
    BOOL getLocationAutostop;
    MAUserLocation *currentUserLocation;
    //监听地图事件id
    NSInteger longPressCbid, viewChangeCbid, singleTapCbid, trackingModeCbid, zoomLisCbid;
    //标注气泡类
    NSInteger setBubbleCbid, addBillboardCbid, moveAnnoCbid, addMobileAnnoCbid;
    NSMutableDictionary *_allMovingAnno;//可移动的标注集合
    //覆盖物类
    NSMutableDictionary *_allOverlays;
    NSDictionary *overlayStyles;//覆盖物样式
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

- (void)dispose {
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
        setBubbleCbid = -1;
        addBillboardCbid = -1;
        addMobileAnnoCbid = -1;
        zoomLisCbid = -1;
        self.timerAnnoMove = nil;
        canDraw = NO;
        poiSearchCbid = -1;
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

    //显示地图
    self.mapView = [[MAMapView alloc]initWithFrame:newRect];
    self.mapView.frame = newRect;
    self.mapView.delegate = self;
    [self.mapView setZoomLevel:zoomLevel animated:NO];
    self.mapView.showsUserLocation = isShow;
    self.mapView.mapType = MAMapTypeStandard;
    [self addSubview:self.mapView fixedOn:fixedOnName fixed:fixed];
    firstShowLocation = YES;
    //设置父滚动视图的canCancelContentTouches
    UIWebView *webView = (UIWebView *)[self getViewByName:fixedOnName];
    id superViewObj = [webView superview];
    if (!fixed && [superViewObj isKindOfClass:[UIScrollView class]]) {
        UIScrollView *scrollView = (UIScrollView *)superViewObj;
        scrollView.canCancelContentTouches = NO;
    }
    //设置地图中心点
    NSDictionary *centerInfo = [paramsDict_ dictValueForKey:@"center" defaultValue:@{}];
    if (centerInfo.count > 0) {
        float centerLon = [centerInfo floatValueForKey:@"lon" defaultValue:116.213];
        float centerLat = [centerInfo floatValueForKey:@"lat" defaultValue:39.213];
        if ([self isValidLon:centerLon lat:centerLat]) {
            firstShowLocation = NO;
            CLLocationCoordinate2D coord2d;
            coord2d.latitude = centerLat;
            coord2d.longitude = centerLon;
            [self.mapView setCenterCoordinate:coord2d animated:NO];
        }
    }
    //回调
    NSInteger openCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    if (self.mapView && openCbid>=0 && [AMapServices sharedServices].apiKey.length>0){
        [self sendResultEventWithCallbackId:openCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"status"] errDict:nil doDelete:YES];
    } else {
        [self sendResultEventWithCallbackId:openCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"status"] errDict:nil doDelete:YES];
    }
}

- (void)close:(NSDictionary *)parmasDict_ {
    if (self.mapView) {
        self.mapView.delegate = nil;
        [self.mapView removeFromSuperview];
        self.mapView = nil;
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
    if (timerAnnoMove) {
        [timerAnnoMove invalidate];
        self.timerAnnoMove = nil;
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
    UIView *superView = [self.mapView superview];
    NSDictionary *rectInfo = [paramsDict_ dictValueForKey:@"rect" defaultValue:@{}];
    float orgX = [rectInfo floatValueForKey:@"x" defaultValue:superView.frame.origin.x];
    float orgY = [rectInfo floatValueForKey:@"y" defaultValue:superView.frame.origin.y];
    float viewW = [rectInfo floatValueForKey:@"w" defaultValue:superView.bounds.size.width];
    float viewH = [rectInfo floatValueForKey:@"h" defaultValue:superView.bounds.size.height];
    CGRect newRect = CGRectMake(orgX, orgY, viewW, viewH);
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
        return;
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
        [self sendResultEventWithCallbackId:cbcontantId dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"status"] errDict:nil doDelete:YES];
        return;
    }
    NSDictionary *targetInfo = [paramsDict_ dictValueForKey:@"point" defaultValue:@{}];
    if (!targetInfo || targetInfo.count==0) {
        [self sendResultEventWithCallbackId:cbcontantId dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"status"] errDict:nil doDelete:YES];
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
        if (longPressCbid != -1) {
            [self deleteCallback:longPressCbid];
        }
        longPressCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    } else if ([nameStr isEqualToString:@"viewChange"]) {//视角改变监听
        if (viewChangeCbid != -1) {
            [self deleteCallback:viewChangeCbid];
        }
        viewChangeCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    } else if ([nameStr isEqualToString:@"click"]) {//单击监听
        if (singleTapCbid != -1) {
            [self deleteCallback:singleTapCbid];
        }
        singleTapCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    } else if ([nameStr isEqualToString:@"trackingMode"]) {//tackingmode监听
        if (trackingModeCbid != -1) {
            [self deleteCallback:trackingModeCbid];
        }
        trackingModeCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    } else if ([nameStr isEqualToString:@"zoom"]) {//tackingmode监听
        if (zoomLisCbid != -1) {
            [self deleteCallback:zoomLisCbid];
        }
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
    }
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
        if (![self isValidLon:lon lat:lat]) {
            continue;
        }
        NSInteger annoId = [annoInfo integerValueForKey:@"id" defaultValue:-1];
        if (annoId < 0) {
            continue;
        }
        NSArray *pinIcons = [annoInfo arrayValueForKey:@"icons" defaultValue:nil];
        if (pinIcons.count > 0) {
            NSMutableArray *newPinIcons = [NSMutableArray arrayWithCapacity:1];
            for (NSString *iconPath in pinIcons) {
                NSString *realPath = [self getPathWithUZSchemeURL:iconPath];
                [newPinIcons addObject:realPath];
            }
            pinIcons = newPinIcons;
        }
        ACGDAnnotaion *annotation = [[ACGDAnnotaion alloc] init];
        CLLocationCoordinate2D coor;
        coor.longitude = lon;
        coor.latitude = lat;
        annotation.coordinate = coor;
        annotation.annotId = annoId;
        annotation.clickCbId = addAnnCbid;
        annotation.interval = timeInterval;
        if (pinIcons.count > 0) {
            annotation.pinIcons = pinIcons;
        } else {
            annotation.pinIcons = iconPaths;
        }
        if ([annoInfo objectForKey:@"draggable"]) {
            annotation.draggable = [annoInfo boolValueForKey:@"draggable" defaultValue:NO];
        } else {
            annotation.draggable = draggable;
        }
        [annotationsAry addObject:annotation];
    }
    if (annotationsAry.count > 0) {
        [self.mapView addAnnotations:annotationsAry];
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

- (void)setBubble:(NSDictionary *)paramsDict_ {
    NSString *setID = [paramsDict_ stringValueForKey:@"id" defaultValue:nil];
    NSString *bgImgStr = [paramsDict_ stringValueForKey:@"bgImg" defaultValue:nil];
    NSDictionary *contentInfo = [paramsDict_ dictValueForKey:@"content" defaultValue:@{}];
    NSDictionary *styleInfo = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    if (![setID isKindOfClass:[NSString class]] || setID.length==0) {
        return;
    }
    if (setBubbleCbid >= 0) {
        [self deleteCallback:setBubbleCbid];
    }
    setBubbleCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
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
    NSDictionary *contentInfo = [paramsDict_ dictValueForKey:@"content" defaultValue:@{}];
    NSDictionary *styleInfo = [paramsDict_ dictValueForKey:@"styles" defaultValue:@{}];
    if (addBillboardCbid >= 0) {
        [self deleteCallback:addBillboardCbid];
    }
    addBillboardCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    ACGDAnnotaion *annotation = [[ACGDAnnotaion alloc] init];
    CLLocationCoordinate2D coor;
    coor.longitude = lon;
    coor.latitude = lat;
    annotation.coordinate = coor;
    annotation.annotId = [setID integerValue];
    annotation.billBgImg = bgImgStr;
    annotation.draggable = [paramsDict_ boolValueForKey:@"draggable" defaultValue:NO];
    annotation.contentDict = contentInfo;
    annotation.stylesDict = styleInfo;
    annotation.type = ANNOTATION_BILLBOARD;
    [self.mapView addAnnotation:annotation];
}

- (void)addMobileAnnotations:(NSDictionary *)paramsDict_ {
    addMobileAnnoCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
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
    if (moveAnnoCbid >= 0) {
        [self deleteCallback:moveAnnoCbid];
    }
    moveAnnoCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
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
                if (OBJMap.timerAnnoMove == nil) {
                    [OBJMap.timerAnnoMove invalidate];
                    OBJMap.timerAnnoMove = [CADisplayLink displayLinkWithTarget:OBJMap selector:@selector(doStep)];
                    OBJMap.timerAnnoMove.frameInterval = 2;
                    NSRunLoop *mainRunLoop = [NSRunLoop currentRunLoop];
                    [OBJMap.timerAnnoMove addToRunLoop:mainRunLoop forMode:NSDefaultRunLoopMode];
                    [OBJMap.timerAnnoMove addToRunLoop:mainRunLoop forMode:UITrackingRunLoopMode];
                }
            };
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
    }
}

#pragma mark 覆盖物类接口

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
    NSInteger pointCount = [pointAry count];
    CLLocationCoordinate2D coorAry[500] = {0};
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
            _runningCoords[i].longitude = [data[@"longtitude"] doubleValue];
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
    } else {
        self.routePlanningType = AMapRoutePlanningTypeDrive;//驾车
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
            navi.multipath = 1;
            /* 出发点. */
            navi.origin = start;
            /* 目的地. */
            navi.destination = end;
            [self.mapSearch AMapWalkingRouteSearch:navi];
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
        MANaviAnnotationType type = self.routePlanningType == AMapRoutePlanningTypeDrive ? MANaviAnnotationTypeDrive : MANaviAnnotationTypeWalking;
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
    /*
    [busLine.busStops enumerateObjectsUsingBlock:^(AMapBusStop *busStop, NSUInteger idx, BOOL *stop) {
        BusStopAnnotation *annotation = [[BusStopAnnotation alloc] initWithBusStop:busStop];

        [busStopAnnotations addObject:annotation];
    }];
     */
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
        return;
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

#pragma mark 离线地图类
- (void)getProvinces:(NSDictionary *)paramsDict_ {
    NSInteger provinceCbid = [paramsDict_ integerValueForKey:@"cbId" defaultValue:-1];
    NSArray *allProvince = [MAOfflineMap sharedOfflineMap].provinces;
    NSMutableArray *provinceAry = [NSMutableArray array];
    for (MAOfflineProvince *province in allProvince) {
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
        if (citiesAry.count > 0) {
            [provinceAry addObject:citiesAry];
        }
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
    //步行、驾车路线方案
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

#pragma mark - MAMapViewDelegate -

#pragma mark 覆盖物类代理
- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id <MAOverlay>)overlay {
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
        circleView.lineDash = [overlayStyles boolValueForKey:@"lineDash" defaultValue:NO];
        return circleView;
    } else if ([overlay isKindOfClass:[MAPolygon class]]) {//多边形
        MAPolygonRenderer *polygonView = [[MAPolygonRenderer alloc] initWithPolygon:overlay];
        polygonView.lineWidth = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2];
        NSString *stroke = [overlayStyles stringValueForKey:@"borderColor" defaultValue:@"#000"];
        NSString *fill = [overlayStyles stringValueForKey:@"fillColor" defaultValue:@"rgba(1,0.8,0,0.8)"];
        polygonView.strokeColor = [UZAppUtils colorFromNSString:stroke];
        polygonView.fillColor = [UZAppUtils colorFromNSString:fill];
        polygonView.lineJoinType = kMALineJoinRound;
        polygonView.lineDash = [overlayStyles boolValueForKey:@"lineDash" defaultValue:NO];
        return polygonView;
    } else if ([overlay isKindOfClass:[MAPolyline class]]) {//线
        MAPolylineRenderer *polylineView = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        NSString *keyStr = nil;
        NSArray *allOverlayKeys = [self.allOverlays allKeys];
        for (NSString *targetKey in allOverlayKeys) {
            MAPolyline *target = [self.allOverlays objectForKey:targetKey];
            if (target == overlay) {
                keyStr = targetKey;
                break;
            }
        }
        NSString *strokeImage = [overlayStyles stringValueForKey:@"strokeImg" defaultValue:@""];
        if ([strokeImage isKindOfClass:[NSString class]] && strokeImage.length>0) {//文理图片线条
            polylineView.lineWidth = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2.0];
            NSString *realStrokeImgPath = [self getPathWithUZSchemeURL:strokeImage];
            [polylineView loadStrokeTextureImage:[UIImage imageWithContentsOfFile:realStrokeImgPath]];
        } else {//线
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
            polylineView.lineDash = [overlayStyles boolValueForKey:@"lineDash" defaultValue:NO];
        }
        return polylineView;
    } else if ([overlay isKindOfClass:[MAGeodesicPolyline class]]) {//弧形
        MAPolylineRenderer *polylineView = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        polylineView.lineWidth = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2.0];
        NSString *color = [overlayStyles stringValueForKey:@"borderColor" defaultValue:@"#000"];
        polylineView.strokeColor = [UZAppUtils colorFromNSString:color];
        polylineView.lineDash = [overlayStyles boolValueForKey:@"lineDash" defaultValue:NO];
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
            polylineRenderer.lineDash = [walkStyle boolValueForKey:@"lineDash" defaultValue:NO];
            NSString *strokeImg = [walkStyle stringValueForKey:@"strokeImg" defaultValue:nil];
            if (strokeImg.length > 0) {
                strokeImg = [self getPathWithUZSchemeURL:strokeImg];
                UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
                [polylineRenderer loadStrokeTextureImage:strokeImage];
            }
        } else if (naviPolyline.type == MANaviAnnotationTypeBus) {//公交路线样式
            NSDictionary *busStyle = [routeStyles dictValueForKey:@"busLine" defaultValue:@{}];
            polylineRenderer.lineWidth = [busStyle floatValueForKey:@"width" defaultValue:4];
            NSString *colorStr = [busStyle stringValueForKey:@"color" defaultValue:@"#00BFFF"];
            polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
            polylineRenderer.lineDash = [busStyle boolValueForKey:@"lineDash" defaultValue:NO];
            NSString *strokeImg = [busStyle stringValueForKey:@"strokeImg" defaultValue:nil];
            if (strokeImg.length > 0) {
                strokeImg = [self getPathWithUZSchemeURL:strokeImg];
                UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
                [polylineRenderer loadStrokeTextureImage:strokeImage];
            }
        } else {//驾车路线样式
            NSDictionary *driveStyle = [routeStyles dictValueForKey:@"driveLine" defaultValue:@{}];
            polylineRenderer.lineWidth = [driveStyle floatValueForKey:@"width" defaultValue:5];
            NSString *colorStr = [driveStyle stringValueForKey:@"color" defaultValue:@"#00868B"];
            polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
            polylineRenderer.lineDash = [driveStyle boolValueForKey:@"lineDash" defaultValue:NO];
            NSString *strokeImg = [driveStyle stringValueForKey:@"strokeImg" defaultValue:nil];
            if (strokeImg.length > 0) {
                strokeImg = [self getPathWithUZSchemeURL:strokeImg];
                UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
                [polylineRenderer loadStrokeTextureImage:strokeImage];
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
        polylineRenderer.lineDash = [driveStyle boolValueForKey:@"lineDash" defaultValue:NO];
        NSString *strokeImg = [driveStyle stringValueForKey:@"strokeImg" defaultValue:nil];
        if (strokeImg.length > 0) {
            strokeImg = [self getPathWithUZSchemeURL:strokeImg];
            UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
            [polylineRenderer loadStrokeTextureImage:strokeImage];
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
        polylineRenderer.lineDash = [lineStyle boolValueForKey:@"lineDash" defaultValue:NO];
        NSString *strokeImg = [lineStyle stringValueForKey:@"strokeImg" defaultValue:nil];
        if (strokeImg.length > 0) {
            strokeImg = [self getPathWithUZSchemeURL:strokeImg];
            UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
            [polylineRenderer loadStrokeTextureImage:strokeImage];
        }
        return polylineRenderer;
    }
    return nil;
}
/*
- (MAOverlayView *)mapView:(MAMapView *)mapView viewForOverlay:(id <MAOverlay>)overlay {
    if ([overlay isKindOfClass:[MACircle class]]) {//圆
        MACircleView *circleView = [[MACircleView alloc] initWithCircle:overlay];
        circleView.lineWidth  = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2];
        NSString *stroke = [overlayStyles stringValueForKey:@"borderColor" defaultValue:@"#000"];
        NSString *fill = [overlayStyles stringValueForKey:@"fillColor" defaultValue:@"rgba(1,0.8,0,0.8)"];
        circleView.strokeColor = [UZAppUtils colorFromNSString:stroke];
        circleView.fillColor = [UZAppUtils colorFromNSString:fill];
        circleView.lineDash = [overlayStyles boolValueForKey:@"lineDash" defaultValue:NO];
        return circleView;
    } else if ([overlay isKindOfClass:[MAPolygon class]]) {//多边形
        MAPolygonView *polygonView = [[MAPolygonView alloc] initWithPolygon:overlay];
        polygonView.lineWidth = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2];
        NSString *stroke = [overlayStyles stringValueForKey:@"borderColor" defaultValue:@"#000"];
        NSString *fill = [overlayStyles stringValueForKey:@"fillColor" defaultValue:@"rgba(1,0.8,0,0.8)"];
        polygonView.strokeColor = [UZAppUtils colorFromNSString:stroke];
        polygonView.fillColor = [UZAppUtils colorFromNSString:fill];
        polygonView.lineJoinType = kMALineJoinRound;
        polygonView.lineDash = [overlayStyles boolValueForKey:@"lineDash" defaultValue:NO];
        return polygonView;
    } else if ([overlay isKindOfClass:[MAPolyline class]]) {//线
        MAPolylineView *polylineView = [[MAPolylineView alloc] initWithPolyline:overlay];
        NSString *keyStr = nil;
        NSArray *allOverlayKeys = [self.allOverlays allKeys];
        for (NSString *targetKey in allOverlayKeys) {
            MAPolyline *target = [self.allOverlays objectForKey:targetKey];
            if (target == overlay) {
                keyStr = targetKey;
                break;
            }
        }
        NSString *strokeImage = [overlayStyles stringValueForKey:@"strokeImg" defaultValue:@""];
        if ([strokeImage isKindOfClass:[NSString class]] && strokeImage.length>0) {//文理图片线条
            polylineView.lineWidth = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2.0];
            NSString *realStrokeImgPath = [self getPathWithUZSchemeURL:strokeImage];
            [polylineView loadStrokeTextureImage:[UIImage imageWithContentsOfFile:realStrokeImgPath]];
        } else {//线
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
            polylineView.lineDash = [overlayStyles boolValueForKey:@"lineDash" defaultValue:NO];
        }
        return polylineView;
    } else if ([overlay isKindOfClass:[MAGeodesicPolyline class]]) {//弧形
        MAPolylineView *polylineView = [[MAPolylineView alloc] initWithPolyline:overlay];
        polylineView.lineWidth = [overlayStyles floatValueForKey:@"borderWidth" defaultValue:2.0];
         NSString *color = [overlayStyles stringValueForKey:@"borderColor" defaultValue:@"#000"];
        polylineView.strokeColor = [UZAppUtils colorFromNSString:color];
        polylineView.lineDash = [overlayStyles boolValueForKey:@"lineDash" defaultValue:NO];
        return polylineView;
    } else if ([overlay isKindOfClass:[MAGroundOverlay class]]) {//图片
        MAGroundOverlayView *groundOverlayView = [[MAGroundOverlayView alloc] initWithGroundOverlay:overlay];
        return groundOverlayView;
    }
    //路线规划
    if ([overlay isKindOfClass:[MANaviPolyline class]]) {
        MANaviPolyline *naviPolyline = (MANaviPolyline *)overlay;
        MAPolylineView *polylineRenderer = [[MAPolylineView alloc] initWithPolyline:naviPolyline.polyline];
        if (naviPolyline.type == MANaviAnnotationTypeWalking) {//步行路线样式
            NSDictionary *walkStyle = [routeStyles dictValueForKey:@"walkLine" defaultValue:@{}];
            polylineRenderer.lineWidth = [walkStyle floatValueForKey:@"width" defaultValue:3];
            NSString *colorStr = [walkStyle stringValueForKey:@"color" defaultValue:@"#0000ee"];
            polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
            polylineRenderer.lineDash = [walkStyle boolValueForKey:@"lineDash" defaultValue:NO];
            NSString *strokeImg = [walkStyle stringValueForKey:@"strokeImg" defaultValue:nil];
            if (strokeImg.length > 0) {
                strokeImg = [self getPathWithUZSchemeURL:strokeImg];
                UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
                [polylineRenderer loadStrokeTextureImage:strokeImage];
            }
        } else if (naviPolyline.type == MANaviAnnotationTypeBus) {//公交路线样式
            NSDictionary *busStyle = [routeStyles dictValueForKey:@"busLine" defaultValue:@{}];
            polylineRenderer.lineWidth = [busStyle floatValueForKey:@"width" defaultValue:4];
            NSString *colorStr = [busStyle stringValueForKey:@"color" defaultValue:@"#00BFFF"];
            polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
            polylineRenderer.lineDash = [busStyle boolValueForKey:@"lineDash" defaultValue:NO];
            NSString *strokeImg = [busStyle stringValueForKey:@"strokeImg" defaultValue:nil];
            if (strokeImg.length > 0) {
                strokeImg = [self getPathWithUZSchemeURL:strokeImg];
                UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
                [polylineRenderer loadStrokeTextureImage:strokeImage];
            }
        } else {//驾车路线样式
            NSDictionary *driveStyle = [routeStyles dictValueForKey:@"driveLine" defaultValue:@{}];
            polylineRenderer.lineWidth = [driveStyle floatValueForKey:@"width" defaultValue:5];
            NSString *colorStr = [driveStyle stringValueForKey:@"color" defaultValue:@"#00868B"];
            polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
            polylineRenderer.lineDash = [driveStyle boolValueForKey:@"lineDash" defaultValue:NO];
            NSString *strokeImg = [driveStyle stringValueForKey:@"strokeImg" defaultValue:nil];
            if (strokeImg.length > 0) {
                strokeImg = [self getPathWithUZSchemeURL:strokeImg];
                UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
                [polylineRenderer loadStrokeTextureImage:strokeImage];
            }
        }
        return polylineRenderer;
    }
    if ([overlay isKindOfClass:[LineDashPolyline class]]) {//红绿灯时，左转弯路线断开部分
        MAPolylineView *polylineRenderer = [[MAPolylineView alloc] initWithPolyline:((LineDashPolyline *)overlay).polyline];
        NSDictionary *driveStyle = [routeStyles dictValueForKey:@"driveLine" defaultValue:@{}];
        polylineRenderer.lineWidth = [driveStyle floatValueForKey:@"width" defaultValue:5];
        NSString *colorStr = [driveStyle stringValueForKey:@"color" defaultValue:@"#00868B"];
        polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
        polylineRenderer.lineDash = [driveStyle boolValueForKey:@"lineDash" defaultValue:NO];
        NSString *strokeImg = [driveStyle stringValueForKey:@"strokeImg" defaultValue:nil];
        if (strokeImg.length > 0) {
            strokeImg = [self getPathWithUZSchemeURL:strokeImg];
            UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
            [polylineRenderer loadStrokeTextureImage:strokeImage];
        }
        return polylineRenderer;
    }
    //公交路线规划
    if ([overlay isKindOfClass:[MABusPolyline class]]) {
        MAPolylineView *polylineRenderer = [[MAPolylineView alloc] initWithPolyline:((MABusPolyline *)overlay).polyline];
        NSDictionary *lineStyle = [busLineStyles dictValueForKey:@"line" defaultValue:@{}];
        polylineRenderer.lineWidth = [lineStyle floatValueForKey:@"width" defaultValue:4];
        NSString *colorStr = [lineStyle stringValueForKey:@"color" defaultValue:@"#00BFFF"];
        polylineRenderer.strokeColor = [UZAppUtils colorFromNSString:colorStr];
        polylineRenderer.lineDash = [lineStyle boolValueForKey:@"lineDash" defaultValue:NO];
        NSString *strokeImg = [lineStyle stringValueForKey:@"strokeImg" defaultValue:nil];
        if (strokeImg.length > 0) {
            strokeImg = [self getPathWithUZSchemeURL:strokeImg];
            UIImage *strokeImage = [UIImage imageWithContentsOfFile:strokeImg];
            [polylineRenderer loadStrokeTextureImage:strokeImage];
        }
        return polylineRenderer;
    }
    return nil;
}
*/
#pragma mark 标注、气泡类代理
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation {
    ACGDAnnotaion *targetAnnot = (ACGDAnnotaion *) annotation;
    if ([targetAnnot isKindOfClass:[ACGDAnnotaion class]]) {
        static NSString *pointReuseIndetifier = @"pointReuseIndetifier";
        AnimatedAnnotationView *annotationView = (AnimatedAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndetifier];
        if (annotationView == nil) {
            annotationView = [[AnimatedAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndetifier];
        }
        annotationView.draggable = targetAnnot.draggable;
        //设置标注、布告牌
        [self processAnnotationView:targetAnnot withView:annotationView];
        //设置气泡
        if (targetAnnot.haveBubble) {
            [self setBubbleView:targetAnnot withView:annotationView];
        }
        return annotationView;
    } else if ([annotation isKindOfClass:[MAPointAnnotation class]]) {
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
        case ANNOTATION_MARKE: {//设置标注为自定义图标（动态）
            NSArray *pinIconPaths = annotation.pinIcons;
            NSString *pinIconPath = nil;
            if (pinIconPaths.count == 0) {//默认大头针图标
                pinIconPath = [[NSBundle mainBundle]pathForResource:@"res_aMap/redPin" ofType:@"png"];
            } else if (pinIconPaths.count == 1) {//自定义标注图标
                pinIconPath = [pinIconPaths firstObject];
            }
            UIImage *pinImage = [UIImage imageWithContentsOfFile:pinIconPath];
            pinImage = [self scaleImage:pinImage];
            if (pinImage) {
                annotationView.image = pinImage;
            }
            annotationView.centerOffset = CGPointMake(0, -annotationView.bounds.size.height/2.0);
        }
            break;
            
        case ANNOTATION_BILLBOARD: {//设置标注为布告牌
            if (annotationView.billboardView) {
                [self refreshBillboardView:annotation withAnnotationView:annotationView];
            } else {
                [self addBillboardView:annotation withAnnotationView:annotationView];
            }
            annotationView.centerOffset = CGPointMake(0, -annotationView.bounds.size.height/2.0);
        }
            break;
            
        case ANNOTATION_MOBILEGD: {//设置标注为可移动对象
            UIImage *pinImage = [UIImage imageNamed:@"res_aMap/mobile.png"];
            annotationView.image = pinImage;
            NSString *mobilePath = annotation.mobileBgImg;
            UIImage *mbileImage = [UIImage imageWithContentsOfFile:[self getPathWithUZSchemeURL:mobilePath]];
            CGRect mobileRect = CGRectMake(0, 0, mbileImage.size.width/2.0, mbileImage.size.height/2.0);
            UIImageView *mobileIcon = [[UIImageView alloc]init];
            mobileIcon.frame = mobileRect;
            mobileIcon.image = mbileImage;
            [annotationView addSubview:mobileIcon];
            mobileIcon.center = CGPointMake(annotationView.bounds.size.width/2.0, annotationView.bounds.size.height/2.0);
            mobileIcon.tag = ANNOTATION_MOBILETAG;
            annotationView.centerOffset = CGPointMake(0, 0);
        }
            break;
    }
}

- (void)mapView:(MAMapView *)mapView didSelectAnnotationView:(MAAnnotationView *)view {
    ACGDAnnotaion *target = (ACGDAnnotaion *)view.annotation;
    if (![target isKindOfClass:[ACGDAnnotaion class]]) {
        return;
    }
    if (target.clickCbId < 0) {
        return;
    }
    NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
    [sendDict setObject:[NSNumber numberWithInteger:target.annotId] forKey:@"id"];
    [sendDict setObject:@"click" forKey:@"eventType"];
    [self sendResultEventWithCallbackId:target.clickCbId dataDict:sendDict errDict:nil doDelete:NO];
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
            sendId = addBillboardCbid;
            [sendDict setObject:@"drag" forKey:@"eventType"];
            break;
            
        case ANNOTATION_MOBILEGD:
            sendId = addMobileAnnoCbid;
            break;
    }
    [sendDict setObject:state forKeyedSubscript:@"dragState"];
    [self sendResultEventWithCallbackId:sendId dataDict:sendDict errDict:nil doDelete:NO];
}

- (void)didMoving:(ACGDAnnotaion *)anno {
    anno.delegate = nil;
    anno.timeOffset = 0;
    NSString *moveId= [NSString stringWithFormat:@"%d",(int)anno.annotId];
    [_allMovingAnno removeObjectForKey:moveId];
    [self sendResultEventWithCallbackId:moveAnnoCbid dataDict:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:anno.annotId] forKey:@"id"] errDict:nil doDelete:NO];
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
    UIImageView *popView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, bubbleLong, 90)];
    popView.tag = BUBBLEVIEW_PAOVIEW;
    UIImage *imageBg = nil;
    if (bgImgPathStr.length > 0) {
        imageBg = [UIImage imageWithContentsOfFile:bgImgPathStr];
    } else {
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
            AMapAsyncImageView *asyImg = [[AMapAsyncImageView alloc]init];
            [asyImg loadImage:illusPath];
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
            [tap addTarget:self action:@selector(selectBubbleIllus:) forControlEvents:UIControlEventTouchDown];
            tap.tag = BUBBLEVIEW_ILLUSIMBTN;
            [illusImg addSubview:tap];
        }
        //添加气泡单击事件
        ACAMButton *tapContent = [ACAMButton buttonWithType:UIButtonTypeCustom];
        CGRect tapRect = CGRectMake(labelX, 10, 140, 60);
        tapContent.frame = tapRect;
        tapContent.btnId = annotaion.annotId;
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
            AMapAsyncImageView *asyImg = [popView viewWithTag:BUBBLEVIEW_ILLUSAS];
            [asyImg loadImage:illusPath];
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
            [tap addTarget:self action:@selector(selectBubbleIllus:) forControlEvents:UIControlEventTouchDown];
        }
        //添加气泡单击事件
        ACAMButton *tapContent = [popView viewWithTag:BUBBLEVIEW_CONTENTCK];
        CGRect tapRect = CGRectMake(labelX, 10, 140, 60);
        tapContent.frame = tapRect;
        tapContent.btnId = annotaion.annotId;
        [tapContent addTarget:self action:@selector(selectBubble:) forControlEvents:UIControlEventTouchDown];
    } else {
        labelX = 10;
        labelW = bubbleLong - 20;
        //添加气泡单击事件
        ACAMButton *tap = [popView viewWithTag:BUBBLEVIEW_CONTENTCK];
        tap.frame = popView.bounds;
        tap.btnId = annotaion.annotId;
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

- (void)setBubbleView:(ACGDAnnotaion *)annotation withView:(AnimatedAnnotationView *)annotationView {//自定义气泡
    if (annotationView.bubbleView) {
        [self refreshBubbleView:annotation withBubble:annotationView.bubbleView];
    } else {
        ACBubbleView *bubble = [self allocBubbleView:annotation];
        bubble.hidden = YES;
        annotationView.bubbleView = bubble;
    }
    annotationView.canShowCallout = NO;
}

- (void)selectBubble:(UIButton *)btn {//点击气泡上的内容图事件
    if (setBubbleCbid >= 0) {
        ACAMButton *targetBtn = (ACAMButton *)btn;
        NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [sendDict setObject:[NSNumber numberWithInteger:targetBtn.btnId] forKey:@"id"];
        [sendDict setObject:@"clickContent" forKey:@"eventType"];
        [self sendResultEventWithCallbackId:setBubbleCbid dataDict:sendDict errDict:nil doDelete:NO];
    }
}

- (void)selectBubbleIllus:(UIButton *)btn {//点击气泡上的插图事件
    if (setBubbleCbid >= 0) {
        ACAMButton *targetBtn = (ACAMButton *)btn;
        NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [sendDict setObject:[NSNumber numberWithInteger:targetBtn.btnId] forKey:@"id"];
        [sendDict setObject:@"clickIllus" forKey:@"eventType"];
        [self sendResultEventWithCallbackId:setBubbleCbid dataDict:sendDict errDict:nil doDelete:NO];
    }
}


- (void)addBillboardView:(ACGDAnnotaion *)annotation withAnnotationView:(AnimatedAnnotationView *)annotationView {
    //背景图片（160*75）
    UIView *mainBoard = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 160, 75)];
    mainBoard.backgroundColor = [UIColor clearColor];
    NSString *billImgPath = annotation.billBgImg;
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
    //样式参数获取
    NSDictionary *stylesInfo = annotation.stylesDict;
    NSString *aligment = [stylesInfo stringValueForKey:@"illusAlign" defaultValue:@"left"];
    NSString *titleColor = [stylesInfo stringValueForKey:@"titleColor" defaultValue:@"#000"];
    NSString *subTitleColor = [stylesInfo stringValueForKey:@"subTitleColor" defaultValue:@"#000"];
    float titleSize = [stylesInfo floatValueForKey:@"titleSize" defaultValue:16];
    float subtitleSize = [stylesInfo floatValueForKey:@"subTitleSize" defaultValue:12];
    //位置参数
    float labelW, labelH, labelX ,labelY;
    labelY = 10;
    labelH = 20;
    labelW = 100;
    //插图
    if (illusPath.length > 0) {
        CGRect rect;
        if ([illusPath hasPrefix:@"http"]) {
            AMapAsyncImageView *asyImg = [[AMapAsyncImageView alloc]init];
            asyImg.tag = BILLBOARD_ILLUS;
            [asyImg loadImage:illusPath];
            if (aligment.length>0 && [aligment isEqualToString:@"right"]) {
                rect = CGRectMake(115, 5, 35, 50);
                labelX = 10;
            } else {
                rect = CGRectMake(10, 5, 35, 50);
                labelX = 50;
            }
            asyImg.frame = rect;
            [mainBoard addSubview:asyImg];
        } else {
            NSString *realIllusPath = [self getPathWithUZSchemeURL:illusPath];
            UIImageView *illusImg = [[UIImageView alloc]init];
            illusImg.image = [UIImage imageWithContentsOfFile:realIllusPath];
            illusImg.tag = BILLBOARD_ILLUS;
            if (aligment.length>0 && [aligment isEqualToString:@"right"]) {
                rect = CGRectMake(115, 5, 35, 50);
                labelX = 10;
            } else {
                rect = CGRectMake(10, 5, 35, 50);
                labelX = 50;
            }
            illusImg.frame = rect;
            [mainBoard addSubview:illusImg];
        }
    } else {
        labelX = 10;
        labelW = 140;
    }
    //标题
    NSString *title = [contentInfo stringValueForKey:@"title" defaultValue:@""];
    UILabel *titleLab = [[UILabel alloc]initWithFrame:CGRectMake(labelX, labelY, labelW, labelH)];
    titleLab.text = title;
    titleLab.tag = BILLBOARD_TITLE;
    titleLab.backgroundColor = [UIColor clearColor];
    titleLab.font = [UIFont systemFontOfSize:titleSize];
    titleLab.textColor = [UZAppUtils colorFromNSString:titleColor];
    [mainBoard addSubview:titleLab];
    //子标题
    NSString *subTitle = [contentInfo stringValueForKey:@"subTitle" defaultValue:nil];
    UILabel *subTitleLab = [[UILabel alloc]initWithFrame:CGRectMake(labelX, labelY+labelH, labelW, labelH)];
    subTitleLab.text = subTitle;
    subTitleLab.tag = BILLBOARD_SUBTITLE;
    subTitleLab.backgroundColor = [UIColor clearColor];
    subTitleLab.font = [UIFont systemFontOfSize:subtitleSize];
    subTitleLab.textColor = [UZAppUtils colorFromNSString:subTitleColor];
    [mainBoard addSubview:subTitleLab];
    if (illusPath.length == 0) {
        titleLab.textAlignment = NSTextAlignmentCenter;
        subTitleLab.textAlignment = NSTextAlignmentCenter;
    }
    //添加插图单击事件
    ACAMButton *tap = [ACAMButton buttonWithType:UIButtonTypeCustom];
    tap.frame = mainBoard.bounds;
    tap.btnId = annotation.annotId;
    tap.tag = BILLBOARD_BUTTON;
    [tap addTarget:self action:@selector(selectBillboard:) forControlEvents:UIControlEventTouchDown];
    [mainBoard addSubview:tap];
}

- (void)refreshBillboardView:(ACGDAnnotaion *)annotation withAnnotationView:(AnimatedAnnotationView *)annotationView {
    //背景图片（160*75）
    UIView *mainBoard = annotationView.billboardView;
    NSString *billImgPath = annotation.billBgImg;
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
    //样式参数获取
    NSDictionary *stylesInfo = annotation.stylesDict;
    NSString *aligment = [stylesInfo stringValueForKey:@"illusAlign" defaultValue:@"left"];
    NSString *titleColor = [stylesInfo stringValueForKey:@"titleColor" defaultValue:@"#000"];
    NSString *subTitleColor = [stylesInfo stringValueForKey:@"subTitleColor" defaultValue:@"#000"];
    float titleSize = [stylesInfo floatValueForKey:@"titleSize" defaultValue:16];
    float subtitleSize = [stylesInfo floatValueForKey:@"subTitleSize" defaultValue:12];
    //位置参数
    float labelW, labelH, labelX ,labelY;
    labelY = 10;
    labelH = 20;
    labelW = 100;
    //插图
    if (illusPath.length > 0) {
        CGRect rect;
        if ([illusPath hasPrefix:@"http"]) {
            AMapAsyncImageView *asyImg = [mainBoard viewWithTag:BILLBOARD_ILLUS];
            [asyImg loadImage:illusPath];
            if (aligment.length>0 && [aligment isEqualToString:@"right"]) {
                rect = CGRectMake(115, 5, 35, 50);
                labelX = 10;
            } else {
                rect = CGRectMake(10, 5, 35, 50);
                labelX = 50;
            }
            asyImg.frame = rect;
        } else {
            NSString *realIllusPath = [self getPathWithUZSchemeURL:illusPath];
            UIImageView *illusImg = [mainBoard viewWithTag:BILLBOARD_ILLUS];
            illusImg.image = [UIImage imageWithContentsOfFile:realIllusPath];
            if (aligment.length>0 && [aligment isEqualToString:@"right"]) {
                rect = CGRectMake(115, 5, 35, 50);
                labelX = 10;
            } else {
                rect = CGRectMake(10, 5, 35, 50);
                labelX = 50;
            }
            illusImg.frame = rect;
        }
    } else {
        labelX = 10;
        labelW = 140;
    }
    //标题
    NSString *title = [contentInfo stringValueForKey:@"title" defaultValue:@""];
    UILabel *titleLab = [mainBoard viewWithTag:BILLBOARD_TITLE];
    titleLab.frame = CGRectMake(labelX, labelY, labelW, labelH);
    titleLab.text = title;
    titleLab.backgroundColor = [UIColor clearColor];
    titleLab.font = [UIFont systemFontOfSize:titleSize];
    titleLab.textColor = [UZAppUtils colorFromNSString:titleColor];
    //子标题
    NSString *subTitle = [contentInfo stringValueForKey:@"subTitle" defaultValue:nil];
    UILabel *subTitleLab = [mainBoard viewWithTag:BILLBOARD_SUBTITLE];
    subTitleLab.frame = CGRectMake(labelX, labelY+labelH, labelW, labelH);
    subTitleLab.text = subTitle;
    subTitleLab.backgroundColor = [UIColor clearColor];
    subTitleLab.font = [UIFont systemFontOfSize:subtitleSize];
    subTitleLab.textColor = [UZAppUtils colorFromNSString:subTitleColor];
    [mainBoard addSubview:subTitleLab];
    if (illusPath.length == 0) {
        titleLab.textAlignment = NSTextAlignmentCenter;
        subTitleLab.textAlignment = NSTextAlignmentCenter;
    }
    //添加插图单击事件
    ACAMButton *tap = [mainBoard viewWithTag:BILLBOARD_BUTTON];
    tap.frame = mainBoard.bounds;
    tap.btnId = annotation.annotId;
}

- (void)selectBillboard:(ACAMButton *)btn {
    if (addBillboardCbid >= 0) {
        ACAMButton *targetBtn = (ACAMButton *)btn;
        NSMutableDictionary *sendDict = [NSMutableDictionary dictionaryWithCapacity:1];
        [sendDict setObject:[NSNumber numberWithInteger:targetBtn.btnId] forKey:@"id"];
        [sendDict setObject:@"click" forKey:@"eventType"];
        [self sendResultEventWithCallbackId:addBillboardCbid dataDict:sendDict errDict:nil doDelete:NO];
    }
}

- (void)doStep {
    if (_allMovingAnno.count == 0) {
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
    // 使当前的context出堆栈
    UIGraphicsEndImageContext();
    //返回新的改变大小后的图片
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
        NSLog(@"******************:%zi",path.steps.count);
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

@end
