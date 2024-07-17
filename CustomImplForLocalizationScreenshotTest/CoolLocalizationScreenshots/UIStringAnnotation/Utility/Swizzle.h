//
//  Swizzle.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import <Foundation/Foundation.h>
#import "PreprocessorMagic.h"

NS_ASSUME_NONNULL_BEGIN

@interface Swizzle : NSObject

typedef id InterceptorBlock;
typedef IMP OriginalImplementation;
typedef InterceptorBlock _Nonnull (^InterceptorFactory)(Class originalClass, SEL _cmd, OriginalImplementation _Nonnull originalImplementation);

#define UNPACK(...) __VA_ARGS__ /// This allows us to include `,` inside an argument to a macro (but the argument then needs to be wrapped inside `()` by the caller of the macro )

#define MakeInterceptorFactory(__ReturnType, __Arguments, ...) \
    (id)                                                        /** Cast the entire factory block to id to silence type-checker */ \
    ^id (Class m_originalClass, SEL m__cmd, __ReturnType (*m_originalImplementation)(id self, SEL _cmd UNPACK __Arguments)) /** Define return types and args of the factory block (Setting the return type to id bc idk how to objc, return value is actually the interceptor block) */ \
    {                                                           /** Body of the factory block */ \
        return ^__ReturnType (id m_self UNPACK __Arguments)     /** Return type and args of the interceptor block */ \
            __VA_ARGS__;                                        /**  Body of the interceptor block is the code that the caller of the macro provided. Needs to be the varargs to prevent weird compiler errors. */ \
    } \

void swizzleMethodOnClassAndSubclasses(Class baseClass, NSString *framework, SEL originalSelector, InterceptorFactory interceptorFactory);
void swizzleMethod(Class cls, SEL originalSelector, InterceptorFactory interceptorFactory);

/// Convenience macros
///     To be used inside the onIntercept codeblock passed to the `MakeInterceptorFactory()` macro
#define OGImpl(...) \
    m_originalImplementation(m_self, m__cmd __VA_ARGS__)


/// Old
#define MakeInterceptorFactory_2(__ReturnType, __Arguments, __InterceptionCode) /** This older alternate factory-maker is more neat and properly typed but it seems to break autocomplete */ \
    ({ \
        typedef __ReturnType (*OriginalImplementation)(id, SEL, UNPACK __Arguments); \
        typedef __ReturnType (^InterceptorBlock)(id self, UNPACK __Arguments); \
        typedef InterceptorBlock (^InterceptorFactory)(Class originalClass, SEL _cmd, OriginalImplementation originalImplementation); \
        \
        (InterceptorFactory) ^InterceptorBlock (Class originalClass, SEL _cmd, OriginalImplementation originalImplementation) { \
            return ^__ReturnType (id self, UNPACK __Arguments) __InterceptionCode; \
        }; \
    })

@end

NS_ASSUME_NONNULL_END
