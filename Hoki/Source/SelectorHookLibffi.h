//
//  IMPFunctionPool.h
//  calssHookLibffiDemo
//
//  Created by Chasel on 08/04/2018.
//  Copyright © 2018 邵文涛. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef void(^SelectorHookLibffiBlock)(Class cls, SEL sel, CFTimeInterval timeCost, NSDictionary *argDict, id returnValue);
typedef void(^SelectorHookLibffiBeforeBlock)(Class cls, SEL sel);
typedef void(^SelectorHookLibffiAfterBlock)(Class cls, SEL sel, CFTimeInterval timeCost);
static CFTimeInterval CalculateTimeBlock(dispatch_block_t block);

@interface IMPFunction : NSObject

- (void *)constructIMPFuncWithClass:(Class)cls selecor:(SEL)sel;

@end


@interface SelectorHookLibffi : NSObject

+ (instancetype)sharedInstance;
+ (void)hookLibffiClass:(Class)cls beforeBlock:(SelectorHookLibffiBeforeBlock)beforeBlock afterBlock:(SelectorHookLibffiAfterBlock)afterBlock;

@end


