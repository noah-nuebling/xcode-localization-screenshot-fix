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

static NSString *_swizzlePrefix(void) {
    return @"swizzled_";
}

static BOOL isSwizzledSelector(SEL selector) {
    NSRange prefixRange = [NSStringFromSelector(selector) rangeOfString:_swizzlePrefix()];
    BOOL isSwizzled = prefixRange.location == 0;
    return isSwizzled;
}

static SEL getOriginalSelector(SEL swizzledSelector) {
    
    assert(isSwizzledSelector(swizzledSelector));
    
    NSString *selectorString = NSStringFromSelector(swizzledSelector);
    NSRange prefixRange = [selectorString rangeOfString:_swizzlePrefix()];
    NSString *resultSelectorString = [selectorString substringFromIndex:prefixRange.length];
    SEL resultSelector = NSSelectorFromString(resultSelectorString);
    
    return resultSelector;
}

static SEL getSwizzledSelector(SEL originalSelector) {
    
    assert(!isSwizzledSelector(originalSelector));
    
    NSString *selectorString = NSStringFromSelector(originalSelector);
    NSString *resultSelectorString = [_swizzlePrefix() stringByAppendingString:selectorString];
    SEL resultSelector = NSSelectorFromString(resultSelectorString);
    
    return resultSelector;
}


