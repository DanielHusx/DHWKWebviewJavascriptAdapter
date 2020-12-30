//
//  DHWKWebviewJavascriptAdapter.m
//  DHWKWebviewJavascriptAdapterDemo
//
//  Created by Daniel on 2020/10/7.
//  Copyright © 2020 Daniel. All rights reserved.
//

#import "DHWKWebviewJavascriptAdapter.h"
#import <objc/runtime.h>
#import <objc/objc.h>
#import <objc/message.h>

// ################################################
// MARK: - DHWebviewJavascriptUtils实用类
// ################################################
@interface DHWebviewJavascriptUtils : NSObject

@end

@implementation DHWebviewJavascriptUtils

/// 获取子协议(遵循DHJavascriptExport协议)的所有方法
+ (NSArray *)dh_instanceMethodsForClass:(Class)cls {
    return [DHWebviewJavascriptUtils dh_instanceMethodsForClass:cls
                                                   baseProtocol:@protocol(DHJavascriptExport)];
}

/// 获取子协议(遵循protocolString协议)的所有方法
/// @param cls class
/// @param baseProtocol 基协议
+ (NSArray *)dh_instanceMethodsForClass:(Class)cls baseProtocol:(Protocol *)baseProtocol {
    // 基协议
    if (!class_conformsToProtocol(cls, baseProtocol)) { return nil; }
    
    // 获取类所遵循的协议列表，去查找符合protocolString的子协议
    unsigned int protocolCount;
    Protocol * __unsafe_unretained *protocol_list = class_copyProtocolList(cls, &protocolCount);
    Protocol *conformedProtocol;
    for (int i = 0; i < protocolCount; i++) {
        if (protocol_conformsToProtocol(protocol_list[i], baseProtocol)
            && !protocol_isEqual(protocol_list[i], baseProtocol)) {
            conformedProtocol = protocol_list[i];
            break;
        }
    }
    free(protocol_list);
    // 未查找到遵循的基协议的子协议
    if (!conformedProtocol) { return nil; }
    
    // 循环遍历协议所遵循的协议列表，以获得所有定义的方法列表
    NSMutableSet *methodList = [NSMutableSet set];
    [self traverseSuperProtocolsForMethodsWithProtocol:conformedProtocol baseProtocol:baseProtocol methods:methodList];
    
    return [methodList allObjects];
}

/// 遍历父协议直到基协议获取所有方法
///
/// @param protocol 协议
/// @param baseProtocol 基协议
/// @param methods 方法集合
+ (void)traverseSuperProtocolsForMethodsWithProtocol:(Protocol *)protocol baseProtocol:(Protocol *)baseProtocol methods:(NSMutableSet *)methods {
    // 当协议不遵循基协议或等于基协议时跳出循环
    if (!protocol_conformsToProtocol(protocol, baseProtocol)) { return ; }
    if (protocol_isEqual(protocol, @protocol(NSObject))) { return ; }
    if (protocol_isEqual(protocol, baseProtocol)) { return ; }
    
    // 获取子协议的方法（必要(require)且是实例方法）列表
    unsigned int count;
    struct objc_method_description *protocol_method_list = protocol_copyMethodDescriptionList(protocol, YES, YES, &count);
    
    for (int i = 0; i < count; i ++) {
        SEL sel = protocol_method_list[i].name;
        [methods addObject:@(sel_getName(sel))];
    }
    free(protocol_method_list);
    
    // 遍历父协议
    unsigned int protocolCount;
    Protocol * __unsafe_unretained *protocol_list = protocol_copyProtocolList(protocol, &protocolCount);
    for (int i = 0; i < protocolCount; i++) {
        [self traverseSuperProtocolsForMethodsWithProtocol:protocol_list[i] baseProtocol:baseProtocol methods:methods];
    }
    free(protocol_list);
}

