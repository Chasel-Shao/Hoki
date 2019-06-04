//
//  BiuHookForward.h
//  testDemo
//
//  Created by Chasel on 12/03/2018.
//  Copyright © 2018 邵文涛. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^SelectorHookForwardBeforeBlock)(id target, SEL sel, NSArray *argList);
typedef void(^SelectorHookForwardAfterBlock)(id target, SEL sel, NSTimeInterval interval);
//Boolean HookForwardSelector(id object, SEL selector, SelectorHookForwardBeforeBlock beforeBlock, SelectorHookForwardAfterBlock afterBlock);

@interface SelectorHookForward : NSObject
@property (nonatomic, weak, readonly) id hookForwardObject;
@property (nonatomic, copy) SelectorHookForwardBeforeBlock selectorHookForwardBeforeBlock;
@property (nonatomic, copy) SelectorHookForwardAfterBlock selectorHookForwardAfterBlock;


#pragma mark -- original
+ (instancetype)hookForwardSelectorWithClass:(Class)cls beforeBlock:(SelectorHookForwardBeforeBlock)beforeBlock afterBlock:(SelectorHookForwardAfterBlock)afterBlock;

+ (instancetype)hookForwardSelectorWithObject:(id)object selector:(SEL)selector beforeBlock:(SelectorHookForwardBeforeBlock)beforeBlock afterBlock:(SelectorHookForwardAfterBlock)afterBlock;

@end
