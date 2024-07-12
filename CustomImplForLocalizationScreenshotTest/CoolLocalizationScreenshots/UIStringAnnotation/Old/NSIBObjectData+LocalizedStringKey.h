//
//  NSIBObjectData+LocalizedStringKey.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSIBObjectData : NSObject
/// Declaring the private class.
/// NSIBObjectData seems to be the top-level object in the chain of initWithCoder: calls that we can see when an IB file is loaded.
@end

@interface NSIBObjectData (LocalizedStringKey)
/// Declare a category
/// For our own stuff
@end

NS_ASSUME_NONNULL_END