/// 调用实例方法
///
/// @param obj 实例对象
/// @param originalMethodName 原生方法名
/// @param parameter 参数 NSNumber, NSString, NSDate, NSArray, NSNull, NSDictionary
+ (void)dh_invokeInstanceMethodForObject:(NSObject *)obj
                  withOriginalMethodName:(NSString *)originalMethodName
                               parameter:(id)parameter {
    if (!obj) { return; }
    if (![DHWebviewJavascriptUtils isValidString:originalMethodName]) { return; }
    if (![obj respondsToSelector:NSSelectorFromString(originalMethodName)]) { return; }
    
    // 以下开始调用匿名方法
    SEL sel = NSSelectorFromString(originalMethodName);//sel_getUid(originalMethodName.UTF8String);
    Method m = class_getInstanceMethod([obj class], sel);
    unsigned int argumentsCount = method_getNumberOfArguments(m) - 2;
    BOOL multiableArgument = argumentsCount > 1;
    BOOL needArgument = argumentsCount >= 1;
    
    NSMethodSignature *signature = [obj methodSignatureForSelector:sel];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = obj;
    invocation.selector = sel;
    
    // 匹配方法名的顺序进行赋值
    // NSNumber, NSString, NSDate, NSArray, NSNull, NSDictionary
    if ([parameter isKindOfClass:[NSArray class]] && multiableArgument) {
        NSUInteger parameterElementCount = [parameter count];
        for (NSInteger i = 0; i < argumentsCount && i < parameterElementCount; i++) {
            id argument = parameter[i];
            [invocation setArgument:&argument atIndex:i+2];
        }
    } else if ([parameter isKindOfClass:[NSDictionary class]] && multiableArgument) {
        NSArray *parameterKeys = [originalMethodName componentsSeparatedByString:@":"];
        // 接收的方法名是多参数，参数又是字典时，只有当字典key与方法名分段匹配时才分配对应参数
        // 否则直接分配给第一个
        BOOL hasMatchedKey = NO;
        for (NSInteger i = 0; i < [parameterKeys count]; i++) {
            id argument = parameter[parameterKeys[i]];
            if (!argument) { continue; }
            hasMatchedKey = YES;
            
            [invocation setArgument:&argument atIndex:i+2];
        }
        if (!hasMatchedKey) {
            id argument = parameter;
            [invocation setArgument:&argument atIndex:2];
        }
    } else if (needArgument) {
        id argument = parameter;
        [invocation setArgument:&argument atIndex:2];
    }
    
    [invocation invoke];
}

/// 通过js方法名查找对应响应的方法
+ (NSString *)dh_findMatchedOriginalMethodNameForReceiver:(NSObject *)receiver
                                         withJSMethodName:(NSString *)jsMethodName
                                                parameter:(id)parameter {
    if (!receiver) { return nil; }
    // 集合类型参数，可支持多类型参数
    NSUInteger aspectArgumentCount = 1;
    BOOL multiableArgument = NO;
    if ([parameter isKindOfClass:[NSArray class]] || [parameter isKindOfClass:[NSDictionary class]]) {
        aspectArgumentCount = [parameter count];
        multiableArgument = YES;
    }
   
    __block NSString *result;
    NSArray *protocolMethods = [DHWebviewJavascriptUtils dh_instanceMethodsForClass:receiver.class];
    
    [protocolMethods enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        @autoreleasepool {
            NSString *currentJSMethodName = [DHWebviewJavascriptUtils dh_convertOriginalMethodNameToJSMethodName:obj];
            if ([currentJSMethodName isEqualToString:jsMethodName]) {
                // 查找到对应方法，因为是协议方法可能未实现
                if ([receiver respondsToSelector:NSSelectorFromString(obj)]) {
                    Method method = class_getInstanceMethod(receiver.class, NSSelectorFromString(obj));
                    unsigned int argumentCount = method_getNumberOfArguments(method) - 2;
                    if (argumentCount == 0
                        || (argumentCount == 1 && multiableArgument)
                        || (argumentCount == aspectArgumentCount)) {
                        result = obj;
                        *stop = YES;
                    }
                }
            }
        }
        
    }];
    /*
    // 此代码是遍历类下所有方法，理论上只要协议的方法即可
     
    NSString *result;
    // 匹配方法名前缀一致 且参数个数匹配的方法名
    unsigned int count;
    Method *methods = class_copyMethodList([receiver class], &count);

    for (int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *methodName = @(sel_getName(sel));
        // 匹配方法名
        NSString *currentJSMethodName = [self dh_convertOriginalMethodNameToJSMethodName:methodName];
        if (![currentJSMethodName isEqualToString:jsMethodName]) {
            continue;
        }
        // 参数个数必须匹配 (target, SEL, argument1, ...)
        unsigned int argumentCount = method_getNumberOfArguments(methods[i]) - 2;
        // 不需要参数，只要名字匹配即可；
        // 方法的参数个数为1，且参数为集合类型，可匹配；
        // 方法的参数个数 与 期望参数个数相等
        if (argumentCount == 0
            || (argumentCount == 1 && multiableArgument)
            || (argumentCount == aspectArgumentCount)) {
            result = methodName;
            break;
        }

    }
    free(methods);
     */
    
    return result;
}

