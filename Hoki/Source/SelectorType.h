//
//  SelectorType.h
//  HookDemo
//
//  Created by Chasel on 2018/6/5.
//  Copyright © 2018 邵文涛. All rights reserved.
//

#import <UIKit/UIKit.h>


#define kPrefix @"biu_"
#define HKLog(...) printf("HOOKLOG - %s\n", [[NSString stringWithFormat:__VA_ARGS__] UTF8String])

@interface SelectorType : NSObject

BOOL isAllowHookLibffiSelector(Class cls, SEL sel);
BOOL _is_object_type(const char *argumentType);

@end
