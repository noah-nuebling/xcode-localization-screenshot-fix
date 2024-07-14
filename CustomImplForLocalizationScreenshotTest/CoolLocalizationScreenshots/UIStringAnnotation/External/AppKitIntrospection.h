//
//  AppKitIntrospection.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 14.07.24.
//

#import <Foundation/Foundation.h>
#import "AppKit/AppKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSegmentItem

@end

@interface NSCell (MFIntrospection)

- (id)rawContents;

@end

NS_ASSUME_NONNULL_END