void subclassSwizzleBodyWrapper(id self, SEL _cmd, void (^body)(IMP originalImplementation, NSInteger callDepth)) {
    
    /// To prevent an infinite loop:
    ///     Wrap the entire body of `swizzled_do` inside a block and pass that block to this function.
    ///     This will only work and is only necessary in certain scenarios. See explanation below.
    ///     To be safe just use this inside every `swizzled_` implementation that you're applying using `includeSubclasses`
    ///
    /// Explanation:
    ///
    ///     In the following scenario, an infinite loop can occur: (which this will prevent)
    ///
    ///     Setup pt 1:
    ///     There's a class `A` and its subclass `B`. A method with selector `-[A do]` is defined on `A`. `B` overrides the method `do` from its superclass `A` with `-[B do]`, and inside this method, B calls the A's implementation with the line `[super do]`.
    ///
    ///     Setup pt 2:
    ///     Now, we want to intercept calls to `do` on `A` as well as all of its subclasses (such as `B`). So on `A`, we define an interceptor method `-[A swizzled_do]` and pass it to `swizzleMethods()` with `includeSubclasses` set to `true`, which will swap out the implementation for both `-[A do]` and `-[B do]` with the implementation for `-[A swizzled_do]`.
    ///
    ///     Setup pt 3:
    ///     Inside the interceptor `-[A swizzled_do]`, we want to call the original implementation of `do`. To do this, we call `[self swizzled_do]`.
    ///     (`swizzled_do` calls the original implementation of `do`, since the implementations have been swapped out aka swizzled!)
    ///     `[self swizzled_do]` will invoke the original implementation of either -[A do]` or `-[B do]`, depending on whether self is an instance of `A` or and instance of `B`.
    ///
    ///     Problem:
    ///     When `do` is called on an instance of `B`, there will be an infinite loop: First the orignal implementation for the interceptor method (`-[A swizzled_do]`) is executed. Then, inside the interceptor implementation, the line `[self swizzled_do]` will invoke the original implementation for `[B do]`. All good so far, but then, inside of `-[B do]`, the line `[super do]` should invoke -[A do], but first it will be intercepted by `-[A swizzled_do]`. And now we're back to the start! We have an infinite loop. At the core of the problem is that `-[A swizzled_do]` doesn't know that it was invoked with a `super` call.
    ///
    ///     Solution:
    ///     We need to figure out whether `-[A swizzled_do]` was intercepting a call to `[B do]` or to `[A do]` and then call that specific classes' implementation instead of just calling `[self do]`.
    ///     We can figure this out do this by looking at how many times the interceptor for [self do] was called recursively on the same instance. Whenever the `-`[A swizzled_do]` interceptor is called recursively on the same instance, we know that a method with selector `do` called another method on the same instance with selector `do`. And as far as I understand, this can only happen if `do` is a recursive method or if `do` called `[super do]`. (On recursive methods, this approach will fail. Also this will fail if do is called on the super.super class. Maybe in other scenarios.)
    ///     So when swizzling non-recursive methods, that don't do weird stuff like calling  the same method on super.super, then recursionDepth will tell us how many times [super do] was invoked, which we can then use to traverse up the superclass hierarchy of [self class] to find the class which has the implementation of `do` which was intercepted by the current invocation of `swizzled_do`.
    ///
    ///     ("original implementation" refers to the implementation before the implementation is swapped out by swizzling )

    
    /// Get callDepth
    NSString *key = stringf(@"%p|%s", (void *)self, sel_getName(_cmd));
    NSInteger currentCallDepth = [NSThread.currentThread.threadDictionary[key] integerValue];
    
    /// Get swizzled selector
    SEL swizzledSelector = getSwizzledSelector(_cmd); /// Don't understand this
    
    /// TEST
    if ([self isKindOfClass:[NSTableView class]]) {
        
    }
    
    if ([self isKindOfClass:[NSTableHeaderView class]]) {
        
    }
    
    /// Get superclass whose implementation to call
    ///     based on callDepth
    
    Class cls = [self class];
    
    NSInteger nIterations = currentCallDepth + 1;
    
    for (int i = 0; i < nIterations; i++) {
        
        /// Find next superclass
        /// After this while-loop, cls will be set to the next superclass of cls that implements a method for `targetSelector`.
        ///     If cls itself implements a method for `targetSelector`, then the value of cls will be unchanged after this loop.
        
        while (true) {
            
            Class superclass = class_getSuperclass(cls);
            if (superclass == nil) {
                assert(cls == [NSObject class]);
                break;
            }

            Method currentMethodOriginal        = class_getInstanceMethod(cls, swizzledSelector);            /// The swizzled selector gets the unswizzled implementation since the impls have been swapped
            Method superMethodOriginal          = class_getInstanceMethod(superclass, swizzledSelector);
            
            Method superMethodInterceptor       = class_getInstanceMethod(superclass, _cmd);                            /// DEBUG
            Method currentMethodInterceptor     = class_getInstanceMethod(cls, _cmd);                                   /// DEBUG
            
            IMP currentImplementationInterceptor        = method_getImplementation(currentMethodInterceptor);           /// DEBUG
            IMP currentImplementationOriginal           = method_getImplementation(currentMethodOriginal);              /// DEBUG
            IMP superImplementationOriginal             = method_getImplementation(superMethodOriginal);                /// DEBUG
            IMP superImplementationInterceptor          = method_getImplementation(superMethodInterceptor);             /// DEBUG
            
            if (currentMethodOriginal != superMethodOriginal) {
                
                /// `cls` implements the method
                break;
            }
            
            cls = class_getSuperclass(cls);
        }
        
        /// Set up next iteration
        ///     If this is not the last iteration, we need to keep searching for implementors of `targetSelector` at the superclass of cls, so that's why we set cls to it's superclass. (Otherwise there's an infinte loop)
        ///     If this is the last iteration, then we don't set cls to it's superclass so that cls contains the class that implements `targetSelector` which we found.
        BOOL isNotLastIteration = i < (nIterations - 1);
        if (isNotLastIteration) {
            cls = class_getSuperclass(cls);
        }
    }
    
    /// Get target implemementation
    Class targetClass = cls;
    IMP targetImplementation = class_getMethodImplementation(targetClass, swizzledSelector);
    
    /// Increment callDepth
    NSThread.currentThread.threadDictionary[key] = @(currentCallDepth + 1);
    
    /// Call
    body(targetImplementation, currentCallDepth);
    
    /// Decrement callDepth
    NSThread.currentThread.threadDictionary[key] = @(currentCallDepth);
};


