//
//  NSString+Additions.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 12.07.24.
//

#import "NSString+Additions.h"

@implementation NSString (Additions)

- (NSString *)stringByAddingIndent:(NSInteger)indent {
    
    NSArray *lines = [self componentsSeparatedByString:@"\n"];
    
    NSMutableArray *paddedLines = [NSMutableArray array];
    for (NSString *line in lines) {
        NSString *paddedLine = [line stringByPrependingWhitespace:indent];
        [paddedLines addObject:paddedLine];
    }
    
    NSString *result = [paddedLines componentsJoinedByString:@"\n"];
    
    return result;
}

- (NSString *)stringByPrependingWhitespace:(NSInteger)spaces {
        
    NSMutableString *whitespace = [NSMutableString string];
    for (int i = 0; i < spaces; i++) {
        [whitespace appendString:@" "];
    }
    
    return [whitespace stringByAppendingString:self];
}



@end
