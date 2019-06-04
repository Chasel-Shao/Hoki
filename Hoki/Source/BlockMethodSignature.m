//
//  ArgumentsDecode.m
//  libffiDemo
//
//  Created by Chasel on 13/03/2018.
//  Copyright © 2018 邵文涛. All rights reserved.
//

#import "BlockMethodSignature.h"
#import <objc/runtime.h>
#import "ffi.h"

#if __cplusplus
extern "C" {
#endif
    // Runtime support functions used by compiler when generating copy/dispose helpers
    enum {
        // see function implementation for a more complete description of these fields and combinations
        BLOCK_FIELD_IS_OBJECT   =  3,  // id, NSObject, __attribute__((NSObject)), block, ...
        BLOCK_FIELD_IS_BLOCK    =  7,  // a block variable
        BLOCK_FIELD_IS_BYREF    =  8,  // the on stack structure holding the __block variable
        BLOCK_FIELD_IS_WEAK     = 16,  // declared __weak, only used in byref copy helpers
        BLOCK_BYREF_CALLER      = 128, // called from __block (byref) copy/dispose support routines.
    };
    
    enum {
        BLOCK_ALL_COPY_DISPOSE_FLAGS =
        BLOCK_FIELD_IS_OBJECT | BLOCK_FIELD_IS_BLOCK | BLOCK_FIELD_IS_BYREF |
        BLOCK_FIELD_IS_WEAK | BLOCK_BYREF_CALLER
    };
    
    // Runtime entry point called by compiler when assigning objects inside copy helper routines
    //    BLOCK_EXPORT void _Block_object_assign(void *destAddr, const void *object, const int flags);
    //    // BLOCK_FIELD_IS_BYREF is only used from within block copy helpers
    //
    //
    //    // runtime entry point called by the compiler when disposing of objects inside dispose helper routine
    //    BLOCK_EXPORT void _Block_object_dispose(const void *object, const int flags);
    //
    //    // Other support functions
    //
    //    // runtime entry to get total size of a closure
    //    BLOCK_EXPORT size_t Block_size(void *aBlock);
    //
    //    // indicates whether block was compiled with compiler that sets the ABI related metadata bits
    //    BLOCK_EXPORT bool _Block_has_signature(void *aBlock)
    //    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
    //
    //    // returns TRUE if return value of block is on the stack, FALSE otherwise
    //    BLOCK_EXPORT bool _Block_use_stret(void *aBlock)
    //    __OSX_AVAILABLE_STARTING(    , __IPHONE_4_3);
    //
    //    // Returns a string describing the block's parameter and return types.
    //    // The encoding scheme is the same as Objective-C @encode.
    //    // Returns NULL for blocks compiled with some compilers.
    //    BLOCK_EXPORT const char * _Block_signature(void *aBlock)
    //    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
    //
    //    // Returns a string describing the block's GC layout.
    //    // Returns NULL for blocks compiled with some compilers.
    //    BLOCK_EXPORT const char * _Block_layout(void *aBlock)
    //    __OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_4_3);
    enum {
        BLOCK_DEALLOCATING =      (0x0001),  // runtime
        BLOCK_REFCOUNT_MASK =     (0xfffe),  // runtime
        BLOCK_NEEDS_FREE =        (1 << 24), // runtime
        BLOCK_HAS_COPY_DISPOSE =  (1 << 25), // compiler
        BLOCK_HAS_CTOR =          (1 << 26), // compiler: helpers have C++ code
        BLOCK_IS_GC =             (1 << 27), // runtime
        BLOCK_IS_GLOBAL =         (1 << 28), // compiler
        BLOCK_USE_STRET =         (1 << 29), // compiler: undefined if !BLOCK_HAS_SIGNATURE
        BLOCK_HAS_SIGNATURE  =    (1 << 30)  // compiler
    };
    
    struct Fake_block_descriptor {
        unsigned long int reserved;
        unsigned long int size;
        void *rest[1];
        /*
         // requires BLOCK_HAS_COPY_DISPOSE
         void (*copy)(void *dst, const void *src);
         void (*dispose)(const void *);
         */
        
        /*
         // requires BLOCK_HAS_SIGNATURE
         const char *signature;
         const char *layout;
         */
    };
    
    struct Fake_block_layout {
        void *isa;
        volatile int flags; // contains ref count
        int reserved;
        void (*invoke)(void *, ...);
        struct Fake_block_descriptor *descriptor;
        /* variables */
        void *rest[6];
    };
    
    
    //////////////////////////////////////////////////////////////
    
//    union isa_t
//    {
//        isa_t() { };
//        isa_t(uintptr_t value) : bits(value) { };
//        Class cls;
//        uintptr_t bits;
//    };
//
//    struct fake_object {
//        union isa_t isa;
//    };
    
//    struct objc_class : objc_object {
//        // Class ISA;
//        Class superclass;
//        cache_t cache;             // formerly cache pointer and vtable
//        class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags
//    }
    


    
    
#if __cplusplus
}
#endif