/// 判定原生方法名以及参数类型，是否匹配
+ (NSString *)dh_matchedOriginalMethodNameForReceiver:(NSObject *)receiver
                               withOriginalMethodName:(NSString *)originalMethodName
                                            parameter:(id)parameter {
    if (!receiver) { return nil; }
    // 集合类型参数，可支持多类型参数
    NSUInteger aspectArgumentCount = 1;
    BOOL multiableArgument = NO;
    if ([parameter isKindOfClass:[NSArray class]] || [parameter isKindOfClass:[NSDictionary class]]) {
        aspectArgumentCount = [parameter count];
        multiableArgument = YES;
    }
    NSString *result;
    
    SEL sel = NSSelectorFromString(originalMethodName);
    if (![receiver respondsToSelector:sel]) { return nil; }

    Method method = class_getInstanceMethod([receiver class], sel);
    unsigned int argumentCount = method_getNumberOfArguments(method) - 2;
    if (argumentCount == 0
        || (argumentCount == 1 && multiableArgument)
        || (argumentCount == aspectArgumentCount)) {
        result = originalMethodName;
    }
    return result;
}

/// 有效字符串
+ (BOOL)isValidString:(NSString *)str {
    if (![str isKindOfClass:[NSString class]]) { return NO; }
    if (str.length == 0) { return NO; }
    return YES;
}

/// myMethod:param: => myMethodParam
+ (NSString *)dh_convertOriginalMethodNameToJSMethodName:(NSString *)name {
    if (![self isValidString:name]) { return nil; }
    
    NSArray *components = [name componentsSeparatedByString:@":"];
    NSMutableString *result = [components.firstObject mutableCopy];
    for (NSUInteger i = 1; i < [components count]; i++) {
        [result appendString:[components[i] capitalizedString]];
    }
    return [result copy];
}

/// myMethod:param: => [@"myMethod", @"param"]
+ (NSArray *)dh_methodParametersName:(NSString *)name {
    if (![self isValidString:name]) { return @[]; }
    NSMutableArray *temp = [[name componentsSeparatedByString:@":"] mutableCopy];
    // 移除所有为空字符串的对象
    [temp removeObject:@""];
    return [temp copy];
}

@end

// MARK: -
@implementation DHWebviewJavascriptUtils (Javascript)
/// 替换方法的js，其中method与replaceMethod必须不一致
/// @attention 替换方法名如已存在同名冲突，虽然能注入，但不会生效
/// @param identifier 标记名
/// @param originalMethodName oc原生方法名，例：myMethod:param:
/// @param jsMethodName js响应方法名 ，例：myMethodParam
/// @param jsReplacedMethodName js替换方法名，例：myMethodParam_my_tag
/// @return 注入的js
+ (NSString *)dh_javascriptForIdentifier:(NSString *)identifier
                      originalMethodName:(NSString *)originalMethodName
                            jsMethodName:(NSString *)jsMethodName
                    jsReplacedMethodName:(NSString *)jsReplacedMethodName {
    if (![DHWebviewJavascriptUtils isValidString:identifier]) { return nil; }
    if (![DHWebviewJavascriptUtils isValidString:jsMethodName]) { return nil; }
    if (![DHWebviewJavascriptUtils isValidString:originalMethodName]) { return nil; }
    if (![DHWebviewJavascriptUtils isValidString:jsReplacedMethodName]) { return nil; }
    // 如果js方法名与替换的一致将导致方法无法触发App方法
    if ([jsMethodName isEqualToString:jsReplacedMethodName]) { return nil; }
    /*
     实现以下
     identifier.replacedMethod = function(param) {
        let message = param;
        webkit.webkit.messageHandlers.method.postMessage(message);
     }
     */
    NSString *methodName = jsMethodName;
    NSArray *methodParameters = [self dh_methodParametersName:originalMethodName];
    NSString *replacedMethodName = jsReplacedMethodName;
    
    // 识别替换的变量 identifier.replacedMethod
    NSString *variable = [self dh_javascriptForIdentifier:identifier method:methodName];
    
    /* 函数
     function(param) {
        let message = param;// 字典以方法名分割处理
        webkit.webkit.messageHandlers.method.postMessage(message);
     }
     */
    NSString *function = [self dh_javascriptForFunctionImplementationWithMethodName:replacedMethodName
                                                                     parameterNames:methodParameters];
    
    // 最后的组装
    return [self dh_javascriptForVariable:variable functionImplementation:function];
}

