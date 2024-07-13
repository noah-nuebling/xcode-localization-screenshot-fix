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

void listMethods(id obj);
void printClassHierarchy(NSObject *obj);
+ (NSObject *)getRepresentingToolTipHolderForObject:(NSObject *)object;
+ (NSObject <NSAccessibility>* _Nullable)getRepresentingAccessibilityElementForObject:(NSObject <NSAccessibility>*)object ;

@end

NS_ASSUME_NONNULL_END
