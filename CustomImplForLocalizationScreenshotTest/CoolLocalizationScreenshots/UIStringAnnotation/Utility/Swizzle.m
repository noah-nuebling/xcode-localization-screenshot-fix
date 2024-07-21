//
//  Swizzle.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

///
/// Discussion:
///
/// Why use the `InterceptorFactory` pattern?
///     When swizzling, after your swizzled method (we call it the `interceptor`) is called, you normally always want to call the original implementation of the method which was intercepted.
///     The usual pattern for intercepting a method with name `-[methodName]`, is to define a method `-[swizzled_methodName]`, and then swap the implementations of the two.
///     Then to invoke the original implementation inside the interceptor, you'd call `[self swizzled_methodName]` (which invokes the original implementation of `[self methodName]` since the two implementations have been swapped) .
///     However, this does not invoke the original implementation in all cases.
///     For example, if your interceptor is invoked from a subclass with a `[super methodName]` call, and the subclass also has an implementation for `[swizzled_methodName]` then `[self swizzled_methodName]` would be invoking the original implementation on the subclass.
///
///     This stuff lead to really complicated issues in the implementation of `swizzleMethodOnClassAndSubclasses()`. (We deleted the detailed notes on that, I think in commit fc3064033f974c454aebb479f20bb0cc3d0eebb6)
///
///     I've thought about the problem quite a bit and I think the only way to reliably get a reference to the original implementation, is to store a reference to the original implementation directly inside the interceptor function. You can't dynamically figure it out without extra information.
///         (I tried a weird appraoch with counting recursions on the interceptor to infer `super` invokations and then find the right implementation  which worked pretty well but was complicated and broke for actually recursive functions. I don't think it's possible to find a robust solution.)
///     Thatt's where the InterceptorFactory comes in. The swizzling code passes the originalImplementation (and some other metadata) to the InterceptorFactory which then creates an Interceptor function that can reliably call its original implementation. - And then the swizzling code replaces the original implementation with the Interceptor.
///
///     Such an InterceptorFactory is quite tedious to write, since you'd have to write all the arguments and types again and again and declare complicated objc blocks. But that's what the MakeInterceptorFactory() macro is for! It provides a clean syntax.
///
///     We have to make it a macro, not a function I think. since the compiler needs to be aware of the argument number and types and stuff. I don't remember. But I tried dynamically parsing the arguments and passing them on to the original implementation from inside the interceptor but it didn't work. varargs didn't work. All the arguments were in weird registers. You'd have to like hardcode knowledge about the calling convention to do this. So we have to declare the interceptor method and its factory with the right types and argument number at compile time. And making that easier is only possible with a macro (I think? I don't remember exactly.)
///

#import "Swizzle.h"
@import ObjectiveC.runtime;
#import "NSString+Additions.h"
@import AppKit;
#import "stdarg.h"

@implementation Swizzle

void swizzleMethod(Class class, SEL selector, InterceptorFactory interceptorFactory) {
    
    /// Replaces the method for `selector` on `class` with the interceptor retrieved from the `interceptorFactory`.
    /// - Use the `MakeInterceptorFactor()` macro to conveniently create an interceptor factory.
    /// - Note on arg `class`:
    ///     Pass in a metaclass to swap out class methods instead of instance methods.
    ///     You can get the metaclass of a class `baseClass` by calling `object_getClass(baseClass)`.
    
    /// Log
    NSLog(@"Swizzling [%s %s]", class_getName(class), sel_getName(selector));
    
    /// Validate
    ///     Make sure `selector` is defined on class or one of its superclasses.
    ///     Otherwise swizzling doesn't make sense.
    assert([class instancesRespondToSelector:selector]); /// Note: This seems to work as expected on meta classes
    
    /// Get original
    ///     Note: Based on my testing, we don't need to use `class_getClassMethod` to make swizzling class methods work, if we just pass in a meta class as `class`, then `class_getInstanceMethod` will get the class methods, and everything works as expected.
    Method originalMethod = class_getInstanceMethod(class, selector);
    IMP originalImplementation = method_getImplementation(originalMethod);
    
    /// Make sure originalMethod is present directly on `class`
    ///     (Instead of being inherited from a superclass -> So we're not replacing the implementation of the method from the superclass, affecting all its other subclasses.)
    BOOL didAddOriginal = class_addMethod(class, selector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    if (didAddOriginal) { /// Re-fetch
        originalMethod = class_getInstanceMethod(class, selector);
    }
    
    /// Get interceptor implementation
    ///  Explanation:
    ///  We need to use the 'factory' pattern because this is the only way to reliably have the interceptor code find its original implementation.
    InterceptorBlock interceptorBlock = interceptorFactory(class, selector, originalImplementation);
    IMP interceptorImplementation = imp_implementationWithBlock(interceptorBlock);
    
    /// Replace implementation
    IMP previousImplementation = method_setImplementation(originalMethod, interceptorImplementation);
    
    /// Validate
    assert(previousImplementation == originalImplementation);
}

void swizzleMethodOnClassAndSubclasses(Class baseClass, NSDictionary<MFClassSearchCriterion, id> *subclassSearchCriteria, SEL selector, InterceptorFactory interceptorFactory) {

    /// Log
    NSLog(@"Swizzling [%s %s] including subclasses. subclassSearchCriteria: %@ (Class is in %s)", class_getName(baseClass), sel_getName(selector), subclassSearchCriteria, class_getImageName(baseClass));
    
    /// Validate args
    assert(baseClass != nil);
    assert(interceptorFactory != nil);
    
    /// Preprocess classSearchCriteria
    assert([subclassSearchCriteria isKindOfClass:[NSDictionary class]]);
    NSMutableDictionary *classSearchCriteria = subclassSearchCriteria.mutableCopy;
    assert(classSearchCriteria[MFClassSearchCriterionSuperclass] == nil);
    classSearchCriteria[MFClassSearchCriterionSuperclass] = baseClass;
    
    /// Find subclasses
    NSArray<Class> *subclasses = searchClasses(classSearchCriteria);
    
    /// Declare validation state
    BOOL someClassHasBeenSwizzled = NO;
    
    /// Swizzle subclasses
    for (Class subclass in subclasses) {
        
        /// Skip
        ///     We only need to swizzle one method, and then all its subclasses will also be swizzled - as long as they inherit the method and don't override it.
        if (![subclass instancesRespondToSelector:selector]
            || classInheritsMethod(subclass, selector)) continue;
        
        /// Swizzle
        swizzleMethod(subclass, selector, interceptorFactory);
        someClassHasBeenSwizzled = YES;
    }
    
    /// Swizzle on baseClass
    ///     We (almost) always want to at least swizzle on the baseClass. Even if the baseClass, doesn't define it's own implementation for `selector`, and instead inherits the implementation.
    ///     That way all the subclasses inherit the swizzled method from the baseClass.
    ///     Except, if `baseClass` doesn't respond to the `selector` at all, then we skip this.
    
    if ([baseClass instancesRespondToSelector:selector]) {
        swizzleMethod(baseClass, selector, interceptorFactory);
        someClassHasBeenSwizzled = YES;
    }
    
    /// Validate
    if (!someClassHasBeenSwizzled) {
        NSLog(@"Error: Neither %@ nor any of the subclasses we found for it (%@) have been swizzled. This is probably because none of the processed classes implement a method for selector %@. We used the search criteria: %@", baseClass, subclasses, selector, subclassSearchCriteria);
        assert(false);
    }
    
}


@end


