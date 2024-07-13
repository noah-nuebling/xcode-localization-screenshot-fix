//
//  NSLocalizedStringRecord.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 09.07.24.
//

///
/// Explanation:
/// The idea is that whenever translated-string-retrieval-functions such as NSLocalizedString() are called from our code, we record the localized-string-key into the AnnotationQueue.
/// Then, whenever a UIString is set on an object, we want to take take all the localized-string-keys inside the AnnotationQueue and annotate the object with those keys.
///

#import "NSLocalizedStringRecord.h"
#import "Swizzle.h"
#import "objc/runtime.h"

///
/// Forward declare
///

@interface NSString (Tracking)

- (void)setIsTracked:(BOOL)doTrack;
- (BOOL)isTracked;

@end

///
/// LocalizedStringRecord
///

@implementation NSLocalizedStringRecord

static Queue *_localizationKeyQueue;

+ (Queue *)queue {
    if (_localizationKeyQueue == nil) {
        _localizationKeyQueue = [Queue queue];
    }
    return _localizationKeyQueue;
}
static Queue *_systemLocalizationKeyQueue;
+ (Queue *)systemQueue {
    if (_systemLocalizationKeyQueue == nil) {
        _systemLocalizationKeyQueue = [Queue queue];
    }
    return _systemLocalizationKeyQueue;
}
+ (NSSet *)systemSet { /// The system set contains tons of duplicates which we don't care about.
    return [NSSet setWithArray:[self systemQueue]._rawStorage];
}

+ (void)unpackRecord:(NSDictionary *)e callback:(void (^)(NSString *key, NSString *value, NSString *table, NSString *result))callback {
    callback(e[@"key"], e[@"value"], e[@"table"], e[@"result"]);
}

@end

///
/// NSBundle swizzling
///

/// vvv Swizzle NSLocalizedString so that it stores any retrieved translations into the NSLocalizedStringRecord (along with the localizationKey which is what we want to annotate the UIElements with)

@implementation NSBundle (LocalizationKeyAnnotations)

+ (void)load {
    
    /// TODO: Only swizzle, when some special 'MF_AX_INSPECTABLE_LOCALIZATION_KEYS' flag is set
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        swizzleMethods([self class], true, @"swizzled_", @selector(swizzled_localizedStringForKey:value:table:), nil);
        swizzleMethods([self class], true, @"swizzled_", @selector(swizzled_localizedAttributedStringForKey:value:table:), nil);
    });
}

- (NSArray <NSString *>*)systemTables {
    
    /// These string tables are defined by macOS
    return @[@"FunctionKeyNames", @"Common", @"InputManager", @"DictationManager", @"MenuCommands", @"WindowTabs", @"NSColorPanelExtras", @"FontManager", @"Services", @"Accessibility"];
}

- (NSString *)swizzled_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName {
    
    /// Call og
    NSString *result = [self swizzled_localizedStringForKey:key value:value table:tableName];
    
    /// Create element
    NSDictionary *newElement = @{
        @"key": key,
        @"value": value ?: @"",
        @"table": tableName ?: @"",
        @"result": result ?: @"",
    };
    /// Enqueue
    BOOL isSystemString = [[self systemTables] containsObject: tableName];
    if (!isSystemString) {
        [NSLocalizedStringRecord.queue enqueue:newElement];
    } else {
        [NSLocalizedStringRecord.systemQueue enqueue:newElement];
    }
    
    /// TESTING
    if ([result containsString:@"tooltip"]) {
        
    }
    if ([result isEqual:@"Rechtschreibung und Grammatik einblenden"]) {
        
    }
    
    
    /// Return
    return result;
}

- (NSAttributedString *)swizzled_localizedAttributedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName {
    
    assert(false); /// This is untested
    
    /// Call og
    NSAttributedString *result = [self swizzled_localizedAttributedStringForKey:key value:value table:tableName];
    
    /// Create element
    NSDictionary *newElement = @{
        @"key": key,
        @"value": value ?: @"",
        @"table": tableName ?: @"",
        @"result": result ?: @"",
    };
    
    /// Enqueue
    BOOL isSystemString = [[self systemTables] containsObject:tableName];
    
    if (!isSystemString) {
        [NSLocalizedStringRecord.queue enqueue:newElement];
    } else {
        [NSLocalizedStringRecord.systemQueue enqueue:newElement];
    }
    
    /// Return
    return result;
    
}

@end