void swizzleMethods(Class class, bool includeSubclasses, NSString *framework, NSString *swizzlePrefix, SEL firstSwizzledSelector, ...) {
    
    /// Use this inside a custom Category (or Extension if you're using Swift) on the class `class` to replace existing methods of `class` with your own implementations.
    ///
    /// Explanation for arg `class`:
    ///     The class whose methods to swap out. Pass in a metaclass () to swap out class methods. Otherwise instance methods will be swapped out.
    ///     You can get the metaclass of a class by calling `object_getClass()` on it.
    /// Explanation for arg `includeSubclasses`:
    ///     Set this to true to swap out the methods for `class` as well as *all* subclasses of `class`. If you set this to false, only subclasses which inherit the swapped out methods from `class` will be affected (And subclasses which override the swapped out methods won't be affected.). Setting this to true,might make this function slow. (Which might affect app startup time)
    /// Explanation for arg `framework`:
    ///     Set this to a framework name such as @"AppKit" to only swizzle subclasses from that framework. Use this option with includeSubclasses=true.
    ///     This should be useful when swizzling subclasses of NSObject.
    ///     Set this to nil to not filter out any subclasses.
    /// Explanation for args `swizzlePrefix` and `firstSwizzledSelector, ...`:
    ///     At the end of the argument list for this method, you can pass in a number of `swizzledSelectors`.
    ///     Each selector from`swizzledSelectors` will have its method implementation swapped out with the method that has the same selector but without the `swizzlePrefix`.
    ///     (All `swizzledSelectors` are expected to have the `swizzlePrefix` at the start of their name.)
    ///
    /// Usage example
    ///     If `class` is `MyClass`, and `swizzlePrefix` is `swooz_` and `swizzledSelectors` is a single selector `swooz_loadImagesFromServer:`, then the   implementation of `MyClass -loadImagesFromServer:` is replaced with the implementation for `MyClass -swooz_loadImagesFromServer:`
    

    
    /// Check if there ar any args
    if (firstSwizzledSelector == NULL) {
//        assert(false);
        return;
    }
    
    /// Check if swizzlePrefix matches
    /// TODO: Remove swizzlePrefix arg and use global var instead
    assert([_swizzlePrefix() isEqual:swizzlePrefix]);
    
    /// Log
    NSLog(@"Swizzling class %@ FROM %s, includingSubclasses: %d, filteringToFramework: %@. First selector: %@", class, class_getImageName(class), includeSubclasses, framework, NSStringFromSelector(firstSwizzledSelector));
    
    /// Validate
    if (framework != nil && framework.length > 0) {
        assert(includeSubclasses);
    }
    
    /// Handle first selector
    _swizzleMethodWithPrefix(class, firstSwizzledSelector, swizzlePrefix, includeSubclasses, framework);
    
    /// Handle remaining selectors
    va_list selectors;
    va_start(selectors, firstSwizzledSelector);
    
    while (true) {
        SEL sel = va_arg(selectors, SEL);
        if (sel == nil) break;
        _swizzleMethodWithPrefix(class, sel, swizzlePrefix, includeSubclasses, framework);
    }
    va_end(selectors);
}

void _swizzleMethodWithPrefix(Class class, SEL swizzledSelector, NSString *swizzlePrefix, bool includeSubclasses, NSString *framework) {
    
    SEL baseSelector = getOriginalSelector(swizzledSelector);
    
    _swizzleMethod_SubclassArg(class, baseSelector, swizzledSelector, includeSubclasses, framework);
}

void _swizzleMethod_SubclassArg(Class baseClass, SEL originalSelector, SEL swizzledSelector, bool includeSubclasses, NSString *framework) {
    if (includeSubclasses) {
        _swizzleMethodOnClassAndSubclasses(baseClass, framework, originalSelector, swizzledSelector);
    } else {
        _swizzleMethod(baseClass, originalSelector, swizzledSelector);
    }
}

