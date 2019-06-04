//
//  BiuHookForward.m
//  testDemo
//
//  Created by Chasel on 12/03/2018.
//  Copyright © 2018 邵文涛. All rights reserved.
//

#import "SelectorHookForward.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import "SelectorType.h"

#define INITIALIZEGETMAP(map_name)\
static dispatch_semaphore_t semaphore##map_name;\
NSMutableDictionary *hook_forward_get##map_name##Map(){ \
static NSMutableDictionary<NSString *, NSString *> *_objectTo##map_name##Map = nil;\
static dispatch_once_t onceToken;\
dispatch_once(&onceToken, ^{\
semaphore##map_name = dispatch_semaphore_create(1);\
_objectTo##map_name##Map = [NSMutableDictionary dictionary];\
});\
return _objectTo##map_name##Map;\
} \
static void hook_forward_set##map_name##Map(NSString *key, id value){ \
NSMutableDictionary *map = hook_forward_get##map_name##Map();\
dispatch_semaphore_wait(semaphore##map_name,DISPATCH_TIME_FOREVER);\
[map setObject:value forKey:key];\
dispatch_semaphore_signal(semaphore##map_name);\
} \
static id hook_forward_get##map_name##WithKey(NSString *key){\
NSMutableDictionary *map = hook_forward_get##map_name##Map();\
return [map valueForKey:key];\
} \
void hook_forward_remove##map_name##WithKey(NSString *key){\
NSMutableDictionary *map = hook_forward_get##map_name##Map();\
dispatch_semaphore_wait(semaphore##map_name,DISPATCH_TIME_FOREVER);\
[map removeObjectForKey:key];\
dispatch_semaphore_signal(semaphore##map_name);\
}

INITIALIZEGETMAP(Selector)
INITIALIZEGETMAP(BeforeBlock)
INITIALIZEGETMAP(AfterBlock)

Class _hook_forward_class(id self, SEL cmd);
BOOL _hook_forward_is_struct_type(const char *argumentType);
Class _hook_forward_replaceClassWithObject(NSString *className);
NSArray* _hook_forward_method_arguments(NSInvocation *invocation);
void _hook_forward_invocation(id target, SEL selector, NSInvocation *invocation);
Boolean hookForwardSelector(id object, SEL selector, SelectorHookForwardBeforeBlock beforeBlock, SelectorHookForwardAfterBlock afterBlock);
Boolean hookForwardSel(Class cls, SEL selector);

static NSMapTable *_objectToBeforeBlockMapTable;
static NSMapTable *_objectToAfterBlockMapTable;
static  dispatch_semaphore_t _semaphore;

@interface Parasite : NSObject
@property (nonatomic, copy) dispatch_block_t deallocBlock;
@end
@implementation Parasite
- (void)dealloc {
    if (self.deallocBlock) {
        self.deallocBlock();
    }
}

static const char kParsiteDeadBlockKey = '\0';
void _parasite_addDeallocBlock(dispatch_block_t block, id object){
    @synchronized ([Parasite class]) {
        NSMutableArray *parasiteList = objc_getAssociatedObject(object, &kParsiteDeadBlockKey);
        if (!parasiteList) {
            parasiteList = [NSMutableArray array];
            objc_setAssociatedObject(object, &kParsiteDeadBlockKey, parasiteList, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        Parasite *parasite = [Parasite new];
        parasite.deallocBlock = block;
        [parasiteList addObject: parasite];
    }
}
@end

@interface SelectorHookForward()
@property (nonatomic, weak, readwrite) id hookForwardObject;
@end

@implementation SelectorHookForward
+ (void)initialize{
    if (self == [SelectorHookForward class]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _semaphore = dispatch_semaphore_create(1);
            _objectToAfterBlockMapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsCopyIn valueOptions:NSPointerFunctionsWeakMemory];
            _objectToBeforeBlockMapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsCopyIn valueOptions:NSPointerFunctionsWeakMemory];
        });
    }
}

