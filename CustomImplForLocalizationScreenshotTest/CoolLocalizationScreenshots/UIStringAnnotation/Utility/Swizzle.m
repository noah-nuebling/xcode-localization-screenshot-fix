//
//  Swizzle.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import "Swizzle.h"
@import ObjectiveC.runtime;

@implementation Swizzle

void swizzleMethods(Class class, bool includeSubclasses, NSString *swizzlePrefix, SEL firstSwizzledSelector, ...) {
    
    /// Use this inside a custom Category (or Extension if you're using Swift) on the class `class` to replace existing methods of `class` with your own implementations.
    ///
    /// Explanation for arg `class`:
    ///     The class whose methods to swap out. Pass in a metaclass () to swap out class methods. Otherwise instance methods will be swapped out.
    ///     You can get the metaclass of a class by calling `object_getClass()` on it.
    /// Explanation for arg `includeSubclasses`:
    ///     Set this to true to swap out the methods for `class` as well as *all* subclasses of `class`. If you set this to false, only subclasses which inherit the swapped out methods from `class` will be affected (And subclasses which override the swapped out methods won't be affected.). Setting this to true,might make this function slow. (Which might affect app startup time)
    /// Explanation for args `swizzlePrefix` and `firstSwizzledSelector, ...`:
    ///     At the end of the argument list for this method, you can pass in a number of `swizzledSelectors`.
    ///     Each selector from`swizzledSelectors` will have its method implementation swapped out with the method that has the same selector but without the `swizzlePrefix`.
    ///     (All `swizzledSelectors` are expected to have the `swizzlePrefix` at the start of their name.)
    ///
    /// Usage example
    ///     If `class` is `MyClass`, and `swizzlePrefix` is `swooz_` and `swizzledSelectors` is a single selector `swooz_loadImagesFromServer:`, then the   implementation of `MyClass -loadImagesFromServer:` is replaced with the implementation for `MyClass -swooz_loadImagesFromServer:`
    ///
    
    /// Handle first selector
    _swizzleMethodWithPrefix(class, firstSwizzledSelector, swizzlePrefix, includeSubclasses);
    
    /// Handle remaining selectors
    va_list selectors;
    va_start(selectors, firstSwizzledSelector);
    
    while (true) {
        SEL sel = va_arg(selectors, SEL);
        if (sel == nil) break;
        _swizzleMethodWithPrefix(class, sel, swizzlePrefix, includeSubclasses);
    }
    va_end(selectors);
}

void _swizzleMethodWithPrefix(Class class, SEL swizzledSelector, NSString *swizzlePrefix, bool includeSubclasses) {
    
    NSString *swizzledSelectorNS = NSStringFromSelector(swizzledSelector);
    
    NSRange prefixRange = [swizzledSelectorNS rangeOfString:swizzlePrefix];
    
    assert(prefixRange.location != NSNotFound);
    assert(prefixRange.location == 0);
    
    NSString *baseSelectorNS = [swizzledSelectorNS substringFromIndex:prefixRange.length];
    SEL baseSelector = NSSelectorFromString(baseSelectorNS);
    
    _swizzleMethod_SubclassArg(class, baseSelector, swizzledSelector, includeSubclasses);
}

void _swizzleMethod_SubclassArg(Class baseClass, SEL originalSelector, SEL swizzledSelector, bool includeSubclasses) {
    if (includeSubclasses) {
        _swizzleMethodOnClassAndSubclasses(baseClass, originalSelector, swizzledSelector);
    } else {
        _swizzleMethod(baseClass, originalSelector, swizzledSelector);
    }
}