void _swizzleMethodOnClassAndSubclasses(Class baseClass, NSString *framework, SEL originalSelector, SEL swizzledSelector) {
    
    /// TEST
    if ([NSStringFromSelector(swizzledSelector) isEqual:@"swizzled_setToolTip:"]) {
        
    }
    
    /// Validate
    assert([baseClass instancesRespondToSelector:swizzledSelector]); /// We expect the swizzledSelector method to be defined on the `baseClass`
        
    /// TEST
    
    /// Get interceptor implementation
//    IMP interceptor = class_getMethodImplementation(baseClass, swizzledSelector);
    
    /// Wrap implementation with infinite-loop-preventer block.
    ///     Note: Just doing this in all scenarios isn't optimally effiicient. But if we're using subclass swizzling, we probably don't care about efficiency anyways. See the explanation about when infinite loops can occur in this file.
    ///     Update: Couldn't get this to work.
//    Method method = class_getInstanceMethod(baseClass, swizzledSelector);
//    method_setImplementation(method, subclassSwizzleNoInfiniteLoopIMP(method));
    
    /// TEST
//    BOOL isSearchFieldSuperclass = [[NSSearchFieldCell class] isKindOfClass:object_getClass(baseClass)];
//    BOOL isSearchFieldSubclass = [baseClass isKindOfClass:object_getClass([NSSearchFieldCell class])];
//    if (isSearchFieldSuperclass || isSearchFieldSubclass) {
//        NSLog(@"Swizzle: ITERRR NSSearchfieldCell sub-/superclass: %@ || isBaseClass || (swizzling: %@)", NSStringFromClass(baseClass), NSStringFromSelector(originalSelector));
//    }
    
    /// Find subclasses
    NSArray <NSDictionary *> *subclasses = _subclassesOfClass(baseClass, framework, false);
    
    /// Sort subclasses by depth
    subclasses = [subclasses sortedArrayUsingDescriptors:@[
        [[NSSortDescriptor alloc] initWithKey:@"depth" ascending:NO],
    ]];
    
    /// Swizzle subclasses
    /// Notes:
    ///     - Since we sorted by depth, we will iterate over subclasses before their respective superclasses. If we don't do this, and we attempt to swizzle the subclass after its superclass has already been swizzled, then `getInstanceMethod(subclass, `swizzledSelector`)` wouldn't map to the interceptor method anymore and swizzling the subclass would fail.
    ///         (Alternatively to sorting, we could also get the interceptor method implemenation once and store it instead of retrieving it for each subclass based on `swizzledSelector`).
    ///     - We iterate all the subclasses, but we only swizzle them if they implement their own method for `originalSelector`.
    NSInteger lastDepth = NSIntegerMax;
    int i = 0;
    for (NSDictionary *subclassDict in subclasses) {
        
        Class subclass = subclassDict[@"class"];
        NSInteger depth = [subclassDict[@"depth"] integerValue];
        
        /// Validate depth
        assert(depth <= lastDepth);
        
        /// Check if `class` overrides the method for `originalSelector`
        Method subclassMethod = class_getInstanceMethod(subclass, originalSelector);
        Method superclassMethod = class_getInstanceMethod(class_getSuperclass(subclass), originalSelector);
        BOOL subclassOverridesMethod = subclassMethod != superclassMethod;
        
        /// Skip
        ///     We only need to swizzle classes that override the implementation, otherwise the class will inherit the (already swizzled) implementation of a superclass.
        if (!subclassOverridesMethod) continue;
        
        /// Skip
        ///     If we arrive at a superclass that doesn't have an implementation, we don't swizzle (This check is redundant I think.)
        assert(subclassMethod != nil);
        if (subclassMethod == nil) continue;
        
        /// TEST
//        isSearchFieldSuperclass = [[NSSearchFieldCell class] isKindOfClass:object_getClass(subclass)];
//        isSearchFieldSubclass = [subclass isKindOfClass:object_getClass([NSSearchFieldCell class])];
//        if (isSearchFieldSuperclass || isSearchFieldSubclass) {
//            NSLog(@"Swizzle: ITERRR NSSearchfieldCell sub-/superclass: %@ || distanceFrom %@: %ld || (%d/%lu) (swizzling: %@)", NSStringFromClass(subclass), NSStringFromClass(baseClass), (long)depth, i, (unsigned long)subclasses.count, NSStringFromSelector(originalSelector));
//        }
        

        /// Validate
        /// Old notes: 
        ///     only swizzle classes that respond to the `originalSelector`.
        ///     This allows us to swizzle all the subclasses of `baseClass` that respond to `originalSelector`, even if `baseClass` doesn't respond to the selector.
        ///     (I don't fully understand this either but it's necessary for that to work.)
        assert([subclass instancesRespondToSelector: originalSelector]);
                
        /// Swizzle
        _swizzleMethod_SubclassSwizzling_Subclass(subclass, originalSelector, swizzledSelector);
        
        /// Update state
        i++;
        lastDepth = depth;
    }
    
    /// Swizzle on baseClass
    ///     We always want to at least swizzle on the baseClass. Even if the baseClass, doesn't define it's own implementation for `originalSelector`, and instead inherits the implementation.
    ///     If `baseClass` doesn't respond to the `originalSelector` at all, then we could skip this, but eh.
    _swizzleMethod_SubclassSwizzling_BaseClass(baseClass, originalSelector, swizzledSelector);
}