/// identifier = webkit.messageHandlers;
+ (NSString *)dh_javascriptForIdentifier:(NSString *)identifier {
    // 中间件标识，其实没必要是 webkit.messageHandlers，对于网页来说，只要是挂载在window下的对象即可
    return [NSString stringWithFormat:@"%@ = new Object();", identifier];
//    return [NSString stringWithFormat:@"%@ = webkit.messageHandlers;", identifier];
}

/// identifier.myMethod
+ (NSString *)dh_javascriptForIdentifier:(NSString *)identifier method:(NSString *)method {
    return [NSString stringWithFormat:@"%@.%@", identifier, method];
}

/// function(param, param1, ...) {...}
+ (NSString *)dh_javascriptForFunctionImplementationWithMethodName:(NSString *)methodName
                                                    parameterNames:(NSArray *)parameterNames  {
    // 如果为空，则传null
    NSString *functionParams = nil;
    NSString *message = nil;
    if ([parameterNames count] <= 1) {
        // NSNumber, NSString, NSDate, NSArray, NSNull
        functionParams = @"param"; //parameterNames.firstObject?:@"param";
        message = functionParams;
    } else {
        // NSDictionary
        // 将分割的方法名作为参数名，以匹配相应参数顺序值
        functionParams = [[parameterNames componentsJoinedByString:@","] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
        
        NSMutableArray *keyValues = [NSMutableArray arrayWithCapacity:parameterNames.count];
        for (NSString *name in parameterNames) {
            if (name.length == 0) { continue; }
            [keyValues addObject:[NSString stringWithFormat:@"\"%@\":%@", name, name]];
        }
        message = [NSString stringWithFormat:@"{%@}", [[keyValues componentsJoinedByString:@","] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]]];
    }
    
    return [NSString stringWithFormat:@"function(%@) { let message = %@; webkit.messageHandlers.%@.postMessage(message); }", functionParams, message, methodName];
}

+ (NSString *)dh_javascriptForVariable:(NSString *)variable
            functionImplementation:(NSString *)functionImplementation {
    return [NSString stringWithFormat:@"%@ = %@", variable, functionImplementation];
}

@end


// ################################################
// MARK: - WKUserContentController分类
// ################################################

@interface WKUserContentController (DHMethodPoolExtension)
/// 获取加密的js方法名
/// @param obj 中间件对象
/// @param originalMethodName oc协议方法名，例：someMethod:withParam:
/// @param jsMethodname js方法名，此时没有
/// @return 加密的js方法名
- (NSString *)dh_fetchEncodedJSMethodNameForObject:(NSObject *)obj
                            withOriginalMethodName:(NSString *)originalMethodName
                                      jsMethodName:(NSString *)jsMethodname;
/// 从注册的js方法名获取原方法名
/// @param obj 方法所属对象
/// @param jsMethodName js方法名
/// @param jsParameter js传递参数
/// @return oc协议原生方法名
- (NSString *)dh_fetchDecodedMethodNameForObject:(NSObject *)obj
                                withJSMethodName:(NSString *)jsMethodName
                                     jsParameter:(id)jsParameter;
@end

@interface WKUserContentController (DHPropertyExtension) <WKScriptMessageHandler>
/// 需要监听的消息
@property (nonatomic, strong, readwrite) NSMutableArray *dh_registerScriptMessage;
/// 监听的中间件 @{注册的js方法名：中间件对象}
@property (nonatomic, strong) NSMutableDictionary *dh_registerScriptMiddleware;
/// 脚本消息执行者 @{注册的js方法名：消息监听者}
@property (nonatomic, strong) NSMutableDictionary *dh_registerScriptMessageHandler;
/// oc原生方法与js方法的匹配池 @{中间件对象类名:@{oc对应的原生方法：js注册的方法名}}
@property (nonatomic, strong) NSMutableDictionary *dh_scriptMessageMethodNamePool;
/// 需要注入的js
@property (nonatomic, strong, readwrite) NSMutableArray *dh_injectedJavascript;

@end

