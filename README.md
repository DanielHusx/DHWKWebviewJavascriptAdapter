# DHWKWebviewJavascriptAdapter
适用于WKWebview的JS中间件处理



优点：

- 优雅的替换UIWebview的中间件
- 简单易用，耦合性低



## 使用方法

1. 创建继承 `DHJavascriptExport` 的协议再创建中间件并遵循该协议中间件。实现新协议方法，并根据所需，选择性实现 `DHJavascriptExport` 的类方法

   ```objective-c
   #import "DHWKWebviewJavascriptAdapter.h"
   @protocol DHMiddlewareExport <DHJavascriptExport>
   /// js对应方法名为methodName
   - (void)methodName:(id)param;
   @end
     
   @interface DHMiddleware : NSObject <DHMiddlewareExport>
   @end
   @implementation DHMiddleware
   + (BOOL)dh_javascriptAllNeedReplacedMethod { return YES; }
   - (void)methodName:(id)param {...} 
   @end
   ```

   

2. 使用`-dh_registerMiddleware:`注册中间件对象

   ```objective-c
   [webView.configuration.userContentController dh_registerMiddleware:[[DHMiddleware alloc] init]];
   ```



3. 设置`webView.navigationDelegate`且实现`-webView:didFinishNavigation:`即可



## 应用场景

- iOS使用WKWebview，而JS使用`window.webkit.messageHandlers.methodName.postMessage('');` 或类似定义`window.middlewareId.methodName('');`的方式发送消息



## 注意点

1. 当同一类存在多个对象时，替换方法将只在该类第一个对象生效后续的对象将不注入脚本。
   - 解决方案：需要手动全局定义宏`DH_WKWEBVIEW_NOT_SWIZZLING`然后在`-webView:didFinishNavigation:`中使用`-dh_injectJavascriptIfNeed`进行手动注入