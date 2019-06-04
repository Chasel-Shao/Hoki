//
//  IMPFunctionPool.m
//  calssHookLibffiDemo
//
//  Created by Chasel on 08/04/2018.
//  Copyright © 2018 邵文涛. All rights reserved.
//

#import "ffi.h"
#import "SelectorHookLibffi.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import "SelectorType.h"
#import <mach/mach_time.h>

static SelectorHookLibffiBeforeBlock _beforeBlock;
static SelectorHookLibffiAfterBlock _afterBlock;
static void _performLocked(dispatch_block_t block);
BOOL _hook_libffi_is_struct_type(const char *argumentType);
BOOL _canHandleType(char *type) ;
@interface IMPFunction () {
    ffi_cif *_cif;
    ffi_closure *_closure;
    ffi_type ** _argTypes;
    void *_HookLibffiedFunc;
}
@property (nonatomic, assign) Class cls;
@property (nonatomic, assign) SEL originSelector;
@end

@implementation IMPFunction

-(void *)constructIMPFuncWithClass:(Class)cls selecor:(SEL)sel{
    
    void *_replacementFunc = NULL;
    
    Method targetMethod = class_getInstanceMethod(cls, sel);
    unsigned int  argumentsCount = method_getNumberOfArguments(targetMethod);
    _closure = ffi_closure_alloc(sizeof(ffi_closure), &_replacementFunc);
    _cif = malloc(sizeof(ffi_cif));
    _argTypes = malloc(sizeof(ffi_type *) * argumentsCount);
    char dst[256];
    method_getReturnType(targetMethod, dst, sizeof(dst));
    ffi_type *returnType = [self _ffiTypeWithEncodingChar:dst];
    for (int i = 0; i < argumentsCount; i ++) {
        char dst[256];
        method_getArgumentType(targetMethod, i, dst, sizeof(dst));
        ffi_type *currentType = [self _ffiTypeWithEncodingChar:dst];
        _argTypes[i] = currentType;
    }
    
    ffi_status status1 = ffi_prep_cif(_cif, FFI_DEFAULT_ABI, argumentsCount, returnType, _argTypes);
    if (status1 == FFI_OK) {
        ffi_status status2 =  ffi_prep_closure_loc(_closure, _cif, _hook_libffi_class_interpreter, (__bridge_retained void *)(self), _replacementFunc);
        if (status2 == FFI_OK) {
            self->_HookLibffiedFunc =  class_getMethodImplementation(cls, sel);
            const char *typeEncoding =  method_getTypeEncoding(targetMethod);
            NSString *selString = NSStringFromSelector(sel);
            SEL newSelecotr = NSSelectorFromString([kPrefix stringByAppendingString:selString]);
            __unused BOOL addedAlias = class_addMethod(cls, newSelecotr,self->_HookLibffiedFunc, typeEncoding);
            
            class_replaceMethod(cls, sel, _replacementFunc, typeEncoding);
        }
    }
    return _replacementFunc;
}

static void _hook_libffi_class_interpreter(ffi_cif *cif, void *ret, void **args, void *userdata)
{
    if(!userdata){
        NSLog(@"%@",@"HookLibffi running error!");
        return;
    }
    __block IMPFunction *one = nil;
    _performLocked(^{
        one = (__bridge IMPFunction*)userdata;
    });
    if (one == nil || ![one isKindOfClass:[IMPFunction class]]) {
        NSLog(@"%@",@"HookLibffi running error!");
        return;
    }
    
    if (_beforeBlock) {
        _beforeBlock(one.cls, one.originSelector);
    }
    CFTimeInterval ms = CalculateTimeBlock(^{
        ffi_call(cif,  one->_HookLibffiedFunc , ret, args);
    });

    if (_afterBlock) {
//        NSDictionary *argDict =  _hook_libffi_method_arguments(one,args);
//        id ret = _hook_libffi_method_ret(one,args);
        _afterBlock(one.cls, one.originSelector, ms);
    }
}