void _swizzleMethod_SubclassSwizzling_Subclass(Class class, SEL originalSelector, SEL swizzledSelector) {
    
    /// Get interceptor implementation
    Method interceptorMethodFromSuperclass = class_getInstanceMethod(class, swizzledSelector); /// This will get the method from the closest superclass (or from this class, if the method is defined on this class)
    IMP interceptorImplementation = method_getImplementation(interceptorMethodFromSuperclass);
    const char *interceptorTypeEncoding = method_getTypeEncoding(interceptorMethodFromSuperclass);
    assert(interceptorImplementation != NULL);
    
    /// Add the interceptor method (which is likely defined on a superclass) to this class.
    ///     So that when we swap the implementations, we don't affect the original interceptor method on the superclass.
    ///     If the interceptor is defined on `class` itself then this will do nothing and return NO;
    BOOL didAddInterceptor = class_addMethod(class, swizzledSelector, interceptorImplementation, interceptorTypeEncoding);
    Method interceptorMethod = class_getInstanceMethod(class, swizzledSelector);
    
    /// Validate
    if (didAddInterceptor) {
        assert(interceptorMethodFromSuperclass != interceptorMethod);
    } else {
        assert(interceptorMethodFromSuperclass == interceptorMethod);
    }
    
    /// Get the original method
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    
    /// Validate originalImplementation
    ///     Kind of unnecessary
    IMP originalImplementation = method_getImplementation(originalMethod);
    assert(originalImplementation != NULL);
    const char *originalTypeEncoding = method_getTypeEncoding(originalMethod);
    assert(strcmp(interceptorTypeEncoding, originalTypeEncoding) == 0);

    /// Validate
    /// Make sure the original method exists and is defined on this current class
    /// Otherwise, if we're inheriting the originalMethod, we'd be affecting the superclass by calling exchangeImplementations - which we don't want.
    BOOL originalMethodIsDefinedOnThisClass = NO;
    unsigned int methodCount;
    Method *methodList = class_copyMethodList(class, &methodCount);
    for (int i = 0; i < methodCount; i++) {
        Method method = methodList[i];
        if (method == originalMethod) {
            originalMethodIsDefinedOnThisClass = YES;
            break;
        }
    }
    assert(originalMethodIsDefinedOnThisClass);
    
    /// Free
    free(methodList);
    
    /// Swap implementations
    method_exchangeImplementations(originalMethod, interceptorMethod);
}


void _swizzleMethod_SubclassSwizzling_BaseClass(Class baseClass, SEL originalSelector, SEL swizzledSelector) {

    /// Get interceptor method
    Method interceptorMethod = class_getInstanceMethod(baseClass, swizzledSelector);
    IMP interceptorImplementation = method_getImplementation(interceptorMethod);
    const char *interceptorTypeEncoding = method_getTypeEncoding(interceptorMethod);

    /// Validate
    ///     Interceptor should be defined exactly on this class
    
    BOOL interceptorIsDefinedOnBaseClass = NO;
    unsigned int methodCount;
    Method *methodList = class_copyMethodList(baseClass, &methodCount);
    for (int i = 0; i < methodCount; i++) {
        Method method = methodList[i];
        if (method == interceptorMethod) {
            interceptorIsDefinedOnBaseClass = YES;
            break;
        }
    }
    assert(interceptorIsDefinedOnBaseClass);
    
    /// Free
    free(methodList);
    
    /// Get original method
    Method originalMethod = class_getInstanceMethod(baseClass, originalSelector);
    IMP originalImplementation = originalMethod == NULL ? NULL : method_getImplementation(originalMethod);
    const char *originalTypeEncoding = originalMethod == NULL ? NULL : method_getTypeEncoding(originalMethod);
    
    if (originalMethod == NULL) {
        /// Case 1: originalMethod **is not** defined on baseClass or one of its superclasses.
        
        /// Add placeholder method
        IMP placeholderImp = imp_implementationWithBlock(^(id self) {
            NSLog(@"The method %@ you called on object %@ is an artifact of swizzling. It does not do anything and should not be called.", NSStringFromSelector(swizzledSelector), self);
            assert(false);
        });
        const char *placeholderTypeEncoding = interceptorTypeEncoding; /// Not sure what to use here. Maybe NULL?
        BOOL didAddMethod = class_addMethod(baseClass, originalSelector, placeholderImp, placeholderTypeEncoding);
        if (didAddMethod) {
            originalMethod = class_getInstanceMethod(baseClass, originalSelector);
        } else {
            assert(false);
        }
        
        
    } else {
        /// Case 2: originalMethod **is** defined on baseClass or one of its superclasses.
        
        /// Add the method.
        ///     This will add the method directly to the baseClass, if it was inherited from the superclass beforehand. Otherwise it will do nothing.
        ///     This ensures that we don't affect any superclasses when we `exchangeImplementation`s.
        ///
        BOOL didAddMethod = class_addMethod(baseClass, originalSelector, originalImplementation, originalTypeEncoding);
        if (didAddMethod) { /// Re-fetch
            originalMethod = class_getInstanceMethod(baseClass, originalSelector);
        }
    }
    
    /// Swap implementations
    method_exchangeImplementations(originalMethod, interceptorMethod);
}