+ (instancetype)hookForwardSelectorWithClass:(Class)cls beforeBlock:(SelectorHookForwardBeforeBlock)beforeBlock afterBlock:(SelectorHookForwardAfterBlock)afterBlock{
    SelectorHookForward *hook_forward = [[SelectorHookForward alloc] init];
    hook_forward_setBeforeBlockMap(NSStringFromClass(cls), beforeBlock);
    hook_forward_setAfterBlockMap(NSStringFromClass(cls), afterBlock);
      _performLocked(^{
    unsigned int outCount;
    Method *methods = class_copyMethodList(cls,&outCount);
    for (int i = 0; i < outCount; i ++) {
        Method tempMethod = *(methods + i);
        SEL selector = method_getName(tempMethod);
        char *returnType = method_copyReturnType(tempMethod);
        
        BOOL isCan = isAllowHookLibffiSelector(cls, selector);
        if (isCan) {
          
                if (hook_forwardSel(cls, selector)) {
                    NSLog(@"success hook_forward : %@  %@",NSStringFromClass(cls), NSStringFromSelector(selector));
                } else {
                    NSLog(@"failure hook_forward : %@",NSStringFromSelector(selector));
                }
    
        } else {
            
        }
        free(returnType);
    }
    free(methods);
            });
    return hook_forward;
}

+ (instancetype)hookForwardSelectorWithObject:(id)object selector:(SEL)selector beforeBlock:(SelectorHookForwardBeforeBlock)beforeBlock afterBlock:(SelectorHookForwardAfterBlock)afterBlock{
    SelectorHookForward *hook_forward = [[SelectorHookForward alloc] init];
    hook_forward.hookForwardObject = object;
    hook_forward.selectorHookForwardBeforeBlock = beforeBlock;
    hook_forward.selectorHookForwardAfterBlock = afterBlock;
    hookForwardSelector(object, selector, beforeBlock, afterBlock);
    return hook_forward;
}

-(void)setSelectorHookForwardAfterBlock:(SelectorHookForwardAfterBlock)selectorHookForwardAfterBlock{
    if (_hookForwardObject != nil) {
        _selectorHookForwardAfterBlock = selectorHookForwardAfterBlock;
        hook_forward_setAfterBlockMap([NSString stringWithFormat:@"%p",_hookForwardObject], selectorHookForwardAfterBlock);
    } else {
        // hook_forwarded object is released
    }
}

-(void)setSelectorHookForwardBeforeBlock:(SelectorHookForwardBeforeBlock)selectorHookForwardBeforeBlock{
    if (_hookForwardObject != nil) {
        _selectorHookForwardBeforeBlock = selectorHookForwardBeforeBlock;
        hook_forward_setBeforeBlockMap([NSString stringWithFormat:@"%p",_hookForwardObject], selectorHookForwardBeforeBlock);
    } else {
        // hook_forwarded object is released
    }
}

Boolean hook_forwardSel(Class cls, SEL selector){
    Method originMethod = class_getInstanceMethod(cls, selector);
    if (originMethod == nil || cls == nil) {
        assert(YES);
    }
    
    const char *originTypes = method_getTypeEncoding(originMethod);
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    char *returnType = method_copyReturnType(originMethod);
    if (_hook_forward_is_struct_type(returnType)) {
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:originTypes];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }else{
        }
    }
#endif
    IMP originIMP = method_getImplementation(originMethod);
    SEL newSelecotr = _hook_forward_createNewSelector(selector);
    if (originIMP == nil || originIMP == msgForwardIMP) {
        assert(YES);
    }
    class_replaceMethod(cls, selector, msgForwardIMP, originTypes);
    class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)_hook_forward_forwardInvocation, "v@:@");
    
    BOOL isAdd = class_addMethod(cls, newSelecotr, originIMP, originTypes);
    if (isAdd == NO) {
        return false;
    } else {
        NSLog(@"%@ add method %@",NSStringFromClass(cls),NSStringFromSelector(newSelecotr));
    }
    return true;
}