- (ffi_type *)_ffiTypeWithEncodingChar:(const char *)types
{
    if (types == NULL) {
        return &ffi_type_void;
    }
    
    switch (types[0]) {
        case 'v':
            return &ffi_type_void;
        case 'c':
            return &ffi_type_schar;
        case 'C':
            return &ffi_type_uchar;
        case 's':
            return &ffi_type_sshort;
        case 'S':
            return &ffi_type_ushort;
        case 'i':
            return &ffi_type_sint;
        case 'I':
            return &ffi_type_uint;
        case 'l':
            return &ffi_type_slong;
        case 'L':
            return &ffi_type_ulong;
        case 'q':
            return &ffi_type_sint64;
        case 'Q':
            return &ffi_type_uint64;
        case 'f':
            return &ffi_type_float;
        case 'd':
            return &ffi_type_double;
        case 'F':
#if CGFLOAT_IS_DOUBLE
            return &ffi_type_double;
#else
            return &ffi_type_float;
#endif
        case 'B':
            return &ffi_type_uint8;
        case '^':
            return &ffi_type_pointer;
        case '@':
            return &ffi_type_pointer;
        case '#':
            return &ffi_type_pointer;
        case ':':
            return &ffi_type_schar;
        case '{':
        {
            
#define STRUCT(structType, ...) \
if(strncmp(types, @encode(structType), strlen(@encode(structType))) == 0) \
{ \
ffi_type *elementsLocal[] = { __VA_ARGS__, NULL }; \
ffi_type **elements = malloc(sizeof(elementsLocal)); \
memcpy(elements, elementsLocal, sizeof(elementsLocal)); \
\
ffi_type *structType = malloc(sizeof(*structType)); \
structType->type = FFI_TYPE_STRUCT; \
structType->elements = elements; \
return structType; \
}
            
            ffi_type *CGFloatFFI = sizeof(CGFloat) == sizeof(float) ? &ffi_type_float : &ffi_type_double;
            STRUCT(NSRange,&ffi_type_uint64, &ffi_type_uint64)
            STRUCT(CGRect,CGFloatFFI,CGFloatFFI,CGFloatFFI,CGFloatFFI)
            STRUCT(CGPoint,CGFloatFFI,CGFloatFFI)
            STRUCT(CGSize,CGFloatFFI,CGFloatFFI)
            STRUCT(UIEdgeInsets,CGFloatFFI,CGFloatFFI,CGFloatFFI,CGFloatFFI)
            STRUCT(UIOffset,CGFloatFFI,CGFloatFFI)
            STRUCT(CGVector,CGFloatFFI,CGFloatFFI)
            STRUCT(CGAffineTransform,CGFloatFFI,CGFloatFFI,CGFloatFFI,CGFloatFFI,CGFloatFFI,CGFloatFFI)
        }
    }
    return NULL;
}

id _hook_libffi_method_ret(IMPFunction *impFunc, void *ret) {
    Method targetMethod = class_getInstanceMethod(impFunc.cls, impFunc.originSelector);
    char dst[256];
    method_getReturnType(targetMethod, dst, sizeof(dst));
    NSLog(@" hook ret ---------------------> %s %@  %@", dst, impFunc.cls, NSStringFromSelector(impFunc.originSelector) );

    return _hook_libffi_types(dst, ret);
}

NSDictionary * _hook_libffi_method_arguments(IMPFunction *impFunc, void **args) {
    NSMutableDictionary *argDict =  [NSMutableDictionary dictionary];
    Method targetMethod = class_getInstanceMethod(impFunc.cls, impFunc.originSelector);
    unsigned int  argumentsCount = method_getNumberOfArguments(targetMethod);
            if (argumentsCount < 2) return @{};
    for (int i = 2; i < argumentsCount; i ++) {
        char argumentType[256];
        method_getArgumentType(targetMethod, i, argumentType, sizeof(argumentType));
        id value = nil;
        NSLog(@" hook %d ---------------------> %s %@  %@", i, argumentType, impFunc.cls, NSStringFromSelector(impFunc.originSelector) );
        value = _hook_libffi_types(argumentType, args[i]);
        if(value) argDict[@(i-2)] = value;
    }
    return [argDict copy];
}


