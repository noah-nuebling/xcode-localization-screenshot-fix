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
#import "Utility.h"

@implementation Swizzle

void swizzleMethodOnClassAndSubclasses(Class baseClass, NSString *framework, SEL originalSelector, InterceptorFactory interceptorFactory) {
    
    ///
    /// Explanation for arg `class`:
    ///     The class whose methods to swap out. Pass in a metaclass () to swap out class methods. Otherwise instance methods will be swapped out.
    ///     You can get the metaclass of a class by calling `object_getClass()` on it.
    /// Explanation for `selector`:
    ///     The name of the method on class you want to intercept.
    /// Explanation for arg `includeSubclasses`:
    ///     Set this to true to swap out the methods for `class` as well as *all* subclasses of `class`. If you set this to false, only subclasses which inherit the swapped out methods from `class` will be affected (And subclasses which override the swapped out methods won't be affected.). Setting this to true,might make this function slow. (Which might affect app startup time)
    /// Explanation for arg `framework`:
    ///     Set this to a framework name such as @"AppKit" to only swizzle subclasses from that framework. Use this option with includeSubclasses=true.
    ///     This should be useful when swizzling subclasses of NSObject.
    ///     Set this to nil to not filter out any subclasses.
    /// Expanation for arg `interceptorFactory`:
    ///     Contains the code that is executed when the method is intercepted. Use MakeInterceptorFactory() to create. +
    
    /// Log
    NSLog(@"Swizzling [%s %s] including subclasses. filterToFramework: %@ (Class is in %s)", class_getName(baseClass), sel_getName(originalSelector), framework, class_getImageName(baseClass));
    
    /// Validate args
    assert(baseClass != nil);
    assert(interceptorFactory != nil);
    
    /// Find subclasses
    NSArray <NSDictionary *> *subclasses = _subclassesOfClass(baseClass, framework, false);
    
    /// Declare validation state
    BOOL someClassHasBeenSwizzled = NO;
    
    /// Swizzle subclasses
    for (NSDictionary *subclassDict in subclasses) {

        Class subclass = subclassDict[@"class"];
        
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
    
    if (class_getInstanceMethod(baseClass, originalSelector) != nil) {
        swizzleMethod(baseClass, originalSelector, interceptorFactory);
        someClassHasBeenSwizzled = YES;
    }
    
    /// Validate
    assert(someClassHasBeenSwizzled);
}


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

///
/// Other
///

static NSArray<NSDictionary<NSString *, id> *> *_subclassesOfClass(Class baseClass, NSString *framework, BOOL includeBaseClass) {
        
    /// TODO: Use `objc_enumerateClasses` `objc_copyClassNamesForImage` or similar instead of classList. Should be 1000x faster.
    
    /// Notes:
    /// - I'm not sure the caching as we currently do it helps performance? Might be slowing things down.
    ///     Maybe if we made the cache a tree structure, that would help. But so far it's not super slow.
    /// - The @"depth" is unused at the time of writing.
    
    /// Preprocess
    BOOL baseClassIsMetaClass = class_isMetaClass(baseClass);
    NSString *baseClassName = NSStringFromClass(baseClass);
    if (framework == nil) framework = @"";
    
    /// Get cache
    static NSMutableDictionary *_cache = nil;
    if (_cache == nil) {
        _cache = [NSMutableDictionary dictionary];
    }
    
    /// Look up result in cache
    NSArray *resultFromCache = _cache[stringf(@"%@%@", baseClassName, framework)];
    if (resultFromCache != nil) {
        return resultFromCache;
    }
    
    /// Declare result
    NSMutableArray<NSDictionary<NSString *, id> *> *subclasses = [NSMutableArray array];
    
    /// Add baseClass
    if (includeBaseClass) {
        [subclasses addObject:@{
            @"class": baseClass,
            @"depth": @0,
        }];
    }
    
    /// Get classes from framework
    NSArray<Class> *classes = getClassesFromFramework(framework);
    
    /// Iterate classes
    ///     And fill result
    for (Class class in classes) {
        
        /// Turn class into metaclass
        if (baseClassIsMetaClass) {
            class = object_getClass(class);
        }
        
        /// Check if `baseClass` is a superclass of `class`
        BOOL baseClassIsSuperclass = NO;
        Class superclass = class_getSuperclass(class);
        int superclassDistance = 1;
        while (true) {
            
            if (superclass == nil) {
                baseClassIsSuperclass = NO;
                break;
            }
            if (baseClass == superclass) {
                baseClassIsSuperclass = YES;
                break;
            }
            superclass = class_getSuperclass(superclass);
            superclassDistance += 1;
        }

        /// Store in result
        if (baseClassIsSuperclass) {
            [subclasses addObject:@{
                @"class": class,
                @"depth": @(superclassDistance)
            }];
        }
    }
    
    /// Store in cache
    _cache[stringf(@"%@%@", baseClassName, framework)] = subclasses;
    
    /// Return
    return subclasses;
}


NSArray<Class> *getClassesFromFramework(NSString *frameworkNameNS) {

    /// Trying to write cool confusing c code without comments 😎
    
    static NSMutableDictionary *_cache = nil;
    if (_cache == nil) {
        _cache = [NSMutableDictionary dictionary];
    }
    
    NSArray *resultFromCache = _cache[frameworkNameNS];
    if (resultFromCache != nil) {
        return resultFromCache;
    }
    
    bool frameworkIsSpecified = frameworkNameNS != nil && frameworkNameNS.length != 0;
    
    char *frameworkPathComponent = NULL;
    if (frameworkIsSpecified) {
        const char *frameworkName = [frameworkNameNS cStringUsingEncoding:NSUTF8StringEncoding];
        asprintf(&frameworkPathComponent, "/%s.framework/", frameworkName);
    }
    
    unsigned int count;
    Class *classes = objc_copyClassList(&count);
    
    NSMutableArray<Class> *result = [NSMutableArray array];
    
    for (int i = 0; i < count; i++) {
        
        Class class = classes[i];
        
        bool classIsInFramework = !frameworkIsSpecified || (strstr(class_getImageName(class), frameworkPathComponent) != NULL);
        
        if (classIsInFramework) {
            [result addObject:class];
        }
    }
    free(classes);
    
    _cache[frameworkNameNS] = result;
    
    return result;
}

static BOOL classInheritsMethod(Class class, SEL selector) {
    
    /// Returns YES if the class inherits the method for `selector` from its superclass, instead of defining its own implementation.
    /// Note: Also see `class_copyMethodList`
    
    /// Main check
    Method classMethod = class_getInstanceMethod(class, selector);
    Method superclassMethod = class_getInstanceMethod(class_getSuperclass(class), selector);
    BOOL classInherits = classMethod == superclassMethod;
    
    /// ?
    assert(classMethod != NULL); /// Not sure if this is good or necessary
    
    /// Return
    return classInherits;
}


@end