void _swizzleMethod(Class class, SEL originalSelector, SEL swizzledSelector) {
    
    /// Swaps out the implementations of `originalSelector` and `swizzledSelector` on `class`. Works for ObjC and Swift afaik. Initially written by ChatGPT.
    
    /// Get methods
    ///     Note: Based on my testing, we don't need to use `class_getClassMethod` to make swizzling `class_methods` work, if we just pass in a meta class as `class`, then `class_getInstanceMethod` will get the class methods, and everything works as expected.
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method interceptorMethod = class_getInstanceMethod(class, swizzledSelector);

    /// Validate
    assert(originalMethod != NULL);
    assert(interceptorMethod != NULL);
    assert([class instancesRespondToSelector:originalSelector]); /// Note: This seems to work as expected on meta classes
    assert([class instancesRespondToSelector:swizzledSelector]); /// Note: `instancesRespondToSelector:` is equivalent to `class_respondsToSelector()` from my testing.
    
    /// Make sure originalMethod is present directly on `class`
    ///     (Instead of being inherited from a superclass -> So we're not replacing the implementation of the method from the superclass, affecting all its other subclasses.)
    BOOL didAddOriginal = class_addMethod(class, originalSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    if (didAddOriginal) { /// Re-fetch
        originalMethod = class_getInstanceMethod(class, originalSelector);
    }
    
    /// Validate
    ///     Assert that the interceptorMethod was already defined on `class`- and not inherited from a superclass.
    ///     If you wanna do stuff like that look at `_swizzleMethod_ForSubclassSwizzling`.
    BOOL didAddInterceptor = class_addMethod(class, swizzledSelector, method_getImplementation(interceptorMethod), method_getTypeEncoding(interceptorMethod));
    assert(!didAddInterceptor);
    if (didAddOriginal) { /// Re-fetch - to make this not totally break if the assert doesn't stop execution.
        originalMethod = class_getInstanceMethod(class, originalSelector);
    }
    
    /// Swap implementations
    method_exchangeImplementations(originalMethod, interceptorMethod);
}

///
/// Other
///

static NSArray<NSDictionary<NSString *, id> *> *_subclassesOfClass(Class baseClass, NSString *framework, BOOL includeBaseClass) {
        
    /// Note: I'm not sur the caching as we currently do it helps performance? Might be slowing things down.
    ///     Maybe if we made the cache a tree structure, that would help. But so far it's not super slow.
    
    /// Preprocess
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


///
/// Unused
///

+ (void)swizzleAllMethodsInClass:(Class)cls {
    
    /// Written by Claude. Not sure it works
    
    assert(false);
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);

    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        
        /// Skip certain methods that might cause issues if swizzled
        if (selector == @selector(class) || strcmp(sel_getName(selector), "dealloc") == 0 || selector == @selector(forwardInvocation:)) {
            continue;
        }

        IMP originalImp = method_getImplementation(method);
        const char *typeEncoding = method_getTypeEncoding(method);
        
        IMP newImp = imp_implementationWithBlock(^(id self, ...) {
            NSLog(@"Calling method: %@ on %@", NSStringFromSelector(selector), [self class]);
            
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[NSMethodSignature signatureWithObjCTypes:typeEncoding]];
            [invocation setTarget:self];
            [invocation setSelector:selector];
            
            va_list args;
            va_start(args, self);
            [Swizzle setInvocation:invocation withArgs:args];
            va_end(args);
            
            [invocation invokeWithTarget:self];
            
            return [Swizzle returnValueFromInvocation:invocation];
        });

        method_setImplementation(method, newImp);
    }

    free(methods);
}

