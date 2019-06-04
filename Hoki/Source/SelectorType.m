//
//  SelectorType.m
//  HookDemo
//
//  Created by Chasel on 2018/6/5.
//  Copyright © 2018 邵文涛. All rights reserved.
//

#import "SelectorType.h"
#import <objc/message.h>
#import <objc/runtime.h>

@implementation SelectorType

BOOL isAllowHookLibffiSelector(Class cls, SEL sel){
    if (!cls || !sel) return NO;
    static NSSet *disallowedSelectorList;
    static NSSet *disallowedSelectorPefixList;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        disallowedSelectorList = [NSSet setWithObjects:/*UIViewController:*/@".cxx_destruct", @"dealloc", @"_isDeallocating", @"release", @"autorelease", @"retain", @"Retain", @"_tryRetain", @"copy", /*UIView:*/ @"nsis_descriptionOfVariable:", /*NSObject:*/@"respondsToSelector:", @"class", @"methodSignatureForSelector:", @"allowsWeakReference", @"retainWeakReference", @"init", @"forwardInvocation:", @"forwardingTargetForSelector:", @"description", nil];
        
        disallowedSelectorPefixList = [NSSet setWithObjects:kPrefix,@"NSKVONotifying_",nil];
    });
    
    NSString *selectorName = NSStringFromSelector(sel);
    if ([disallowedSelectorList containsObject:selectorName]) {
        return NO;
    }
    if ([disallowedSelectorPefixList containsObject:selectorName]) {
        return NO;
    }
    if ([selectorName hasSuffix:@"__"]) { // isNSString__
        return NO;
    }
    
    Method targetMethod = class_getInstanceMethod(cls, sel);
    char dst[256];
    method_getReturnType(targetMethod, dst, sizeof(dst));
    BOOL isCan = _canHandleType(dst);
    if (!isCan) return NO;

    unsigned int  argumentsCount = method_getNumberOfArguments(targetMethod);
    for (int i = 0; i < argumentsCount; i ++) {
        char argumentType[256];
        method_getArgumentType(targetMethod, i, argumentType, sizeof(argumentType));
        BOOL isCan = _canHandleType(argumentType);
        if (!isCan) {
            return NO;
        }
    }
    return YES;
}

BOOL _canHandleType(char *type) {
#define COMPARE(_type)\
if (0 == strcmp(type, @encode(_type))) {\
return YES;\
}
    COMPARE(char)
    COMPARE(int)
    COMPARE(short)
    COMPARE(long)
    COMPARE(long long)
    COMPARE(unsigned char)
    COMPARE(unsigned int)
    COMPARE(unsigned short)
    COMPARE(unsigned long)
    COMPARE(unsigned long long)
    COMPARE(float)
    COMPARE(double)
    COMPARE(BOOL)
    COMPARE(void)
    COMPARE(char *)
    COMPARE(CGRect)
    COMPARE(CGPoint)
    COMPARE(CGSize)
    COMPARE(CGVector)
    COMPARE(CGAffineTransform)
    COMPARE(UIOffset)
    COMPARE(UIEdgeInsets)
    COMPARE(dispatch_block_t)
    COMPARE(SEL)
    COMPARE(Class)
    if (_is_object_type(type)) {
        return YES;
    }
    return NO;
}

BOOL _is_object_type(const char *argumentType) {
    if (argumentType == NULL) return NO;
    if (argumentType[0] == '@'){
        return YES;
    } else {
        return NO;
    }
}


@end
