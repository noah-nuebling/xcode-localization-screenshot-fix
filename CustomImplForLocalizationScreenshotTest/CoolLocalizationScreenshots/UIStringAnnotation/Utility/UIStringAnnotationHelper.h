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

NSString *annotationDescription(NSAccessibilityElement *element);

+ (BOOL)accessibilityElement:(NSObject *)object containsUIString:(NSString *)uiString;
+ (BOOL)additionalUIStringHolder:(NSObject *)object containsUIString:(NSString *)uiString;

+ (NSDictionary<NSString *, NSString *> *)getUIStringsFromNonAXElement:(NSObject *)element;
+ (NSDictionary<NSString *, NSString *> *)getUIStringsFromAXElement:(NSObject <NSAccessibility>*)element;
+ (NSAccessibilityAttributeName _Nullable)getAttributeForAccessibilityNotification:(NSAccessibilityNotificationName)notification;

+ (NSAccessibilityElement *)createAnnotationElementWithLocalizationKey:(NSString *_Nonnull)localizationKey
                                                      translatedString:(NSString *_Nonnull)translatedString
                                                     developmentString:(NSString *_Nullable)developmentString
                                                translatedStringNibKey:(NSString *_Nullable)translatedStringNibKey
                                                              mergedUIString:(NSString *_Nullable)uiString;

+ (void)addAnnotations:(NSArray<NSAccessibilityElement *>*)annotations toAccessibilityElement:(NSObject<NSAccessibility>*)object withAdditionalUIStringHolder:(NSObject *)additionalUIStringHolder;
+ (void)addAnnotations:(NSArray<NSAccessibilityElement *>*)newChildren toAccessibilityElement:(id<NSAccessibility>)parent;

@end

NS_ASSUME_NONNULL_END
