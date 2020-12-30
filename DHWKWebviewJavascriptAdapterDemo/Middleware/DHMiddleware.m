//
//  DHMiddleware.m
//  DHWKWebviewJavascriptAdapterDemo
//
//  Created by Daniel on 2020/10/7.
//  Copyright © 2020 Daniel. All rights reserved.
//

#import "DHMiddleware.h"

@implementation DHMiddleware

#pragma mark - DHJavascriptExport
+ (NSString *)dh_javascriptIdentifier {
    return @"danielMiddlewareId";
}

+ (DHJavascriptBridgeType)dh_javascriptBridgeType {
    return DHJavascriptBridgeType_NotAllNeed;
}

+ (NSArray *)dh_javascriptNeedNotBridgeMethodNames {
    return @[
        NSStringFromSelector(@selector(middleware_notReplacedWithP1:p2:)),
        // 同名方法如果不注入，那么就是重复方法，那将会导致某一个不生效
//        NSStringFromSelector(@selector(commonMiddleware_noParam))
    ];
}

+ (NSArray *)dh_javascriptExtendInject {
    return @[@"alert('这是额外注入的脚本');"];
}

#pragma mark - DHMiddlewareExport
/// 不接收参数的形式
- (void)middleware_noParam {
    [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s", self, __PRETTY_FUNCTION__]];
}

/// 接收参数的形式
- (void)middleware_singleObj:(id)param {
   [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s \nreceived: [(class:%@)%@]", self, __PRETTY_FUNCTION__, NSStringFromClass([param class]), param]];
}

/// 多参数形式
- (void)middleware_mutiObjWithP1:(id)p1 p2:(id)p2 {
    [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s \nreceived: [p1:(class:%@)%@]; [p2:(class:%@)%@]]", self, __PRETTY_FUNCTION__, NSStringFromClass([p1 class]), p1, NSStringFromClass([p2 class]), p2]];
}

/// 同名方法响应
- (void)middleware_sameMethodName:(id)param {
    [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s \nreceived: [(class:%@)%@]", self, __PRETTY_FUNCTION__, NSStringFromClass([param class]), param]];
}

/// 不替换方法
- (void)middleware_notReplacedWithP1:(id)p1 p2:(id)p2 {
    [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s \nreceived: [p1:(class:%@)%@]; [p2:(class:%@)%@]]", self, __PRETTY_FUNCTION__, NSStringFromClass([p1 class]), p1, NSStringFromClass([p2 class]), p2]];
}

- (void)middleware_mutiObjWithP1P2:(id)p1 {
    [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s \nreceived: [p1:(class:%@)%@];]", self, __PRETTY_FUNCTION__, NSStringFromClass([p1 class]), p1]];
}

/// 与无替换中间件同名方法
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
