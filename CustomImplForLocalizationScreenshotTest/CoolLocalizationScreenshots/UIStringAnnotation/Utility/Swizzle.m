//
//  Swizzle.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import "Swizzle.h"
@import ObjectiveC.runtime;

@implementation Swizzle

+ (void)swizzleMethodsOnClass:(Class)class swizzlePrefix:(NSString *)swizzlePrefix swizzledSelectors:(SEL)firstSelector, ... NS_REQUIRES_NIL_TERMINATION {
    
    ///
    /// Explanation
    /// `...` should contain a number of objc method `swizzledSelectors`.
    /// Each method from`swizzledSelectors` will have its implementations swapped out with the method that has the same selector but without the `swizzlePrefix`.
    /// (All `swizzledSelectors` are expected to have the `swizzlePrefix` at the start of their name.)
    ///
    /// For example:
    /// If `class` is `MyClass`, and `swizzlePrefix` is `swooz_` and `swizzledSelectors` is a single selector `swooz_loadImagesFromServer:`, then the implementation of `MyClass -loadImagesFromServer:` is replaced with the implementation for `MyClass -swooz_loadImagesFromServer:`
    ///
     
    /// Extract selectors from vararg
    
    NSMutableArray <NSString *>*selectors = [NSMutableArray array];
    va_list selectorsRaw;
    va_start(selectorsRaw, firstSelector);
    
    while (true) {
        SEL sel = va_arg(selectorsRaw, SEL);
        if (sel == nil) break;
        [selectors addObject:NSStringFromSelector(sel)];
    }
    va_end(selectorsRaw);
    
    /// Assemble args
    [selectors insertObject:NSStringFromSelector(firstSelector) atIndex:0];
    
    /// Swizzle
    for (NSString *swizzledSelector in selectors) {
        
        assert([swizzledSelector hasPrefix:swizzlePrefix]);
        NSRange prefixRange = [swizzledSelector rangeOfString:swizzlePrefix];
        assert(prefixRange.location == 0);
        NSString *baseSelector = [swizzledSelector substringFromIndex:prefixRange.length];
        swizzleMethod(class, NSSelectorFromString(baseSelector), NSSelectorFromString(swizzledSelector));
    }
}

void swizzleMethod(Class class, SEL originalSelector, SEL swizzledSelector) {
    
    /// Swaps out the implementations of `originalSelector` and `swizzledSelector` on `class`. Works for ObjC and Swift afaik. Written by ChatGPT.
    
    /// Check if we're dealing with class-methods or instance methods
    BOOL useClassMethods = class_isMetaClass(class);
    
    /// Get methods
    Method originalMethod = useClassMethods ? class_getClassMethod(class, originalSelector) : class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = useClassMethods ? class_getClassMethod(class, swizzledSelector) : class_getInstanceMethod(class, swizzledSelector);

    /// Valdate
    assert(originalMethod != NULL);
    assert(swizzledMethod != NULL);
    assert([class instancesRespondToSelector:originalSelector]); /// Not sure if this validation is redundant.
    
    /// Attempt to add the method with the swizzled implementation under the name of the original method.
    /// If the class already contains a method with that name, it fails and returns NO.
    /// Note: This seems kind of unnecessary but it works so won't change it
    BOOL didAddMethod = class_addMethod(class,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
        /// If the original method wasn’t in the class (unlikely but possible), replace the swizzled method's entry
        /// to ensure the swizzled method's implementation is now under the swizzled selector.
        /// Note: This seems kind of unnecessary but it works so won't change it
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        /// If the class already contains a method with the original selector, we swap their implementations.
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

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
