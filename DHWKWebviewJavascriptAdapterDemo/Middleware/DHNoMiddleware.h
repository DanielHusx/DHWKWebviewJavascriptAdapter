//
//  DHNoMiddleware.h
//  DHWKWebviewJavascriptAdapterDemo
//
//  Created by Daniel on 2020/10/7.
//  Copyright © 2020 Daniel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DHWKWebviewJavascriptAdapter.h"

NS_ASSUME_NONNULL_BEGIN
@protocol DHNoMiddlewareExport <DHJavascriptExport>
/// 接收参数的形式
- (void)noMiddleware_singleObj:(id)param;
/// 多参数形式
- (void)noMiddleware_arrayWithP1:(id)p1 p2:(id)p2;
/// 不接收参数的形式
- (void)noMiddleware_noParam;
/// 与替换中间件同名方法
- (void)commonMiddleware_noParam;

@end

@interface DHNoMiddleware : NSObject <DHNoMiddlewareExport>

@end

NS_ASSUME_NONNULL_END
