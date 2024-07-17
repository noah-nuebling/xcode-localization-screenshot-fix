//
//  PreprocessorMagic.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 17.07.24.
//

#ifndef PreprocessorMagic_h
#define PreprocessorMagic_h
//
///// Source: https://github.com/pfultz2/Cloak/wiki/C-Preprocessor-tricks,-tips,-and-idioms
//
///////
/////// Pattern matching
///////
//
//#define CAT(a, ...) PRIMITIVE_CAT(a, __VA_ARGS__)
//#define PRIMITIVE_CAT(a, ...) a ## __VA_ARGS__
//
//#define IIF(c) PRIMITIVE_CAT(IIF_, c)
//#define IIF_0(t, ...) __VA_ARGS__
//#define IIF_1(t, ...) t
//
//#define COMPL(b) PRIMITIVE_CAT(COMPL_, b)
//#define COMPL_0 1
//#define COMPL_1 0
//
//#define BITAND(x) PRIMITIVE_CAT(BITAND_, x)
//#define BITAND_0(y) 0
//#define BITAND_1(y) y
//
/////
///// Detection
/////
//
///// I don't get this but this stuff is used by the other macros
/////
//
//#define CHECK_N(x, n, ...) n
//#define CHECK(...) CHECK_N(__VA_ARGS__, 0,)
//#define PROBE(x) x, 1,
//
//#define IS_PAREN(x) CHECK(IS_PAREN_PROBE x)
//#define IS_PAREN_PROBE(...) PROBE(~)
//
//#define NOT(x) CHECK(PRIMITIVE_CAT(NOT_, x))
//#define NOT_0 PROBE(~)
//
//#define BOOL(x) COMPL(NOT(x))
//#define IF(c) IIF(BOOL(c))
//
//#define EAT(...)
//#define EXPAND(...) __VA_ARGS__
//#define WHEN(c) IF(c)(EXPAND, EAT)
//
/////
///// Comparison
/////
//
///// To make a token foo comparable use
/////     `#define COMPARE_foo(x) x`
///// Then compare it with (possibily uncomparable) tokens using
/////     `EQUAL(foo, someOtherToken)`
//
//#define PRIMITIVE_COMPARE(x, y) IS_PAREN \
//( \
//COMPARE_ ## x ( COMPARE_ ## y) (())  \
//)
//
//#define IS_COMPARABLE(x) IS_PAREN( CAT(COMPARE_, x) (()) )
//
//#define NOT_EQUAL(x, y) \
//IIF(BITAND(IS_COMPARABLE(x))(IS_COMPARABLE(y)) ) \
//( \
//   PRIMITIVE_COMPARE, \
//   1 EAT \
//)(x, y)
//
//#define EQUAL(x, y) COMPL(NOT_EQUAL(x, y))
//


#endif /* PreprocessorMagic_h */
