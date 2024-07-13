//
//  NSString+Additions.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 12.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Additions)

- (NSString *)stringByAddingIndent:(NSInteger)indent;
- (NSString *)stringByPrependingWhitespace:(NSInteger)spaces;

@end

NS_ASSUME_NONNULL_END
