//
//  ViewController.m
//  DHWKWebviewJavascriptAdapterDemo
//
//  Created by Daniel on 2020/10/7.
//  Copyright © 2020 Daniel. All rights reserved.
//

#import "ViewController.h"
#import "DHWKWebviewJavascriptAdapter.h"
#import "DHNoMiddleware.h"
#import "DHMiddleware.h"

@interface ViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>
/// WKWebview
@property (nonatomic, strong) WKWebView *webView;
@end

@implementation ViewController
#pragma mark - life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // 初始化 webview
    [self setupWebview];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // 加载html请求
    [self loadRequest];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // 移除所有脚本监听
    [self.webView.configuration.userContentController dh_removeAllScriptMessageHandler];
}


#pragma mark - private method
- (void)setupWebview {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    WKUserContentController *userContent = [[WKUserContentController alloc] init];
    // 注册脚本中间件
    [self registerScriptWithUserContentController:userContent];
    config.userContentController = userContent;
    WKPreferences *preferences = [[WKPreferences alloc] init];
    preferences.javaScriptEnabled = YES;
    config.preferences = preferences;
    
    WKWebView *webview = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    [self.view addSubview:webview];
    
    _webView = webview;
    _webView.navigationDelegate = self;
    _webView.UIDelegate = self;
}

- (void)loadRequest {
    NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"Test" ofType:@"html"];
    NSString *htmlString = [[NSString alloc] initWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
    
    [self.webView loadHTMLString:htmlString baseURL:nil];
}

- (void)registerScriptWithUserContentController:(WKUserContentController *)userContentController {
    // 虽然可以注册两个中间件，但是注意方法名勿重复
    [userContentController dh_registerMiddleware:[[DHNoMiddleware alloc] init]];
    [userContentController dh_registerMiddleware:[[DHMiddleware alloc] init]];
    // 自定义监听的方法
    [userContentController addScriptMessageHandler:self name:@"vendorUserHandler"];
}


#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"%@ invoke %s", NSStringFromClass(self.class), __PRETTY_FUNCTION__);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"%@ invoke %s", NSStringFromClass(self.class), __PRETTY_FUNCTION__);
}


#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    NSLog(@"%@ didReceiveScriptMessage: [name:%@] [body:%@]", NSStringFromClass(self.class), message.name, message.body);
    [self showAlertForMessage:[NSString stringWithFormat:@"%@ invoke %s name:%@, body:%@", self, __PRETTY_FUNCTION__, message.name, message.body]];
}


#pragma mark - WKUIDelegate
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }])];
    
    [self presentViewController:alertController animated:YES completion:nil];
    
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message?:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }])];
    [alertController addAction:([UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }])];
    
    [self presentViewController:alertController animated:YES completion:nil];
}
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:prompt message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.text = defaultText;
    }];
    [alertController addAction:([UIAlertAction actionWithTitle:@"完成" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(alertController.textFields[0].text?:@"");
    }])];

    [self presentViewController:alertController animated:YES completion:nil];
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
