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
/// NOTE: Found the method `un_localizedStringKey` key by calling listMethods() on NSString instance inside NSLocalizedString [initWithCoder:]:
///     But I couldn't get any info by calling it. 

#import "NSLocalizedStringRecord.h"
#import "objc/runtime.h"
#import "Utility.h"

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

//+ (void)unpackRecord:(NSDictionary *)e callback:(void (^)(NSString *key, NSString *value, NSString *table, NSString *result))callback {
//    callback(e[@"key"], e[@"value"], e[@"table"], e[@"result"]);
//}

@end

///
/// NSBundle swizzling
///

/// vvv Swizzle NSLocalizedString so that it stores any retrieved translations into the NSLocalizedStringRecord (along with the localizationKey which is what we want to annotate the UIElements with)

@implementation NSBundle (LocalizationKeyAnnotations)

+ (void)load {
    
    /// TODO: Only swizzle, when some special 'MF_AX_INSPECTABLE_LOCALIZATION_KEYS' flag is set
    
    swizzleMethod([self class], @selector(localizedStringForKey:value:table:), MakeInterceptorFactory(NSString *, (NSString *key, NSString *value, NSString *tableName), {
        
        /// Call og
        NSString *result = OGImpl(key, value, tableName);
        
        /// Create element
        NSDictionary *newElement = @{
            @"key": key,
            @"value": value ?: @"",
            @"table": tableName ?: @"",
            @"result": result ?: @"",
        };
        
        /// Enqueue
        BOOL isSystemString = [[m_self systemTables] containsObject:tableName] || ![m_self isEqual:NSBundle.mainBundle];
        
        if (!isSystemString) {
            [NSLocalizedStringRecord.queue enqueue:newElement];
        } else {
            [NSLocalizedStringRecord.systemQueue enqueue:newElement];
        }
        
        /// Return
        return result;
    }));
                  
    swizzleMethod([self class], @selector(localizedAttributedStringForKey:value:table:), MakeInterceptorFactory(NSAttributedString *, (NSString *key, NSString *value, NSString *tableName), {
        
        /// Call og
        NSAttributedString *result = OGImpl(key, value, tableName);
        
        /// Create element
        NSDictionary *newElement = @{
            @"key": key,
            @"value": value ?: @"",
            @"table": tableName ?: @"",
            @"result": result ?: @"",
        };
        
        /// Enqueue
        BOOL isSystemString = [[m_self systemTables] containsObject:tableName] || ![m_self isEqual:NSBundle.mainBundle];
        
        if (!isSystemString) {
            [NSLocalizedStringRecord.queue enqueue:newElement];
        } else {
            [NSLocalizedStringRecord.systemQueue enqueue:newElement];
        }
        
        /// Return
        return result;
        
    }));
}

- (NSArray <NSString *>*)systemTables {
    
    /// These string tables are defined by macOS
    ///
    /// Notes:
    /// - Instead of hardcoding these, I think we could also search for a .nib or .strings file in the appBundle with the name of the stringTable of
    ///   a retrieved localizedString. If yes then the stringTable should be defined by the app itself, not the system.
    /// - On the `""`, table
    ///     I saw the following string-retrieval which apparently used a table named empty-string. This is weird. I hope it won't interfere with recording string retrievals by the user.
    ///         key = "search result";
    ///         result = Suchergebnis;
    ///         table = "";
    ///         value = "";
    ///     Update: It turns out that that was called not on our applicationBundle but on the Shortcuts.framework bundle. Now we're filtering out strings retrieved on other bundled. That might make this list obsolete.
    
    
    return @[@"FunctionKeyNames", @"Common", @"InputManager", @"DictationManager", @"MenuCommands", @"WindowTabs", @"NSColorPanelExtras", @"FontManager", @"Services", @"Accessibility", @"AccessibilityImageDescriptions", @"Toolbar", @""];
}

@end