void _swizzleMethodOnClassAndSubclasses(Class baseClass, SEL originalSelector, SEL swizzledSelector) {
    
    /// Swizzle the method on the base class
    _swizzleMethod(baseClass, originalSelector, swizzledSelector);
    
    /// Find subclasses
    NSArray <NSString *> *subclasses = _subclassesOfClass(baseClass);
    
    /// Swizzle subclasses
    for (NSString *subclassName in subclasses) {
        
        Class subclass = NSClassFromString(subclassName);
        
        /// Check if `class` overrides the method for `originalSelector`
        Method classMethod = class_getInstanceMethod(subclass, originalSelector);
        Method superclassMethod = class_getInstanceMethod(class_getSuperclass(subclass), originalSelector);
        BOOL classOverridesMethod = classMethod != superclassMethod;
        
        /// Skip
        ///     We only need to swizzle classes that override the implementation, otherwise the class will inherit the (already swizzled) implementation of a superclass.
        if (!classOverridesMethod) continue;
        
        /// Swizzle
        _swizzleMethod(subclass, originalSelector, swizzledSelector);
    }

}


void _swizzleMethod(Class class, SEL originalSelector, SEL swizzledSelector) {
    
    /// Swaps out the implementations of `originalSelector` and `swizzledSelector` on `class`. Works for ObjC and Swift afaik. Written by ChatGPT.
    
    /// Check if we're dealing with class-methods or instance methods
    BOOL useClassMethods = class_isMetaClass(class);
    
    /// Get methods
    ///     Note: Based on my testing, we don't need to use `class_getClassMethod`, `class_getInstanceMethod` will give the same result on a meta class.
    Method originalMethod = useClassMethods ? class_getClassMethod(class, originalSelector) : class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = useClassMethods ? class_getClassMethod(class, swizzledSelector) : class_getInstanceMethod(class, swizzledSelector);

    /// Valdate
    assert(originalMethod != NULL);
    assert(swizzledMethod != NULL);
    assert([class instancesRespondToSelector:originalSelector]); /// Note: This seems to work as expected on meta classes
    assert([class instancesRespondToSelector:swizzledSelector]); /// Note: `instancesRespondToSelector:` is equivalent to `class_respondsToSelector()` from my testing.
    
    /// Add method to `class`
    ///     So we're not replacing the implementation from the superclass, affecting all of its subclasses.
    BOOL didAddMethod = class_addMethod(class,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    if (didAddMethod) {
        /// Special case: Method was added (so the class didn't have its own implementation for `originalSelector` and was instead using the superclass implementation)
        /// -> Make the swizzledSelector invoke the original method
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        /// Default case: Swap implementations
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

///
/// Other
///

static NSArray <NSString *>*_subclassesOfClass(Class baseClass) {
        
    /// Note: I don't think the caching as we currently do it helps performance in any way.
    ///     Maybe if we made the cache a tree structure, that would help. But so far it's not super slow.
    
    /// Preprocess
    NSString *baseClassName = NSStringFromClass(baseClass);
    
    /// Get cache
    static NSMutableDictionary *_cache = nil;
    if (_cache == nil) {
        _cache = [NSMutableDictionary dictionary];
    }
    
    /// Look up result in cache
    NSArray *resultFromCache = _cache[baseClassName];
    if (resultFromCache != nil) {
        return resultFromCache;
    }
    
    /// Declare result
    NSMutableArray *subclasses = [NSMutableArray array];
    
    /// Get all classes
    ///     I repeat, *all* classes
    Class *classes = NULL; unsigned int numberOfClasses;
    classes = objc_copyClassList(&numberOfClasses);
    
    /// Iterate all classes
    ///     And fill result
    for (unsigned int i = 0; i < numberOfClasses; i++) {

        Class class = classes[i];

        /// Check if `baseClass` is a superclass of `class`
        BOOL baseClassIsSuperclass = NO;
        Class superclass = class_getSuperclass(class);
        while (true) {
            if (superclass == nil) {
                break;
            }
            if (baseClass == superclass) {
                baseClassIsSuperclass = YES;
                break;
            }
            superclass = class_getSuperclass(superclass);
        }

        /// Store in result
        if (baseClassIsSuperclass) {
            [subclasses addObject:NSStringFromClass(class)];
        }
    }
    
    /// Free all classes
    free(classes);
    
    /// Store in cache
    _cache[baseClassName] = subclasses;
    
    /// Return
    return subclasses;
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

@end
