//
//  Utility.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 08.07.24.
//

#import <Foundation/Foundation.h>
@import AppKit.NSAccessibility;

NS_ASSUME_NONNULL_BEGIN

@interface Utility : NSObject

void BREAKPOINT(id context);

void listMethods(id obj);
void printClassHierarchy(NSObject *obj);

NSString *pureString(id value);
+ (NSObject *)getRepresentingToolTipHolderForObject:(NSObject *)object;
+ (NSObject <NSAccessibility>* _Nullable)getRepresentingAccessibilityElementForObject:(NSObject <NSAccessibility>*)object ;

void countRecursions(id recursionDepthKey, void (^workload)(NSInteger recursionDepth));

@end

NS_ASSUME_NONNULL_END
