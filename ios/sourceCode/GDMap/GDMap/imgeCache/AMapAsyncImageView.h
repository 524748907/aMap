//
//  AMapAsyncImageView.h
//  Part of ASIHTTPRequest -> http://allseeing-i.com/ASIHTTPRequest
//
//  Created by Ben Copsey on 01/05/2010.
//  Copyright 2010 All-Seeing Interactive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UZASIHTTPRequest.h"
#import <CommonCrypto/CommonDigest.h>

@interface AMapAsyncImageView : UIImageView
<ASIHTTPRequestDelegate>

@property (nonatomic,retain) UZASIHTTPRequest *request;
@property (nonatomic) BOOL needClip;

- (void) loadImage:(NSString *)imageURL;
- (void) loadImage:(NSString *)imageURL withPlaceholdImage:(UIImage *)image;
- (void) cancelDownload;

@end