+ (void)setInvocation:(NSInvocation *)invocation withArgs:(va_list)args {
    
    /// Helper for `- swizzleAllMethodsInClass`
    
    assert(false);
    
    NSMethodSignature *signature = [invocation methodSignature];
    for (NSInteger i = 2; i < [signature numberOfArguments]; i++) {
        const char *type = [signature getArgumentTypeAtIndex:i];
        switch (type[0]) {
            case 'i': {
                int arg = va_arg(args, int);
                [invocation setArgument:&arg atIndex:i];
                break;
            }
            case 'l': {
                long arg = va_arg(args, long);
                [invocation setArgument:&arg atIndex:i];
                break;
            }
            case 'd': {
                double arg = va_arg(args, double);
                [invocation setArgument:&arg atIndex:i];
                break;
            }
            case '@': {
                id arg = va_arg(args, id);
                [invocation setArgument:&arg atIndex:i];
                break;
            }
            // Add more cases for other types as needed
            default:
                NSLog(@"Unsupported argument type: %s", type);
                break;
        }
    }
}

+ (id)returnValueFromInvocation:(NSInvocation *)invocation {
    
    /// Helper for `- swizzleAllMethodsInClass`
    
    assert(false);
    
    const char *returnType = invocation.methodSignature.methodReturnType;
    if (strcmp(returnType, @encode(void)) == 0) {
        return nil;
    }
    
    void *buffer = malloc(invocation.methodSignature.methodReturnLength);
    [invocation getReturnValue:buffer];
    
    id returnValue;
    if (strcmp(returnType, @encode(id)) == 0) {
        returnValue = (__bridge id)*(void **)buffer;
    } else {
        returnValue = [NSValue valueWithBytes:buffer objCType:returnType];
    }
    
    free(buffer);
    return returnValue;
}

IMP subclassSwizzleNoInfiniteLoopIMP_Block(Method originalMethod) {
    
    /// This doesn't work, use subclassSwizzleNoInfiniteLoop() manually instead of this.
    ///     This was an attempt of automating subclassSwizzleNoInfiniteLoop().
    
    assert(false);
    
    IMP originalImplementation = method_getImplementation(originalMethod);
    SEL __cmd = method_getName(originalMethod);
    
    id (^resultBlock) (id, ...) = ^id (id _self, ...) {
        
        va_list varargs;
        va_start(varargs, _self);
        va_list varargs2;
        va_copy(varargs2, varargs);
        
        NSMethodSignature *signature = [NSObject methodSignatureForSelector:__cmd];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];

        int memoryOffset = 0;
        for (NSInteger i = 2; i < [signature numberOfArguments]; i++) { /// Skip self and `_cmd` || Thank the lord ChatGPT!
            const char *argType = [signature getArgumentTypeAtIndex:i];
            NSUInteger argSize;
            NSGetSizeAndAlignment(argType, &argSize, NULL);
//            id arg = (__bridge id)va_arg(varargs, void *);
            void *arg = alloca(argSize);
            memcpy(arg, varargs + memoryOffset, argSize);
            memoryOffset += argSize;
            [invocation setArgument:arg atIndex:i];
        }
        
        [invocation setSelector:__cmd];
        [invocation setTarget:_self];
        [invocation retainArguments];
        
        NSString *key = stringf(@"%p|%s", (void *)_self, sel_getName(__cmd));
        NSInteger callDepth = [NSThread.currentThread.threadDictionary[key] integerValue];
        NSThread.currentThread.threadDictionary[key] = @(callDepth + 1);
        
        id result = nil;
        if (callDepth <= 1) {
            [invocation invokeUsingIMP:originalImplementation];
            const char *returnType = [signature methodReturnType];
            if (strcmp(returnType, @encode(void)) != 0) {
                NSUInteger returnLength = [signature methodReturnLength];
                void *buffer = (void *)malloc(returnLength);
                [invocation getReturnValue:buffer];
                result = (__bridge id)*(void **)buffer;
                free(buffer);
            }
        }
        NSThread.currentThread.threadDictionary[key] = @(callDepth);
        
        return result;
    };
    
    IMP result = imp_implementationWithBlock(resultBlock);
    
    return result;
};


@end


