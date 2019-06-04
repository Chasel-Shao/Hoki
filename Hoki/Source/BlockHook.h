//
//  SuperHook.h
//  libffiDemo
//
//  Created by Chasel on 14/03/2018.
//  Copyright © 2018 邵文涛. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ffi.h"

typedef void(^BlockHookBlock)(NSArray *arguments, void *ret);

@interface BlockHook : NSObject
@property (nonatomic, copy,readonly)  id hookBlock;
@property (nonatomic, copy) BlockHookBlock beforeBlock;
@property (nonatomic, copy) BlockHookBlock afterBlock;

+ (instancetype)hookBlock:(id)hookBlock before:(BlockHookBlock)beforeBlock after:(BlockHookBlock)afterBlock;

@end
