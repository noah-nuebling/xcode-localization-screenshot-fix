//
//  Swizzle.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Swizzle : NSObject

void subclassSwizzleBodyWrapper(id theSelf, SEL selector, void (^workload)(IMP originalImplementation, NSInteger callDepth));
void swizzleMethods(Class class, bool includeSubclasses, NSString *_Nullable framework, NSString *_Nonnull swizzlePrefix, SEL firstSwizzledSelector, ...) NS_REQUIRES_NIL_TERMINATION;

@end

NS_ASSUME_NONNULL_END
