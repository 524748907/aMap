//
//  ACDistrictSearch.h
//  UZApp
//
//  Created by 孙政篡 on 2017/9/5.
//  Copyright © 2017年 APICloud. All rights reserved.
//

#import <AMapSearchKit/AMapSearchKit.h>

@interface ACDistrictSearch : AMapDistrictSearchRequest

@property (nonatomic, assign) BOOL showInMap;
@property (nonatomic, assign) NSInteger searchResultCbid;

@end
