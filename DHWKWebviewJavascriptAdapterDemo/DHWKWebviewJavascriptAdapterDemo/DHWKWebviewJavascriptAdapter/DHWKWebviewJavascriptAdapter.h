//
//  DHWKWebviewJavascriptAdapter.h
//  DHWKWebviewJavascriptAdapterDemo
//
//  Created by Daniel on 2020/10/7.
//  Copyright © 2020 Daniel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN
@protocol DHJavascriptExport;

/// js中间件扩展
@interface WKUserContentController (DHJavascriptExtension)
/// 需要监听的js消息
@property (nonatomic, strong, readonly) NSMutableArray *dh_registerScriptMessage;
/// 需要注入的js
@property (nonatomic, strong, readonly) NSMutableArray *dh_injectedJavascript;

/// 注册中间对象，可注册多个中间件
///
/// @discussion 中间对象决定需要注入的方法名，js定义标记决定要注册的方法名
/// @param middleware 中间件对象，想要关联方法则需要在对象遵循DHJavascriptExport的子协议（自定义继承协议）中声明方法
- (void)dh_registerMiddleware:(id<DHJavascriptExport>)middleware;

/// 移除所有监听脚本消息名
/// @attention 注意消除时机，不使用此方法也行，务必使用dh_registerScriptMessage遍历移除
- (void)dh_removeAllScriptMessageHandler;

@end

/// WKWebView扩展
@interface WKWebView (DHJavascriptExtension)

/// 如有必要注入所需脚本，一般写在webview:didFinishNavigation:中
///
/// @discussion 当定义了宏 DH_WKWEBVIEW_NOT_SWIZZLING 此方法才会生效
- (void)dh_injectJavascriptIfNeed;

@end


@protocol DHJavascriptExport <NSObject>
@optional
/// js识别标记名，实现此方法将注入识别标记名等价方法，且所有实现的方法名将替换
/// @attention 必须与javascriptReplacedMethods同时使用才会有意义
+ (NSString *)dh_javascriptIdentifier;

/**
 @brief 是否所有的都需要替换，默认为YES

 @discussion 当+dh_javascriptIdentifier有效返回时，此方法才会生效，生效后将可能缓存需要注入替换的js。
 当js不存在完整的调用方法（例：window.webkit.messageHandlers.methodName.postMessage('");） 时，则此方法应该返回YES；
 当不存在不完整的调用方法（例：daniel.methodName("");）时，则可不实现+dh_javascriptIdentifier或此方法返回NO；
 当上述两种调用方式都存在的情况下，则需要实现+dh_javascriptIdentifier且此方法返回NO，另需要在+dh_javascriptNeedNotReplacedMethod中返回无需替换的方法名（即上述 完整的调用方法的方法名）
 */
+ (BOOL)dh_javascriptAllNeedReplacedMethod;

/// 不需要替换的方法名（即在js中使用window.webkit.messageHandlers.methodName.postMessage("");发送的方法名）
/// @attention 方法名必须填写完整的方法，并且在冒号之前的方法名与js中的方法名匹配
/// 例如：
/// method 对应 window.webkit.messageHandlers.method.postMessage("");
/// methodWithParam1:param2: 对应 window.webkit.messageHandlers.methodWithParam1.postMessage("");
+ (NSArray *)dh_javascriptNeedNotReplacedMethod;

/// 额外需要注入的js数组
+ (NSArray *)dh_javascriptExtendInject;

@end

NS_ASSUME_NONNULL_END
