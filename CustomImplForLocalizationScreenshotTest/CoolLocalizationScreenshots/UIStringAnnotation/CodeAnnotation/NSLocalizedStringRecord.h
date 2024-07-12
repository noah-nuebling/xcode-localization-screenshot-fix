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
+ (void)unpackRecord:(NSDictionary *)e callback:(void (^)(NSString *key, NSString *value, NSString *table, NSString *result))callback;

@end

NS_ASSUME_NONNULL_END
