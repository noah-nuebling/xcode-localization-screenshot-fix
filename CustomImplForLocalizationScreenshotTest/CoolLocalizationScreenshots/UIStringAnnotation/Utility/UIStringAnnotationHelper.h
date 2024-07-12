//
//  UIStringAnnotation.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 10.07.24.
//

#import <Foundation/Foundation.h>
#import "AppKit/AppKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIStringAnnotationHelper : NSObject

+ (BOOL)accessibilityElement:(NSObject<NSAccessibility> *)object containsUIString:(NSString *)uiString;

+ (NSDictionary *)getUIStringsFromAccessibilityElement:(NSObject <NSAccessibility>*)element;
+ (NSAccessibilityAttributeName)getAttributeForAccessibilityNotification:(NSAccessibilityNotificationName)notification;

+ (NSAccessibilityElement *)createAnnotationElementWithLocalizationKey:(NSString *_Nonnull)localizationKey
                                                      translatedString:(NSString *_Nonnull)translatedString
                                                     developmentString:(NSString *_Nullable)developmentString
                                                translatedStringNibKey:(NSString *_Nullable)translatedStringNibKey
                                                              mergedUIString:(NSString *_Nullable)uiString;

+ (void)addAnnotations:(NSArray<NSAccessibilityElement *>*)newChildren toAccessibilityElement:(id<NSAccessibility>)parent;

@end

NS_ASSUME_NONNULL_END
