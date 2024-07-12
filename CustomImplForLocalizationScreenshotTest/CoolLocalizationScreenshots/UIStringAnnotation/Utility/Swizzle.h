//
//  Swizzle.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Swizzle : NSObject

+ (void)swizzleMethodsOnClass:(Class)class swizzlePrefix:(NSString *)swizzlePrefix swizzledSelectors:(SEL)firstSelector, ... NS_REQUIRES_NIL_TERMINATION;
void swizzleMethod(Class class, SEL originalSelector, SEL swizzledSelector);

@end

NS_ASSUME_NONNULL_END
