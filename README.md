# DHWKWebviewJavascriptAdapter
仿照JSContext的处理方式，适用于WKWebview的JS中间件处理



优点：

- 优雅的替换UIWebview的JSContext中间件
- 简单易用，耦合性低



## 集成方式

```objective-c
pod 'DHWKWebviewJavascriptAdapter'
```



## 使用方法

1. 创建继承 `DHJavascriptExport` 的协议再创建中间件并遵循该协议

   ```objective-c
   #import "DHWKWebviewJavascriptAdapter.h"
   @protocol DHMiddlewareExport <DHJavascriptExport>
   /// js对应方法名为methodName
   - (void)methodName:(id)param;
   @end
     
   @interface DHMiddleware : NSObject <DHMiddlewareExport>
   @end
   @implementation DHMiddleware
   + (DHJavascriptBridgeType)dh_javascriptBridgeType { 
     return DHJavascriptBridgeType_AllNeed; 
   }
   - (void)methodName:(id)param {...} 
   @end
   ```

   

2. 使用`-dh_registerMiddleware:`注册中间件对象

   ```objective-c
   // 不一定要写在-webView:didFinishNavigation:内
   [webView.configuration.userContentController dh_registerMiddleware:[[DHMiddleware alloc] init]];
   ```



3. 设置`webView.navigationDelegate`且实现`-webView:didFinishNavigation:`



## 应用场景

```js
> 适用于javascript与iOS的交互场景

> js
// 正常与iOS发送信息的方式
window.webkit.messageHandlers.jsMethodName.postMessage("");

> oc
// DHMiddleware.m
+ (DHJavascriptBridgeType)dh_javascriptBridgeType { 
  return DHJavascriptBridgeType_AllNotNeed; 
}
// 以下两个方法都可作为响应
// 请勿同时定义在协议内！一旦都注册，将随机一直响应其中一个方法（基于遍历协议方法列表的先后顺序）
- (void)jsMethodName:(id)param {...} 
- (void)jsMethodName {...}

#################################
#################################

> js
// 定义中间件发送信息的方法
window.dh_identifity.jsMethodNameWithP1P2P3("p1", "p2", "p3");

> oc
// DHMiddleware.m
+ (NSString *)dh_javascriptIdentifier {
   return @"dh_identifity";
}
+ (DHJavascriptBridgeType)dh_javascriptBridgeType { 
  return DHJavascriptBridgeType_AllNeed; 
}
// 以下四个方法都可作为响应
// 请勿同时定义在协议内！一旦都注册，将随机一直响应其中一个方法（基于遍历协议方法列表的先后顺序）
// js传递过来将作为数组参数接收
- (void)jsMethodNameWithP1P2P3:(id)params {...}
// 参数将依次接收
- (void)jsMethodNameWithP1:(id)p1 p2:(id)p2 p3:(id)p3;
// js传递过来的参数将抛弃p3参数
- (void)jsMethodNameWithP1:(id)p1 p2P3:(id)p2  {...}
// js传递过来的参数将抛弃p3参数
- (void)jsMethodNameWithP1P2:(id)p1 p3:(id)p2  {...}

```



## 处理机制

- oc方法名对应js方法以`:`分割，后续以首字母大写进行拼接，例：oc方法`myMethod:param:`对应js方法`myMethodParam`
- 对于js自定义标识发消息的方式，oc会注入等价方法的js，oc维护相关js的注入以及匹配对应oc方法的缓存池



## 已知问题

- 当同一类存在多个对象时，替换方法将只在该类第一个对象生效后续的对象将不注入脚本。
  - 例如：存在网页控制器DHWebview，跳转到下一个DHWebview，后续将不再注入脚本
  - 解决方案：
    1. 全局定义宏`DH_WKWEBVIEW_NOT_SWIZZLING`
    2. 在`-webView:didFinishNavigation:`中使用`-dh_injectJavascriptIfNeed`进行手动注入