@implementation WKUserContentController (DHPropertyExtension)

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    
    // 如果存在监听类实现该方法，则先调用监听类的方法
    id handler = [self.dh_registerScriptMessageHandler objectForKey:message.name];
    if (handler
        && [handler respondsToSelector:@selector(userContentController:didReceiveScriptMessage:)]
        && handler != self) {
        // 此处的message.name可能是替换了的消息名，因为是只读属性，无法更改，考虑开个代理口子或者交换
        [handler userContentController:userContentController didReceiveScriptMessage:message];
    }
    
    // 通过名字取出中间件
    id middleware = [self.dh_registerScriptMiddleware objectForKey:message.name];
    if (!middleware) { return; }
    
    // 解密原生方法名
    NSString *methodName = [self dh_fetchDecodedMethodNameForObject:middleware
                                                   withJSMethodName:message.name
                                                        jsParameter:message.body];
    if (!methodName) { return; }
    
    // 通过回调注册的方法名查找相应的方法进行调用
    [DHWebviewJavascriptUtils dh_invokeInstanceMethodForObject:middleware
                                        withOriginalMethodName:methodName
                                                     parameter:message.body];
}

- (NSMutableArray *)dh_registerScriptMessage {
    NSMutableArray *temp = objc_getAssociatedObject(self, _cmd);
    if (!temp) {
        temp = [NSMutableArray array];
        objc_setAssociatedObject(self, @selector(dh_registerScriptMessage), temp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return temp;
}

- (void)setDh_registerScriptMessage:(NSMutableArray *)dh_registerScriptMessage {
    objc_setAssociatedObject(self, @selector(dh_registerScriptMessage), dh_registerScriptMessage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableArray *)dh_injectedJavascript {
    NSMutableArray *temp = objc_getAssociatedObject(self, _cmd);
    if (!temp) {
        temp = [NSMutableArray array];
        objc_setAssociatedObject(self, @selector(dh_injectedJavascript), temp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return temp;
}

- (void)setDh_injectedJavascript:(NSMutableArray *)dh_injectedJavascript {
    objc_setAssociatedObject(self, @selector(dh_injectedJavascript), dh_injectedJavascript, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)dh_registerScriptMiddleware {
    NSMutableDictionary *temp = objc_getAssociatedObject(self, _cmd);
    if (!temp) {
        temp = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, @selector(dh_registerScriptMiddleware), temp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return temp;
}

- (void)setDh_registerScriptMiddleware:(NSMutableDictionary *)dh_registerScriptMiddleware {
    objc_setAssociatedObject(self, @selector(dh_registerScriptMiddleware), dh_registerScriptMiddleware, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)dh_registerScriptMessageHandler {
    NSMutableDictionary *temp = objc_getAssociatedObject(self, _cmd);
    if (!temp) {
        temp = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, @selector(dh_registerScriptMessageHandler), temp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return temp;
}

- (void)setDh_registerScriptMessageHandler:(NSMutableDictionary *)dh_registerScriptMessageHandler {
    objc_setAssociatedObject(self, @selector(dh_registerScriptMessageHandler), dh_registerScriptMessageHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)dh_scriptMessageMethodNamePool {
    NSMutableDictionary *temp = objc_getAssociatedObject(self, _cmd);
    if (!temp) {
        temp = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, @selector(dh_scriptMessageMethodNamePool), temp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return temp;
}

- (void)setDh_scriptMessageMethodNamePool:(NSMutableDictionary *)dh_scriptMessageMethodNamePool {
    objc_setAssociatedObject(self, @selector(dh_scriptMessageMethodNamePool), dh_scriptMessageMethodNamePool, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark -
@implementation WKUserContentController (DHSwizzleExtension)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 交换监听脚本消息方法
        method_exchangeImplementations(class_getInstanceMethod(self,  @selector(addScriptMessageHandler:name:)), class_getInstanceMethod(self,  @selector(dh_addScriptMessageHandler:name:)));
        // 交换移除监听脚本方法
        method_exchangeImplementations(class_getInstanceMethod(self, @selector(removeScriptMessageHandlerForName:)), class_getInstanceMethod(self, @selector(dh_removeScriptMessageHandlerForName:)));
    });
}

- (void)dh_addScriptMessageHandler:(id<WKScriptMessageHandler>)scriptMessageHandler
                              name:(NSString *)name {
    // 监听者为空，或消息名数据异常
    if (!scriptMessageHandler) { return ; }
    if (![DHWebviewJavascriptUtils isValidString:name]) { return; }
    // 重复添加的消息名，可能会导致崩溃
    if ([self.dh_registerScriptMessage containsObject:name]) {
        // 添加过，那么就更新一下监听者
        [self dh_registerScriptMessageHandlerAppendName:name handler:scriptMessageHandler];
        return;
    }
    
    [self dh_addScriptMessageHandler:self name:name];
    [self.dh_registerScriptMessage addObject:name];
    [self dh_registerScriptMessageHandlerAppendName:name handler:scriptMessageHandler];
}

- (void)dh_removeScriptMessageHandlerForName:(NSString *)name {
    [self dh_removeScriptMessageHandlerForName:name];
    // 清空监听的数据
    [self.dh_registerScriptMessage removeObject:name];
    [self.dh_registerScriptMiddleware removeObjectForKey:name];
    [self.dh_registerScriptMessageHandler removeObjectForKey:name];
    [self.dh_scriptMessageMethodNamePool removeObjectForKey:name];
}

- (void)dh_registerScriptMessageHandlerAppendName:(NSString *)name handler:(id)handler {
    if (![DHWebviewJavascriptUtils isValidString:name]) { return; }
    if (!handler) { return; }
    if (handler == self) { return; }
    [self.dh_registerScriptMessageHandler setObject:handler forKey:name];
}

@end

#pragma mark - *** 提取 ***
@implementation WKUserContentController (DHMethodPoolExtension)
/// 获取加密的js方法名
/// @param obj 中间件对象
/// @param originalMethodName oc协议方法名，例：someMethod:withParam:
/// @param jsMethodName js方法名，此时没有
/// @return 加密的js方法名
- (NSString *)dh_fetchEncodedJSMethodNameForObject:(NSObject *)obj
                            withOriginalMethodName:(NSString *)originalMethodName
                                      jsMethodName:(NSString *)jsMethodName {
    if (!obj) { return nil; }
    if (![DHWebviewJavascriptUtils isValidString:originalMethodName]) { return nil; }
    if (![DHWebviewJavascriptUtils isValidString:jsMethodName]) { return nil; }
    
    NSString *className = NSStringFromClass(obj.class);
    NSMutableDictionary *objectJsMethods = [self.dh_scriptMessageMethodNamePool objectForKey:className] ?: [NSMutableDictionary dictionary];
    // 生成过后同个WKUserContentController是不可注册同名方法的，即便使用多个中间件，只要WKUserContentController是同一个就不行
    NSString *replacedMethodName = [objectJsMethods objectForKey:originalMethodName];
    if (replacedMethodName) { return replacedMethodName; }

    // 不存在则新生成一个加密的
    replacedMethodName = [jsMethodName stringByAppendingFormat:@"_%@", className];
    return replacedMethodName;
}

- (void)dh_appendJSMethodForObject:(NSObject *)obj
                  withJSMethodName:(NSString *)jsMethodName
                originalMethodName:(NSString *)originalMethodName {
    NSString *className = NSStringFromClass(obj.class);
    NSMutableDictionary *objectJsMethods = [self.dh_scriptMessageMethodNamePool objectForKey:className] ?: [NSMutableDictionary dictionary];
    
    [objectJsMethods setObject:jsMethodName
                        forKey:originalMethodName];
    
    [self.dh_scriptMessageMethodNamePool setObject:objectJsMethods
                                            forKey:className];
}

/// 从注册的js方法名获取原方法名
/// @param jsMethodName js方法名
/// @param jsParameter js传递参数
/// @return oc协议原生方法名
- (NSString *)dh_fetchDecodedMethodNameForObject:(NSObject *)obj
                                withJSMethodName:(NSString *)jsMethodName
                                     jsParameter:(id)jsParameter  {
    if (!obj) { return nil; }
    if (![DHWebviewJavascriptUtils isValidString:jsMethodName]) { return nil; }
    
    NSString *className = NSStringFromClass(obj.class);
    NSDictionary *objectScriptMessageMethodNamePool = [self.dh_scriptMessageMethodNamePool objectForKey:className];
    __block NSString *result = nil;
    
    // 先从方法缓存池中查找对应的方法
    [objectScriptMessageMethodNamePool enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull originalMName, id  _Nonnull jsMName, BOOL * _Nonnull stop) {
        if ([jsMethodName isEqualToString:jsMName]) {
            result = originalMName;
            *stop = YES;
        }
    }];
    if (!result) {
        // 再从协议方法中寻找
        result = [DHWebviewJavascriptUtils dh_findMatchedOriginalMethodNameForReceiver:obj
                                                                      withJSMethodName:jsMethodName
                                                                             parameter:jsParameter];
    }
    return result;
}

@end

#pragma mark -
@implementation WKUserContentController (DHJavascriptExtension)

- (void)dh_removeAllScriptMessageHandler {
    NSMutableArray *temp = [self.dh_registerScriptMessage mutableCopy];
    for (NSString *name in temp) {
        [self removeScriptMessageHandlerForName:name];
    }
}

- (void)dh_registerMiddleware:(id<DHJavascriptExport>)middleware {
    if (!middleware) { return ; }
    // 不遵循一切免谈
    BOOL conformed = [middleware conformsToProtocol:@protocol(DHJavascriptExport)];
    if (!conformed) { return ; }
    
    // js标识
    NSString *identifier = nil;
    if ([middleware.class respondsToSelector:@selector(dh_javascriptIdentifier)]) {
        identifier = [middleware.class dh_javascriptIdentifier];
    }
    
    // 是否所有方法都需要替换
    DHJavascriptBridgeType bridgeType = DHJavascriptBridgeType_AllNotNeed;
    if ([middleware.class respondsToSelector:@selector(dh_javascriptBridgeType)]) {
        bridgeType = [middleware.class dh_javascriptBridgeType];
    }
    
    // 无需替换的方法
    NSArray *needNotBridgeMethodNames = @[];
    if ([middleware.class respondsToSelector:@selector(dh_javascriptNeedNotBridgeMethodNames)]) {
        needNotBridgeMethodNames = [middleware.class dh_javascriptNeedNotBridgeMethodNames];
    }
    
    NSMutableArray *injectJavascriptList = [NSMutableArray array];
    // 标识识别注入
    if ([DHWebviewJavascriptUtils isValidString:identifier]) {
        [injectJavascriptList addObject:[DHWebviewJavascriptUtils dh_javascriptForIdentifier:identifier]];
    }
    
    // 遍历对象DHJavascriptExport子协议的所有必要实例方法
    NSArray *methods = [DHWebviewJavascriptUtils dh_instanceMethodsForClass:middleware.class];
    for (NSString *method in methods) {
        @autoreleasepool {
            // 中间件实现的方法名前缀
            NSString *jsMethodName = [DHWebviewJavascriptUtils dh_convertOriginalMethodNameToJSMethodName:method];
            
            // 如果所有的方法都需要替换，或无需替换方法池中不存在该方法名，那么就从缓存取新生成的方法名
            // 网页中替换的方法名称
            NSString *jsReplacedMethodName;
            if ((bridgeType == DHJavascriptBridgeType_AllNeed)
                || (bridgeType == DHJavascriptBridgeType_NotAllNeed && ![needNotBridgeMethodNames containsObject:method])) {
                jsReplacedMethodName = [self dh_fetchEncodedJSMethodNameForObject:middleware withOriginalMethodName:method jsMethodName:jsMethodName];
                [self dh_appendJSMethodForObject:middleware withJSMethodName:jsReplacedMethodName originalMethodName:method];
            } else {
                [self dh_appendJSMethodForObject:middleware withJSMethodName:jsMethodName originalMethodName:method];
            }
            
            
            if (!jsReplacedMethodName) {
                // 监听js回调
                if (![self.dh_registerScriptMessage containsObject:jsMethodName]) {
                    [self dh_appendMiddleware:middleware forMessage:jsMethodName];
                }
                continue;
            }
            
            if (![self.dh_registerScriptMessage containsObject:jsReplacedMethodName]) {
                [self dh_appendMiddleware:middleware forMessage:jsReplacedMethodName];
            }
            
            // 注入替换的js
            // 只有当不同名存在时才需要注入等价替换js
            NSString *js = [DHWebviewJavascriptUtils dh_javascriptForIdentifier:identifier
                                                             originalMethodName:method
                                                                   jsMethodName:jsMethodName
                                                           jsReplacedMethodName:jsReplacedMethodName];
            if (!js) { continue; }
            [injectJavascriptList addObject:js];
        
        }
    }
    
    // 额外需要注入的js
    if ([middleware.class respondsToSelector:@selector(dh_javascriptExtendInject)]) {
        NSArray *jsArray = [middleware.class dh_javascriptExtendInject]?:@[];
        [injectJavascriptList addObjectsFromArray:jsArray];
    }
    
    [self.dh_injectedJavascript addObjectsFromArray:injectJavascriptList];
}

- (void)dh_appendMiddleware:(id)middleware forMessage:(NSString *)message {
    [self addScriptMessageHandler:(id<WKScriptMessageHandler>)self name:message];
    [self.dh_registerScriptMiddleware setValue:middleware forKey:message];
}

@end


// ################################################
// MARK: - 替换WKWebview代理方法
// ################################################

static void dh_webviewDidFinishNavigation(id self, SEL _cmd, id webview, id navigation) {
    // 执行原有代理的方法
    SEL selector = NSSelectorFromString(@"dh_webview:didFinishNavigation:");
    ((void(*)(id, SEL, id, id))objc_msgSend)(self, selector, webview, navigation);
    
    if (![webview isKindOfClass:[WKWebView class]]) { return; }
    // 注入js
    WKUserContentController *userContent = ((WKWebView *)webview).configuration.userContentController;
    if (!userContent) { return; }
    if (![userContent respondsToSelector:@selector(dh_injectedJavascript)]) { return; }
    
    NSArray *injectJavascript = userContent.dh_injectedJavascript;
    
    if (![injectJavascript isKindOfClass:[NSArray class]]) { return; }
    for (NSString *js in injectJavascript) {
        [((WKWebView *)webview) evaluateJavaScript:js completionHandler:nil];
    }
}

static void dh_setNavigationDelegate(id obj, SEL sel, id navigationDelegate) {
    SEL swizzleSel = sel_getUid("dh_setNavigationDelegate:");
    ((void (*)(id, SEL, id))objc_msgSend)(obj, swizzleSel, navigationDelegate);
    
    if (navigationDelegate == nil) {
        return;
    }
    if ([navigationDelegate isKindOfClass:[WKWebView class]]) {
        return;
    }
    Class class = [navigationDelegate class];
#ifdef DH_WKWEBVIEW_NOT_SWIZZLING
    return;
#endif
    // 替换代理方法 webview:didFinishNavigation:
    do {
        Method rootMethod = nil;
        if ((rootMethod = class_getInstanceMethod(class, @selector(webView:didFinishNavigation:)))) {
            if (!class_getInstanceMethod(class_getSuperclass(class), @selector(webView:didFinishNavigation:))) {
                const char* encoding = method_getTypeEncoding(rootMethod);
                SEL swizSel = NSSelectorFromString(@"dh_webview:didFinishNavigation:");
                if (class_addMethod(class , swizSel, (IMP)dh_webviewDidFinishNavigation, encoding)) {
                    Method originalMethod = class_getInstanceMethod(class, @selector(webView:didFinishNavigation:));
                    Method swizzledMethod = class_getInstanceMethod(class, swizSel);
                    method_exchangeImplementations(originalMethod, swizzledMethod);
                }
                break;
            }
        }
    } while ((class = class_getSuperclass(class)));

}

@implementation WKWebView (DHJavascriptExtension)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL origSel_ = sel_getUid("setNavigationDelegate:");
        SEL swizzileSel = sel_getUid("dh_setNavigationDelegate:");
        Method origMethod = class_getInstanceMethod(self, origSel_);
        const char* type = method_getTypeEncoding(origMethod);
        class_addMethod(self, swizzileSel, (IMP)dh_setNavigationDelegate, type);
        Method swizzleMethod = class_getInstanceMethod(self, swizzileSel);
        IMP origIMP = method_getImplementation(origMethod);
        IMP swizzleIMP = method_getImplementation(swizzleMethod);
        method_setImplementation(origMethod, swizzleIMP);
        method_setImplementation(swizzleMethod, origIMP);
    });
}

// 注入js
- (void)dh_injectJavascriptIfNeed {
#ifndef DH_WKWEBVIEW_NOT_SWIZZLING
    return;
#endif
    WKUserContentController *userContent = self.configuration.userContentController;
    if (!userContent) { return; }
    if (![userContent respondsToSelector:@selector(dh_injectedJavascript)]) { return; }
    
    NSArray *injectJavascript = userContent.dh_injectedJavascript;
    
    if (![injectJavascript isKindOfClass:[NSArray class]]) { return; }
    for (NSString *js in injectJavascript) {
        [self evaluateJavaScript:js completionHandler:nil];
    }
}

@end
