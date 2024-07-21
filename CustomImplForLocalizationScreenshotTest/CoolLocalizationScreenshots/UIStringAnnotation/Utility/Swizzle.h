//
//  Swizzle.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import <Foundation/Foundation.h>
#import "Utility.h"

NS_ASSUME_NONNULL_BEGIN

@interface Swizzle : NSObject

/// Typedefs

typedef id InterceptorBlock;
typedef IMP OriginalImplementation;
typedef InterceptorBlock _Nonnull (^InterceptorFactory)(Class originalClass, SEL originalSelector, OriginalImplementation _Nonnull originalImplementation);

/// Main interface

void swizzleMethod(Class cls, SEL originalSelector, InterceptorFactory interceptorFactory);
void swizzleMethodOnClassAndSubclasses(Class baseClass, NSDictionary<MFClassSearchCriterion, id> *subclassSearchCriteria, SEL originalSelector, InterceptorFactory interceptorFactory);

/// Main macro

#define MakeInterceptorFactory(__ReturnType, __Arguments, __OnIntercept...) \
    (id)                                                                /** Cast the entire factory block to id to silence type-checker */ \
    ^InterceptorBlock (Class m_originalClass, SEL m__cmd, __ReturnType (*m_originalImplementation)(id self, SEL _cmd APPEND_ARGS __Arguments)) /** Return type and args of the factory  block */ \
    {                                                                   /** Body of the factory block */ \
        return ^__ReturnType (id m_self APPEND_ARGS __Arguments)        /** Return type and args of the interceptor block */ \
            __OnIntercept;                                              /**  Body of the interceptor block - the code that the caller of the macro provided. This will be executed when the method is intercepted. Needs to be the varargs to prevent weird compiler errors. */ \
    } \

/// Convenience macros
///     To be used inside the `__OnIntercept` codeblock passed to the `MakeInterceptorFactory()` macro

#define OGImpl(args...) \
    m_originalImplementation(m_self, m__cmd APPEND_ARGS(args))

/// Helper macros
///     To implementation the main macros

#define UNPACK(args...) args /// This allows us to include `,` inside an argument to a macro (but the argument then needs to be wrapped inside `()` by the caller of the macro )
#define APPEND_ARGS(args...) , ## args /// This is like UNPACK but it also automatically inserts a comma before the args. The ## deletes the comma, if `args` is empty. I have no idea why. But this lets us nicely append args to an existing list of arguments in a function call or function header.

/// Old

#define MakeInterceptorFactory_2(__ReturnType, __Arguments, __InterceptionCode) /** This older alternate factory-maker is more neat and properly typed but it seems to break autocomplete */ \
    ({ \
        typedef __ReturnType (*OriginalImplementation)(id, SEL, APPEND_ARGS __Arguments); \
        typedef __ReturnType (^InterceptorBlock)(id self, UNPACK __Arguments); \
        typedef InterceptorBlock (^InterceptorFactory)(Class originalClass, SEL _cmd, OriginalImplementation originalImplementation); \
        \
        (InterceptorFactory) ^InterceptorBlock (Class originalClass, SEL _cmd, OriginalImplementation originalImplementation) { \
            return ^__ReturnType (id self, APPEND_ARGS __Arguments) __InterceptionCode; \
        }; \
    })

@end

NS_ASSUME_NONNULL_END
