//
//  SuperHook.m
//  libffiDemo
//
//  Created by Chasel on 14/03/2018.
//  Copyright © 2018 邵文涛. All rights reserved.
//

#import "BlockHook.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "BlockMethodSignature.h"

@interface BlockHook(){
    ffi_cif *_cif;
    ffi_closure *_closure;
    ffi_type ** _argTypes;
    void *_replacementFunc;
    void *_hookBlockFunc;
}
@property (nonatomic,strong) BlockMethodSignature *blockMethodSignature;
@property (nonatomic, copy,readwrite)  id hookBlock;

@end


@implementation BlockHook

- (instancetype)init
{
    self = [super init];
    if (self) {
        //
    }
    return self;
}

+ (instancetype)hookBlock:(id)hookBlock before:(BlockHookBlock)beforeBlock after:(BlockHookBlock)afterBlock{
    BlockHook *blockHook = [[BlockHook alloc] init];
    if (hookBlock == nil || ![hookBlock isKindOfClass:NSClassFromString(@"NSBlock")]) {
        return blockHook;
    }
    blockHook.hookBlock = [hookBlock copy];
    blockHook.beforeBlock = [beforeBlock copy];
    blockHook.afterBlock = [afterBlock copy];
    return blockHook;
}

- (void)setHookBlock:(id)hookBlock{
    _hookBlock = hookBlock;
    [self constructHook];
}

- (BlockMethodSignature *)blockMethodSignature{
    if(_blockMethodSignature == nil){
        if (_hookBlock) {
            _blockMethodSignature = [BlockMethodSignature blockMethodSignatureDecodeWithBlock:self.hookBlock];
        }
    }
    return _blockMethodSignature;
}

-(void)constructHook{
    unsigned int  argumentsCount = (unsigned int)self.blockMethodSignature.numberOfArguments;
    _closure = ffi_closure_alloc(sizeof(ffi_closure), &_replacementFunc);
    _cif = malloc(sizeof(ffi_cif));
    
    _argTypes = malloc(sizeof(ffi_type *) * argumentsCount);
    ffi_type *returnType = self.blockMethodSignature.ffiMethodReturnType;
    for (int i = 0; i < argumentsCount; i ++) {
        ffi_type *currentType = [self.blockMethodSignature getFfiArgumentTypeAtIndex:i];
        _argTypes[i] = currentType;
    }
    
    ffi_status status1 = ffi_prep_cif(_cif, FFI_DEFAULT_ABI, argumentsCount, returnType, _argTypes);
    if (status1 == FFI_OK) {
        ffi_status status2 =  ffi_prep_closure_loc(_closure, _cif, _hook_block_interpreter, (__bridge void *)(self), _replacementFunc);
        if (status2 == FFI_OK) {
            BOOL isDirtyBlock =  (self.blockMethodSignature.blockRefCount.integerValue > 0);
            if (isDirtyBlock) {
                // have been exchanged
            } else {
                // thread lock
                _hookBlockFunc = _blockMethodSignature.blockImp;
                _blockMethodSignature.blockImp = _replacementFunc;
            }
            [self.blockMethodSignature retainBlockRefCount];
        }
    }
}

