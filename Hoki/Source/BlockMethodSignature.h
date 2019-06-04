//
//  ArgumentsDecode.h
//  libffiDemo
//
//  Created by Chasel on 13/03/2018.
//  Copyright © 2018 邵文涛. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ffi.h"
@interface BlockMethodSignature : NSMethodSignature

@property (nonatomic, copy) id block;
@property (nonatomic, assign) void *blockImp;
@property (readonly) ffi_type *ffiMethodReturnType;

- (NSNumber *)blockRefCount;
- (void)retainBlockRefCount;
- (void)releaseBlockRefCount;
- (const char *)blockSignature;
- (ffi_type *)getFfiArgumentTypeAtIndex:(NSUInteger)idx;

+ (instancetype)blockMethodSignatureDecodeWithBlock:(id)block;

@end
