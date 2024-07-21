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

#define getReturnAddress() \
    __builtin_return_address(0) /// If this fails, `backtrace()` should be more robust

NSString *getExecutablePath(void);
NSString *getImagePath(void *address);
NSString *getSymbol(void *address);

typedef NSString * MFClassSearchCriterion NS_TYPED_ENUM;
#define MFClassSearchCriterionFrameworkName @"framework"
#define MFClassSearchCriterionClassNamePrefix @"namePrefix"
#define MFClassSearchCriterionProtocol @"protocol"
#define MFClassSearchCriterionSuperclass @"superclass"

NSArray<Class> *searchClasses(NSDictionary<MFClassSearchCriterion, id> *criteria);
BOOL classInheritsMethod(Class class, SEL selector);

void BREAKPOINT(id context);

void listMethods(id obj);
void printClassHierarchy(NSObject *obj);

NSString *pureString(id value);
+ (NSObject *)getRepresentingToolTipHolderForObject:(NSObject *)object;
+ (NSObject <NSAccessibility> * _Nullable)getRepresentingAccessibilityElementForObject:(id)object;

void countRecursions(id recursionDepthKey, void (^workload)(NSInteger recursionDepth));

@end

NS_ASSUME_NONNULL_END