id _hook_libffi_types(char *argumentType, void *arg){
    id ret = nil;
    if (_hook_libffi_is_struct_type(argumentType)) {
#define GETSTRUCTTYPE(_type) \
if (0 == strcmp(argumentType, @encode(_type))) {\
return [NSValue value:arg withObjCType:argumentType];\
}
        GETSTRUCTTYPE(CGPoint)
        GETSTRUCTTYPE(CGSize)
        GETSTRUCTTYPE(CGRect)
        GETSTRUCTTYPE(CGVector)
        GETSTRUCTTYPE(UIOffset)
        GETSTRUCTTYPE(UIEdgeInsets)
        GETSTRUCTTYPE(CGAffineTransform)
    }
    
#define GET_ARGUMENT(_type)\
if (0 == strcmp(argumentType, @encode(_type))) {\
_type temp;\
memcpy(&temp, arg,sizeof(_type));\
ret =  @(temp);\
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
                                                        else if (0 == strcmp(argumentType, @encode(SEL))) {
                                                            SEL arg_temp;
                                                            memcpy(&arg_temp, arg, sizeof(SEL));
                                                            ret = NSStringFromSelector(arg_temp);
                                                        }
                                                        else if (0 == strcmp(argumentType, @encode(char *))) {
                                                            ret = [NSString stringWithUTF8String:arg];
                                                        }
                                                        else if (0 == strcmp(argumentType, @encode(void *))) {
                                                            ret = (__bridge id _Nonnull)arg;
                                                        }
                                                        else if (0 == strcmp(argumentType, @encode(Class))) {
                                                            Class arg_temp;
                                                            memcpy(&arg_temp, arg, sizeof(Class));
                                                            ret = NSStringFromClass(arg_temp);
                                                        }
                                                        else if (_is_object_type(argumentType)) {
                                                            size_t len = strlen(argumentType);
                                                            if (len > 1 && argumentType[1] == '?') {
                                                                // only be successful in arguments analyzes
                                                                // block type
//                                                                __weak id arg_temp;
                                                                __unsafe_unretained dispatch_block_t arg_temp;
                                                                memcpy((void*)&arg_temp, arg, sizeof(dispatch_block_t));
                                                                ret = [arg_temp copy];
                                                            } else {
                                                                // only be successful in arguments analyzes
                                                                 // may crash by objc_release
//                                                                void *temp = arg;
                                                                ret = (__bridge id)(*(void**)(arg));
//                                                                ret = (__bridge id)temp;
//                                                                id temp;
//                                                                temp = (__bridge id)(*(void**)(arg));

                                                            }
                                                        }
                                                        if (ret == nil) {
                                                            ret = @"unknown";
                                                        }
    
    return ret;
}

BOOL _hook_libffi_is_struct_type(const char *argumentType) {
    if (argumentType == NULL) return NO;
    unsigned long lastIndex = strlen(argumentType) - 1;
    if (argumentType[0] == '{' && argumentType[lastIndex] == '}'){
        return YES;
    } else {
        return NO;
    }
}

@end

@interface SelectorHookLibffi()

@end
static NSMutableDictionary *__IMPFunctionPoolDict;
static  dispatch_semaphore_t _semaphore;
@implementation SelectorHookLibffi

+ (void)initialize{
    __IMPFunctionPoolDict = [NSMutableDictionary dictionary];
    _semaphore = dispatch_semaphore_create(1);
}

+ (instancetype)sharedInstance{
    static SelectorHookLibffi* sharedPool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPool = [[SelectorHookLibffi alloc] init];
    });
    return sharedPool;
}

+ (void)hookLibffiClass:(Class)cls beforeBlock:(SelectorHookLibffiBeforeBlock)beforeBlock afterBlock:(SelectorHookLibffiAfterBlock)afterBlock{
    _beforeBlock = beforeBlock;
    _afterBlock = afterBlock;
    [self _hookLibffiClass:cls];
    Class metaClass = object_getClass(cls);
    [self _hookLibffiClass:metaClass];
}

+ (void)_hookLibffiClass:(Class)cls{
    if (!cls) return;
    NSString *classString = NSStringFromClass(cls);
    if ([classString hasPrefix:@"NSKVONotifying_"]) {
        return;
    }
    
    unsigned int outCount;
    Method *methods = class_copyMethodList(cls,&outCount);
    for (int i = 0; i < outCount; i ++) {
        Method tempMethod = *(methods + i);
        SEL selector = method_getName(tempMethod);
        BOOL isEnable =  isAllowHookLibffiSelector(cls, selector);
        if (isEnable) {
            _performLocked(^{
                IMPFunction *one = [IMPFunction new];
                one.cls = cls;
                one.originSelector = selector;
                [one constructIMPFuncWithClass:cls selecor:selector];
                NSString *key = [self signWithClass:cls selector:selector];
                [__IMPFunctionPoolDict setObject:one forKey:key];
                printf("HookLibffi - [%s %s]\n",NSStringFromClass(cls).UTF8String,NSStringFromSelector(selector).UTF8String);
            });
        }else {
            printf("cant HookLibffi [%s %s]!\n",NSStringFromClass(cls).UTF8String,NSStringFromSelector(selector).UTF8String);
        }
    }
    free(methods);
}


+ (NSString *)signWithClass:(Class)cls selector:(SEL)sel{
    NSString *sign = [NSString stringWithFormat:@"%@_%@",NSStringFromClass(cls),NSStringFromSelector(sel) ];
    return sign;
}


static void _performLocked(dispatch_block_t block) {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    block();
    dispatch_semaphore_signal(_semaphore);
}


CFTimeInterval CalculateTimeBlock(dispatch_block_t block) {
    CFTimeInterval _totoalTime = 0.0f;
    mach_timebase_info_data_t info;
    if (mach_timebase_info(&info) != KERN_SUCCESS) return 0;
    
    uint64_t start = mach_absolute_time ();
    block ();
    uint64_t end = mach_absolute_time ();
    uint64_t elapsed = end - start;
    
    uint64_t nanos = elapsed * info.numer / info.denom;
    CFTimeInterval ms = (CGFloat)nanos / NSEC_PER_SEC * 1000;
    _totoalTime += ms;
//    NSLog(@"HookLibffi class - %@ time cost : %f ms / %f \n",identify,ms,_totoalTime);
    return _totoalTime;
}


@end
