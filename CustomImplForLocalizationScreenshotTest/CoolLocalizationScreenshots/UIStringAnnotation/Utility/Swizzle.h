//
//  Swizzle.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Swizzle : NSObject

void swizzleMethods(Class class, bool includeSubclasses, NSString *swizzlePrefix, SEL firstSwizzledSelector, ...) NS_REQUIRES_NIL_TERMINATION;

@end

NS_ASSUME_NONNULL_END
