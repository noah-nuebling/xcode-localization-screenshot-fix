//
//  Swizzle.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Swizzle : NSObject

typedef id InterceptorBlock;
typedef IMP OriginalImplementation;
typedef InterceptorBlock _Nonnull (^InterceptorFactory)(Class originalClass, SEL _cmd, OriginalImplementation _Nonnull originalImplementation);

#define UNPACK(...) __VA_ARGS__
    
#define MakeInterceptorFactory(__ReturnType, __Arguments, ...) \
    (id) /** Cast to id to silence type-checker */ \
    ^id (Class originalClass, SEL _cmd, __ReturnType (*originalImplementation)(id self, SEL _cmd UNPACK __Arguments)) /** Define return types and args of the factory block (Setting the return type to id bc idk how to objc, return value is actually the interceptor block) */ \
    { /** Body of the factory block */ \
        return ^__ReturnType (id self UNPACK __Arguments) /** Return type and args of the interceptor block */ \
            __VA_ARGS__; /** Body of the interceptor block. Make this vararg to be able to have unguarded commas inside the code block*/\
    }

#define MakeInterceptorFactory2(__ReturnType, __Arguments, __InterceptionCode) /** This alternate factory-maker is more neat and properly typed but it seems to break autocomplete */ \
    ({ \
        typedef __ReturnType (*OriginalImplementation)(id, SEL, UNPACK __Arguments); \
        typedef __ReturnType (^InterceptorBlock)(id self, UNPACK __Arguments); \
        typedef InterceptorBlock (^InterceptorFactory)(Class originalClass, SEL _cmd, OriginalImplementation originalImplementation); \
        \
        (InterceptorFactory) ^InterceptorBlock (Class originalClass, SEL _cmd, OriginalImplementation originalImplementation) { \
            return ^__ReturnType (id self, UNPACK __Arguments) __InterceptionCode; \
        }; \
    })

void swizzleMethodOnClassAndSubclasses(Class baseClass, NSString *framework, SEL originalSelector, InterceptorFactory interceptorFactory);
void swizzleMethod(Class cls, SEL originalSelector, InterceptorFactory interceptorFactory);

/// Convenience macros
#define OGImpl(args) \
    originalImplementation(self, _cmd, UNPACK args) /** This breaks sometimes, not sure why. In those cases juse use `originalImplementation(self, _cmd, ...)` */

@end

NS_ASSUME_NONNULL_END
