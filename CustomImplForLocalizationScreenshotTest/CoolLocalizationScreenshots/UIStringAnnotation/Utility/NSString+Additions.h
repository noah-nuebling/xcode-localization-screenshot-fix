//
//  NSString+Additions.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 12.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Additions)


#define stringf(format, ...) \
    [NSString stringWithFormat:format, __VA_ARGS__]

- (NSAttributedString *)attributed;
- (NSString *)stringByAddingIndent:(NSInteger)indent;
- (NSString *)stringByPrependingWhitespace:(NSInteger)spaces;

@end

NS_ASSUME_NONNULL_END