@interface BlockMethodSignature()


@end

@implementation BlockMethodSignature

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSAssert(YES, @"please the factory method");
    }
    return self;
}


+ (instancetype)blockMethodSignatureDecodeWithBlock:(id)block {
    struct Fake_block_layout *tempBlock =  (__bridge struct Fake_block_layout *)(block);
    
    if (tempBlock->flags & BLOCK_HAS_SIGNATURE) {
        struct Fake_block_descriptor *descriptor = tempBlock->descriptor;
        if (tempBlock->flags & BLOCK_HAS_COPY_DISPOSE) {
            const char*  signature  = (const char*)descriptor->rest[2];
            BlockMethodSignature *ms =  (BlockMethodSignature *)[BlockMethodSignature signatureWithObjCTypes:signature];
            ms.block = block;
            ms.blockImp = tempBlock->invoke;
            return ms;
        } else {
            const char*  signature  = descriptor->rest[0];
            BlockMethodSignature *ms =  (BlockMethodSignature *)[BlockMethodSignature signatureWithObjCTypes:signature];
            ms.block = block;
            ms.blockImp = tempBlock->invoke;
            return ms;
        }
    }
    return nil;
}

- (const char *)blockSignature{
    struct Fake_block_layout *tempBlock =  (__bridge struct Fake_block_layout *)(_block);
    struct Fake_block_descriptor *descriptor = tempBlock->descriptor;
    if (tempBlock->flags & BLOCK_HAS_SIGNATURE) {
        if (tempBlock->flags & BLOCK_HAS_COPY_DISPOSE) {
            const char*  signature  = descriptor->rest[2];
            return signature;
        } else {
            const char*  signature  = descriptor->rest[0];
            return signature;
        }
    }
    return NULL;
}

-(void)setBlockImp:(void *)blockImp{
    if (_block) {
        _blockImp = blockImp;
        ((__bridge struct Fake_block_layout *)_block)->invoke = blockImp;
    }
}


static char kBlockRefCountKey;
-(void)retainBlockRefCount{
    NSNumber *currentRefCount = [self blockRefCount];
    if (_block) {
        objc_setAssociatedObject(_block, &kBlockRefCountKey, @((currentRefCount.integerValue + 1)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        NSAssert(YES, @"block has been released..");
    }
}
-(void)releaseBlockRefCount{
    NSNumber *currentRefCount = [self blockRefCount];
    if (_block) {
        if (currentRefCount.integerValue > 0) {
            objc_setAssociatedObject(_block, &kBlockRefCountKey, @((currentRefCount.integerValue - 1)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else {
        NSAssert(YES, @"block has been released..");
    }
}

-(NSNumber *)blockRefCount{
    if (_block) {
        id refCount = objc_getAssociatedObject(_block, &kBlockRefCountKey);
        if (refCount == nil) {
            objc_setAssociatedObject(_block, &kBlockRefCountKey, @(0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }else {
          return  objc_getAssociatedObject(_block, &kBlockRefCountKey);
        }
    }
    return @(0);
}


- (ffi_type *)getFfiArgumentTypeAtIndex:(NSUInteger)idx{
    const char *type = [self getArgumentTypeAtIndex:idx];
    return [self ffiTypeWithEncodingChar:type];
}

- (ffi_type *)ffiMethodReturnType{
    return [self ffiTypeWithEncodingChar:self.methodReturnType];
}

- (ffi_type *)ffiTypeWithEncodingChar:(const char *)types
{
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


@end

























