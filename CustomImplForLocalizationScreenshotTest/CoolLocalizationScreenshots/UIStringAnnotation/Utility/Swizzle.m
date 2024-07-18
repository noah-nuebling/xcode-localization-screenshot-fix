//
//  Swizzle.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import "Swizzle.h"
@import ObjectiveC.runtime;
#import "NSString+Additions.h"
@import AppKit;
#import "stdarg.h"

@implementation Swizzle

void swizzleMethod(Class class, SEL originalSelector, InterceptorFactory interceptorFactory) {
    
    /// Log
    NSLog(@"Swizzling [%s %s]", class_getName(class), sel_getName(originalSelector));
    
    /// Swaps replaces the method for `originalSelector` on `class` with the interceptor retrieved from the `interceptorFactory`. Works for ObjC and Swift afaik.
    
    /// Validate
    ///     Make sure originalSelector is defined on class or one of its superclasses.
    ///     Otherwise swizzling doesn't make sense.
    assert([class instancesRespondToSelector:originalSelector]); /// Note: This seems to work as expected on meta classes
    
    /// Get original
    ///     Note: Based on my testing, we don't need to use `class_getClassMethod` to make swizzling `class_methods` work, if we just pass in a meta class as `class`, then `class_getInstanceMethod` will get the class methods, and everything works as expected.
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    IMP originalImplementation = method_getImplementation(originalMethod);
    
    /// Make sure originalMethod is present directly on `class`
    ///     (Instead of being inherited from a superclass -> So we're not replacing the implementation of the method from the superclass, affecting all its other subclasses.)
    BOOL didAddOriginal = class_addMethod(class, originalSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    if (didAddOriginal) { /// Re-fetch
        originalMethod = class_getInstanceMethod(class, originalSelector);
    }
    
    /// Get interceptor implementation
    ///  Explanation:
    ///  We need to use the 'factory' pattern because this is the only way to reliably have the interceptor code find its original implementation.
    InterceptorBlock interceptorBlock = interceptorFactory(class, originalSelector, originalImplementation);
    IMP interceptorImplementation = imp_implementationWithBlock(interceptorBlock);
    const char *interceptorTypeEncoding = method_getTypeEncoding(originalMethod);
    
    /// Replace implementation
    method_setImplementation(originalMethod, interceptorImplementation);
}

void swizzleMethodOnClassAndSubclasses(Class baseClass, NSDictionary<MFClassSearchCriterion, id> *subclassSearchCriteria, SEL originalSelector, InterceptorFactory interceptorFactory) {
    
    ///
    /// Explanation for arg `class`:
    ///     The class whose methods to swap out. Pass in a metaclass () to swap out class methods. Otherwise instance methods will be swapped out.
    ///     You can get the metaclass of a class by calling `object_getClass()` on it.
    /// Explanation for arg `framework`:
    ///     Set this to a framework name such as @"AppKit" to only swizzle subclasses from that framework. Use this option with includeSubclasses=true.
    ///     This should be useful when swizzling subclasses of NSObject.
    ///     Set this to nil to not filter out any subclasses.
    /// Explanation for `originalSelector`:
    ///     The name of the method on class you want to intercept.
    /// Expanation for arg `interceptorFactory`:
    ///     Contains the code that is executed when the method is intercepted. Use MakeInterceptorFactory() to create.
    
    /// Log
    NSLog(@"Swizzling [%s %s] including subclasses. classSearchCriteria: %@ (Class is in %s)", class_getName(baseClass), sel_getName(originalSelector), subclassSearchCriteria, class_getImageName(baseClass));
    
    /// Validate args
    assert(baseClass != nil);
    assert(interceptorFactory != nil);
    
    /// Preprocess classSearchCriteria
    assert([subclassSearchCriteria isKindOfClass:[NSDictionary class]]);
    NSMutableDictionary *classSearchCriteria = subclassSearchCriteria.mutableCopy;
    assert(classSearchCriteria[MFClassSearchCriterionSuperclass] == nil);
    classSearchCriteria[MFClassSearchCriterionSuperclass] = baseClass;
    
    /// Find subclasses
    NSArray <Class> *subclasses = searchClasses(classSearchCriteria);
    
    /// Declare validation state
    BOOL someClassHasBeenSwizzled = NO;
    
    /// Swizzle subclasses
    for (Class subclass in subclasses) {
        
        /// Skip
        ///     We only need to swizzle one method, and then all its subclasses will also be swizzled - as long as they inherit the method and don't override it.
        if (![subclass instancesRespondToSelector:originalSelector]
            || classInheritsMethod(subclass, originalSelector)) continue;
        
        /// Swizzle
        swizzleMethod(subclass, originalSelector, interceptorFactory);
        someClassHasBeenSwizzled = YES;
    }
    
    /// Swizzle on baseClass
    ///     We always (\* mostly) want to at least swizzle on the baseClass. Even if the baseClass, doesn't define it's own implementation for `originalSelector`, and instead inherits the implementation.
    ///     That way all the subclasses inherit the swizzled method from the baseClass.
    ///     Except, if `baseClass` doesn't respond to the `originalSelector` at all, then we skip this.
    
    if ([baseClass instancesRespondToSelector:originalSelector]) {
        swizzleMethod(baseClass, originalSelector, interceptorFactory);
        someClassHasBeenSwizzled = YES;
    }
    
    /// Validate
    assert(someClassHasBeenSwizzled);
}


@end