Boolean hookForwardSelector(id object, SEL selector, SelectorHookForwardBeforeBlock beforeBlock, SelectorHookForwardAfterBlock afterBlock){
    Class cls = _hook_forward_replaceClassWithObject(object);
    Method originMethod = class_getInstanceMethod(cls, selector);
    if (originMethod == nil || cls == nil) {
        assert(YES);
    }
    object_setClass(object, cls);
    NSString *selectorString = NSStringFromSelector(selector);
    // life cycle
    NSString *key = [NSString stringWithFormat:@"%p",object];
    hook_forward_setSelectorMap(key, selectorString);
    hook_forward_setBeforeBlockMap(key, beforeBlock);
    hook_forward_setAfterBlockMap(key, afterBlock);
    _parasite_addDeallocBlock(^{
        // remove object
        hook_forward_removeSelectorWithKey(key);
        hook_forward_removeBeforeBlockWithKey(key);
        hook_forward_removeAfterBlockWithKey(key);
    }, object);
    
    const char *originTypes = method_getTypeEncoding(originMethod);
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    char *returnType = method_copyReturnType(originMethod);
    if (_hook_forward_is_struct_type(returnType)) {
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:originTypes];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }else{
        }
    }
#endif
    IMP originIMP = method_getImplementation(originMethod);
    SEL newSelecotr = _hook_forward_createNewSelector(selector);
    if (originIMP == nil || originIMP == msgForwardIMP) {
        assert(YES);
    }
    class_replaceMethod(cls, selector, msgForwardIMP, originTypes);
    class_replaceMethod(cls, @selector(forwardInvocation:), (IMP)_hook_forward_forwardInvocation, "v@:@");
    
    BOOL isAdd = class_addMethod(cls, newSelecotr, originIMP, originTypes);
    if (!isAdd) return false;
    return true;
}

Class _hook_forward_replaceClassWithObject(id object){
    Class originClass = object_getClass(object);
    if (!originClass) return nil;
    NSString *className = NSStringFromClass(originClass);
    if ([className hasPrefix:kPrefix]) return originClass;
    NSString *biuClassName = [kPrefix stringByAppendingString:className];
    Class biuClass = NSClassFromString(biuClassName);
    if (biuClass) return biuClass;
    biuClass = objc_allocateClassPair(originClass, biuClassName.UTF8String, 0);
    Method clazzMethod = class_getInstanceMethod(biuClass, @selector(class));
    const char *types = method_getTypeEncoding(clazzMethod);
    class_addMethod(biuClass, @selector(class), (IMP)_hook_forward_class, types);
    objc_registerClassPair(biuClass);
    return biuClass;
}

Class _hook_forward_class(id self, SEL cmd){
    Class clazz = object_getClass(self);
    Class superClazz = class_getSuperclass(clazz);
    return superClazz;
}


void _hook_forward_forwardInvocation(id target, SEL selector, NSInvocation *invocation) {
        _performLocked(^{
    SEL sel = invocation.selector;
    NSString *selString = NSStringFromSelector(sel);
    SEL newSelecotr;
    if (![selString hasPrefix:kPrefix]) {
        newSelecotr = _hook_forward_createNewSelector(selector);
    } else {
        newSelecotr = sel;
    }
    NSString *key = [NSString stringWithFormat:@"%p",target];
    if ([selString isEqualToString:NSStringFromSelector(@selector(forwardInvocation:))]) {
        return;
    }
    
    NSString *hook_forwardSelectorString = hook_forward_getSelectorWithKey(key);
    if (![selString isEqualToString:hook_forwardSelectorString]) {
        assert(YES);
    }
    
    [invocation setSelector:newSelecotr];
    
    SelectorHookForwardBeforeBlock beforeBlock =  hook_forward_getBeforeBlockWithKey(key);
    if(beforeBlock == nil) beforeBlock = hook_forward_getBeforeBlockWithKey(NSStringFromClass([target class]));
    SelectorHookForwardAfterBlock afterBlock = hook_forward_getAfterBlockWithKey(key);
    if (afterBlock == nil) afterBlock =        hook_forward_getAfterBlockWithKey(NSStringFromClass([target class]));
    
    if (beforeBlock) {
        NSArray *argList = _hook_forward_method_arguments(invocation);
        beforeBlock(target,sel,argList);
    }
    

        
    CFTimeInterval start =  CACurrentMediaTime();
    [invocation invoke];
    if (afterBlock) {
        CFTimeInterval interval = CACurrentMediaTime() - start;
        afterBlock(target,sel,interval);
    }
        
    });
}

BOOL _hook_forward_is_struct_type(const char *argumentType) {
    if (argumentType == NULL) return NO;
    unsigned long lastIndex = strlen(argumentType) - 1;
    if (argumentType[0] == '{' && argumentType[lastIndex] == '}'){
        return YES;
    } else {
        return NO;
    }
}