NSArray* _hook_block_arguments(BlockMethodSignature *blockMethodSignature, void ** args){
    NSMutableArray *argumentArray = [NSMutableArray array];
    NSUInteger argumentsCount =  blockMethodSignature.numberOfArguments;
    if (argumentsCount > 1) {
        for (NSUInteger i  = 1; i < argumentsCount; i++) {
            const char *types = [blockMethodSignature getArgumentTypeAtIndex:i];
            
#define GETBASICTYPE(_type) \
if (0 == strcmp(types, @encode(_type))) {\
_type arg;\
memcpy(&arg, args[i],sizeof(_type));\
[argumentArray addObject:@(arg)];\
continue;\
}
            
            GETBASICTYPE(char)
            GETBASICTYPE(unichar)
            GETBASICTYPE(bool)
            GETBASICTYPE(float)
            GETBASICTYPE(double)
            GETBASICTYPE(int)
            GETBASICTYPE(u_int)
            GETBASICTYPE(int8_t)
            GETBASICTYPE(uint8_t)
            GETBASICTYPE(int16_t)
            GETBASICTYPE(uint16_t)
            GETBASICTYPE(int32_t)
            GETBASICTYPE(uint32_t)
            GETBASICTYPE(int64_t)
            GETBASICTYPE(uint64_t)
            GETBASICTYPE(long)
            GETBASICTYPE(u_long)
            
#define GETSTRUCTTYPE(_type) \
if (0 == strcmp(types, @encode(_type))) {\
_type *arg;\
arg = args[i];\
[argumentArray addObject:NSStringFrom##_type(*arg)];\
continue;\
}
            
            GETSTRUCTTYPE(CGPoint)
            GETSTRUCTTYPE(CGSize)
            GETSTRUCTTYPE(CGRect)
            GETSTRUCTTYPE(CGVector)
            GETSTRUCTTYPE(UIOffset)
            GETSTRUCTTYPE(UIEdgeInsets)
            GETSTRUCTTYPE(CGAffineTransform)
            
            if (0 == strcmp(types, @encode(SEL))) {
                SEL arg;
                memcpy(&arg, args[i], sizeof(SEL));
                [argumentArray addObject:NSStringFromSelector(arg)];
                continue;
            }
            if (types[0] == '^') {
                // c poiner
                continue;
            }
            if (types[0] == '@') {
                // oc object
                void *argumentPtr = args[i];
                id param = (__bridge id)(*(void**)argumentPtr);
                [argumentArray addObject:param];
                continue;
            }
            if (types[0] == '#') {
                // oc class
                [argumentArray addObject:(__bridge Class)args[i]];
                continue;
            }
            
        }
    }
    return argumentArray;
}

static void _hook_block_interpreter(ffi_cif *cif, void *ret, void **args, void *userdata)
{
    BlockHook *blockHook = (__bridge BlockHook*)userdata;
    BlockMethodSignature *blockMethodSignature = blockHook->_blockMethodSignature;
    NSArray *arguments =  _hook_block_arguments(blockMethodSignature,args);
    if (blockHook.beforeBlock) {
        blockHook.beforeBlock(arguments, ret);
    }
    ffi_call(cif,  blockHook->_hookBlockFunc , ret, args);
    if (blockHook.afterBlock) {
        blockHook.afterBlock(arguments, ret);
    }
}

void _hook_block_invocation(id block, void **args){
    BlockMethodSignature *beforeBlockSignature = [BlockMethodSignature blockMethodSignatureDecodeWithBlock:block];
    NSUInteger argumentsCount = beforeBlockSignature.numberOfArguments;
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:beforeBlockSignature];
    void *argBuf = NULL;
    for (NSUInteger idx = 1; idx < argumentsCount; idx++) {
        const char *type = [beforeBlockSignature getArgumentTypeAtIndex:idx];
        NSUInteger argSize;
        NSGetSizeAndAlignment(type, &argSize, NULL);
        if (!(argBuf = reallocf(argBuf, argSize))) {
            NSLog(@"Failed to allocate memory for block invocation.");
            return;
        }
        memcpy(argBuf, args[idx], argSize);
        [blockInvocation setArgument:argBuf atIndex:idx];
    }
    [blockInvocation invokeWithTarget:block];
    if (argBuf != NULL) {
        free(argBuf);
    }
}


- (void)dealloc{
    free(_cif);
    free(_argTypes);
    ffi_closure_free(_closure);
    
    [_blockMethodSignature releaseBlockRefCount];
    printf("hook block dealloc \n");
    
    // lock
    if ([[_blockMethodSignature blockRefCount] integerValue] <= 0) {
        _blockMethodSignature.blockImp = _hookBlockFunc;
    }
    
}


@end














