//
//  DHMiddleware.h
//  DHWKWebviewJavascriptAdapterDemo
//
//  Created by Daniel on 2020/10/7.
//  Copyright © 2020 Daniel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DHWKWebviewJavascriptAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DHMiddlewareExport <DHJavascriptExport>
/// 不接收参数的形式
- (void)middleware_noParam;
/// 接收参数的形式
- (void)middleware_singleObj:(id)param;
/// 多参数形式
- (void)middleware_mutiObjWithP1:(id)p1 p2:(id)p2;
/// js中存在同名方法时响应
- (void)middleware_sameMethodName:(id)param;
/// 不替换方法
- (void)middleware_notReplacedWithP1:(id)p1 p2:(id)p2;
@end

@interface DHMiddleware : NSObject <DHMiddlewareExport>

@end

NS_ASSUME_NONNULL_END