SEL _hook_forward_createNewSelector(SEL originalSelector){
    NSString *oldSelectorName = NSStringFromSelector(originalSelector);
    SEL newSelector = NSSelectorFromString([kPrefix stringByAppendingString:oldSelectorName]);
    return newSelector;
}

NSArray* _hook_forward_method_arguments(NSInvocation *invocation) {
    if (invocation == nil) return nil;
    NSMethodSignature *methodSignature = [invocation methodSignature];
    NSMutableArray *argList = (methodSignature.numberOfArguments > 2 ? [NSMutableArray array] : nil);
    for (NSUInteger i = 2; i < methodSignature.numberOfArguments; i++) {
        const char *argumentType = [methodSignature getArgumentTypeAtIndex:i];
        id arg = nil;
        if (_hook_forward_is_struct_type(argumentType)) {
#define GET_STRUCT_ARGUMENT(structType) \
if(strncmp(argumentType, @encode(structType), strlen(@encode(structType))) == 0) \
{ \
structType arg_temp;\
[invocation getArgument:&arg_temp atIndex:i];\
arg = NSStringFrom##structType(arg_temp);\
}
            GET_STRUCT_ARGUMENT(CGRect)
            else GET_STRUCT_ARGUMENT(CGPoint)
                else GET_STRUCT_ARGUMENT(CGSize)
                    else GET_STRUCT_ARGUMENT(CGVector)
                        else GET_STRUCT_ARGUMENT(UIOffset)
                            else GET_STRUCT_ARGUMENT(UIEdgeInsets)
                                else GET_STRUCT_ARGUMENT(CGAffineTransform)
                                    if (arg == nil) {
                                        arg = @"{unknown}";
                                    }
        }
#define GET_ARGUMENT(_type)\
if (0 == strcmp(argumentType, @encode(_type))) {\
_type arg_temp;\
[invocation getArgument:&arg_temp atIndex:i];\
arg = @(arg_temp);\
}
        else GET_ARGUMENT(char)
            else GET_ARGUMENT(int)
                else GET_ARGUMENT(short)
                    else GET_ARGUMENT(long)
                        else GET_ARGUMENT(long long)
                            else GET_ARGUMENT(unsigned char)
                                else GET_ARGUMENT(unsigned int)
                                    else GET_ARGUMENT(unsigned short)
                                        else GET_ARGUMENT(unsigned long)
                                            else GET_ARGUMENT(unsigned long long)
                                                else GET_ARGUMENT(float)
                                                    else GET_ARGUMENT(double)
                                                        else GET_ARGUMENT(BOOL)
                                                            else if (0 == strcmp(argumentType, @encode(id))) {
                                                                __unsafe_unretained id arg_temp;
                                                                [invocation getArgument:&arg_temp atIndex:i];
                                                                arg = arg_temp;
                                                            }
                                                            else if (0 == strcmp(argumentType, @encode(SEL))) {
                                                                SEL arg_temp;
                                                                [invocation getArgument:&arg_temp atIndex:i];
                                                                arg = NSStringFromSelector(arg_temp);
                                                            }
                                                            else if (0 == strcmp(argumentType, @encode(char *))) {
                                                                char *arg_temp;
                                                                [invocation getArgument:&arg_temp atIndex:i];
                                                                arg = [NSString stringWithUTF8String:arg_temp];
                                                            }
                                                            else if (0 == strcmp(argumentType, @encode(void *))) {
                                                                void *arg_temp;
                                                                [invocation getArgument:&arg_temp atIndex:i];
                                                                arg = (__bridge id _Nonnull)arg_temp;
                                                            }
                                                            else if (0 == strcmp(argumentType, @encode(Class))) {
                                                                Class arg_temp;
                                                                [invocation getArgument:&arg_temp atIndex:i];
                                                                arg = arg_temp;
                                                            }
        
        if (!arg) {
            arg = @"unknown";
        }
        [argList addObject:arg];
    }
    return argList;
}

static void _performLocked(dispatch_block_t block) {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    block();
    dispatch_semaphore_signal(_semaphore);
}


@end
