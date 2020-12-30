//
//  DHNoMiddleware.m
//  DHWKWebviewJavascriptAdapterDemo
//
//  Created by Daniel on 2020/10/7.
//  Copyright © 2020 Daniel. All rights reserved.
//

#import "DHNoMiddleware.h"

@implementation DHNoMiddleware

#pragma mark - DHJavascriptExport
+ (DHJavascriptBridgeType)dh_javascriptBridgeType {
    return DHJavascriptBridgeType_AllNotNeed;
}

#pragma mark - DHNoMiddlewareExport
/// 接收参数的形式
- (void)noMiddleware_singleObj:(id)param {
    [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s \nreceived: [(class:%@)%@]", self, __PRETTY_FUNCTION__, NSStringFromClass([param class]), param]];
}

/// 多参数形式
- (void)noMiddleware_arrayWithP1:(id)p1 p2:(id)p2 {
    [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s \nreceived: [p1:(class:%@)%@]; [p2:(class:%@)%@]]", self, __PRETTY_FUNCTION__, NSStringFromClass([p1 class]), p1, NSStringFromClass([p2 class]), p2]];
}

/// 不接收参数的形式
- (void)noMiddleware_noParam {
    [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s", self, __PRETTY_FUNCTION__]];
}

/// 与替换中间件同名方法
- (void)commonMiddleware_noParam {
    [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s", self, __PRETTY_FUNCTION__]];
}

#pragma mark - other
- (void)showAlertForMessage:(NSString *)message {
    NSLog(@"%@", message);
    
    UIWindow *keyWindow;
    if (@available(iOS 13.0, *)) {
        keyWindow = [[UIApplication sharedApplication].windows lastObject];
    } else {
        keyWindow = [UIApplication sharedApplication].keyWindow;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSStringFromClass(self.class) message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }])];
    
    [keyWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
}

@end
