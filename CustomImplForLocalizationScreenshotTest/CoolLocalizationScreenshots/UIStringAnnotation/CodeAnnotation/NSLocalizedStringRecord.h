//
//  NSLocalizedStringRecord.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 09.07.24.
//

#import <Foundation/Foundation.h>
#import "Queue.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSLocalizedStringRecord : NSObject

+ (Queue <NSDictionary *>*)queue;
+ (Queue <NSDictionary *>*)systemQueue;
+ (NSSet <NSDictionary *>*)systemSet;

#define unpackLocalizedStringRecord(__LocalizedStringRecord) \
    __unused NSString *m_stringKeyFromRecord = __LocalizedStringRecord[@"key"]; \
    __unused NSString *m_developmentStringFromRecord = __LocalizedStringRecord[@"value"]; \
    __unused NSString *m_stringTableFromRecord = __LocalizedStringRecord[@"table"]; \
    __unused NSString *m_localizedStringFromRecord = __LocalizedStringRecord[@"result"]; \

@end

NS_ASSUME_NONNULL_END
