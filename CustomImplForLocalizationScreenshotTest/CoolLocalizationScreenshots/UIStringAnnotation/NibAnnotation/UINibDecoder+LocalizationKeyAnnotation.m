//
//  UINibDecoder+LocalizationKeyAnnotation.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 08.07.24.
//

@import ObjectiveC.runtime;
#import "UINibDecoder+LocalizationKeyAnnotation.h"
#import "Swizzle.h"
#import "AppKit/NSAccessibility.h"
#import "AppKit/NSMenu.h"
#import "NSLocalizedStringRecord.h"
#import "UIStringAnnotationHelper.h"
#import "UINibDecoderDefinitions.h"
#import "Utility.h"


#pragma mark - Track isDecoding

/**
 
 We want to swizzle the nibLoading methods that AppKit uses to load the UI from our IB files, so that we can turn off the CodeAnnotation logic so it doesn't interfere with the NibAnnotation logic.
 
 At the top-level, inside NSApplicationMain, AppKit seems to call `+loadNibNamed:owner:`, even though that has been deprecated, then this method  calls
 `-loadNibNamed:owner:topLevelObjects:` or `+-loadNibFile:externalNameTable:withZone:` (Not sure if + or - since I haven't observed this invocation)
 For now I think it should be sufficient to only swizzle `-loadNibNamed:owner:topLevelObjects:` since that seems to be where all the work takes place and what we'll
 use to instantiate Nib files in our own code (since it's the only one that's not deprecated.)
 Update: `-loadNibNamed:owner:topLevelObjects:` does not seem to be sufficient. UIStringChangeDecector still detects lots of string changes before `applicationDidFinishLaunching:` that we don't recognize as part of Nib loading (yet)
 
 Reference:
 
     Modern API:
         ```
         -loadNibNamed:owner:topLevelObjects:
         ```
     
     Deprecated APIs:
         ```
         +loadNibFile:externalNameTable:withZone:
         +loadNibNamed:owner:
         -loadNibFile:externalNameTable:withZone:
         ```
 */

///
/// DecodingDepth defines
///

#define MFLoadNibDepthKey @"MFLoadNibDepth"

BOOL MFIsLoadingNib(void) {
    return MFLoadNibDepth() > 0;
}
NSInteger MFLoadNibDepth(void) {
    return [NSThread.currentThread.threadDictionary[MFLoadNibDepthKey] integerValue];
}
static void MFLoadNibDepthIncrement(void) {
    NSInteger d = MFLoadNibDepth() + 1;
    NSThread.currentThread.threadDictionary[MFLoadNibDepthKey] = @(d);
}
static void MFLoadNibDepthDecrement(void) {
    NSInteger d = MFLoadNibDepth() - 1;
    assert(d >= 0);
    NSThread.currentThread.threadDictionary[MFLoadNibDepthKey] = @(d);
}

#define MFUINibDecoderDepthKey @"MFUINibDecoderDepth"

NSInteger MFUINibDecoderDepth(void) {
    return [NSThread.currentThread.threadDictionary[MFUINibDecoderDepthKey] integerValue];
}
static void MFUINibDecoderDepthIncrement(void) {
    NSInteger d = MFUINibDecoderDepth() + 1;
    NSThread.currentThread.threadDictionary[MFUINibDecoderDepthKey] = @(d);
}
static void MFUINibDecoderDepthDecrement(void) {
    NSInteger d = MFUINibDecoderDepth() - 1;
    assert(d >= 0);
    NSThread.currentThread.threadDictionary[MFUINibDecoderDepthKey] = @(d);
}


///
/// Declare data storage
///

/// Notes:
/// This being global is weird and not thread safe but I'm pretty sure all this NibDecoding stuff only happens on the main thread anyways.

/// Decoder record
static NSMutableArray<NSMutableDictionary *>*_uiNibDecoderRecordStorage = nil;     /// This is filled up as the UINibDecoder recurses in the object-tree of an Nib file.
static NSMutableArray<NSMutableDictionary *>* uiNibDecoderRecord(void) {
    if (_uiNibDecoderRecordStorage == nil) _uiNibDecoderRecordStorage = [NSMutableArray array];
    return _uiNibDecoderRecordStorage;
}

/// Top level objects
static NSArray *_uiNibDecoderRecordTopLevelObjects = nil;                   /// These are returned by `NSNBundle loadNib...:` after the UINibDecoder finishes.

/// Renamed menuItems
static NSMutableDictionary *_menuItemsRenamedBySystem = nil;

/// Delete storage
static void deleteUINibDecoderRecord(void) {
    _uiNibDecoderRecordStorage = nil;
    _uiNibDecoderRecordTopLevelObjects = nil;
    _menuItemsRenamedBySystem = nil; /// We don't really need to delete this, I think?
}

///
/// Forward declare Annotator
///

@interface Annotator : NSObject
+ (void)annotateUIElementsWithDecoderRecord:(NSArray *)decoderRecord topLevelObjects:(NSArray *)topLevelObjects;
@end


///
/// NSBundle swizzling
///

@implementation NSBundle (MFNibAnnotation)

+ (void)load {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [Swizzle swizzleMethodsOnClass:[self class] 
                                 swizzlePrefix:@"swizzled_"
                             swizzledSelectors: @selector(swizzled_loadNibNamed:owner:topLevelObjects:),
                                                @selector(swizzled_loadNibFile:externalNameTable:withZone:), nil];
        
        [Swizzle swizzleMethodsOnClass:object_getClass([NSBundle class])
                                 swizzlePrefix:@"swizzled_"
                             swizzledSelectors: @selector(swizzled_loadNibNamed:owner:),
                                                @selector(swizzled_loadNibFile:externalNameTable:withZone:), nil];
    });
}

- (BOOL)swizzled_loadNibNamed:(NSNibName)nibName owner:(id)owner topLevelObjects:(NSArray * _Nullable __autoreleasing *)topLevelObjects {
    preDive();
    BOOL result = [self swizzled_loadNibNamed:nibName owner:owner topLevelObjects:topLevelObjects];
    assert(_uiNibDecoderRecordTopLevelObjects == nil); 
    if (topLevelObjects != nil && *topLevelObjects != nil) {
        _uiNibDecoderRecordTopLevelObjects = *topLevelObjects;
    }
    postDive(nibName, nil);
    return result;
}

- (BOOL)swizzled_loadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone {
    preDive();
    BOOL result = [self swizzled_loadNibFile:fileName externalNameTable:context withZone:zone];
    postDive(nil, fileName);
    return result;
}

+ (BOOL)swizzled_loadNibNamed:(NSString *)nibName owner:(id)owner {
    preDive();
    BOOL result = [self swizzled_loadNibNamed:nibName owner:owner];
    postDive(nibName, nil);
    return result;
}

+ (BOOL)swizzled_loadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone {
    preDive();
    BOOL result = [self swizzled_loadNibFile:fileName externalNameTable:context withZone:zone];
    postDive(nil, fileName);
    return result;
}

static void preDive(void) {
    
    /// Determine isTopLevel
    BOOL isTopLevel = MFLoadNibDepth() == 0;

    if (isTopLevel) {
        /// Create fresh record (delete its content)
        deleteUINibDecoderRecord();
    }
    
    /// Increase depth
    MFLoadNibDepthIncrement();
}

static void postDive(NSString *nibName, NSString *fileName) {
    
    /// Decrease depth
    MFLoadNibDepthDecrement();
    
    /// Handle topLevel
    BOOL isTopLevel = MFLoadNibDepth() == 0;
    if (isTopLevel) {
        
        /// Check if we own the bundle
        ///     The reason for this code is that when you open the menu bar the system loads a bundle named "SearchMenu2", which we want to ignore and which crashes our Annotator code
        NSString *bundleName = nibName != nil ? nibName : fileName;
        BOOL isOurBundle = [NSBundle.mainBundle pathForResource:bundleName ofType:@"nib"] != nil; /// Should we use the forLocalization arg?
        
        /// Process record
        ///     it's inefficient that we create the record in the first place if it's not our bundle. But efficiency doesn't matter here since we just run this code for localization screenshots.
        if (isOurBundle) {
            [Annotator annotateUIElementsWithDecoderRecord:uiNibDecoderRecord() topLevelObjects:_uiNibDecoderRecordTopLevelObjects];
        }
        
        /// Validate
        assert(MFUINibDecoderDepth() == 0 && MFLoadNibDepth() == 0);
        
    }

}

@end



#pragma mark - UINibDecoder swizzling

@implementation UINibDecoder (MFNibAnnotation)

+ (void)load {
    
    /// TODO: Only swizzle, when some special 'Take Localization Screenshots' flag is set - for performance.
    /// Notes:
    ///     We're only swizzling `decodeObjectForKey:` atm because that's where the localized string keys appear
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzleMethod([self class], @selector(decodeObjectForKey:), @selector(swizzled_decodeObjectForKey:));
    });
}


- (id)swizzled_decodeObjectForKey:(NSString *)key {
    
    /// Increase depth
    MFUINibDecoderDepthIncrement();
    
    /// Call original implementation
    /// Notes:
    /// - This will recursively call this method over and over for all the child objects.
    id result = [self swizzled_decodeObjectForKey:key];
    
    /// Decrease depth
    MFUINibDecoderDepthDecrement();
    
    /// Record
    [uiNibDecoderRecord() addObject:@{
        @"key": key,
        @"value": result != nil ? result : NSNull.null,
        @"depth": @(MFUINibDecoderDepth()),
    }.mutableCopy];
    
    /// Return
    return result;
}
@end

///
/// NSApplication swizzling
///

@implementation NSApplication (MFNibAnnotation)

+ (void)load {
    [Swizzle swizzleMethodsOnClass:[self class] swizzlePrefix:@"swizzled_" swizzledSelectors:@selector(swizzled_validateMenuItem:), nil];
}

- (BOOL)swizzled_validateMenuItem:(NSMenuItem *)menuItem {
    
    NSString *beforeTitle = [menuItem title];
    BOOL result = [self swizzled_validateMenuItem:menuItem];
    NSString *afterTitle = [menuItem title];
    
    if (![beforeTitle isEqual:afterTitle]) {
        if (_menuItemsRenamedBySystem == nil) _menuItemsRenamedBySystem = [NSMutableDictionary dictionary];
        afterTitle = [NSString stringWithCString:[afterTitle cStringUsingEncoding:NSUTF8StringEncoding] encoding:NSUTF8StringEncoding]; /// afterTitle is a weird `_NSBPlistMappedString`, this turns it into a normal NSString
        _menuItemsRenamedBySystem[beforeTitle] = @{
            @"newTitle": afterTitle,
            @"menuItem": menuItem,
        };
    }
    
    return result;
}

@end


///
/// Annotate UI elements
///

@implementation Annotator: NSObject

+ (void)annotateUIElementsWithDecoderRecord:(NSArray *)accumulator topLevelObjects:(NSArray *)topLevelObjects {
    
    ///
    /// Define helper blocks
    ///
    
    /// Define reusable loc-string-extractor
    
    typedef void (^LocalizationKeyExtractorCallback)(NSString *localizationKey, NSString *developmentString, NSString *uiString, NSString *uiStringNibKey);
    void (^unpackLocalizationKeyData)(NSDictionary *, LocalizationKeyExtractorCallback) = ^(NSDictionary *localizationKeyData, LocalizationKeyExtractorCallback callback) {
        
        if (!callback) assert(false);
        
        NSString *locKey = localizationKeyData[@"NSKey"];
        NSString *devStr = localizationKeyData[@"NSDev"] ?: NSNull.null;
        NSString *transStr = localizationKeyData[@"NSDevSuccessor"][@"value"] ?: NSNull.null;
        NSString *transStrKey = localizationKeyData[@"NSDevSuccessor"][@"key"] ?: NSNull.null;
        
        callback(locKey, devStr, transStr, transStrKey);
    };
    
    /// Define annotationQueueCleaner
    
    void (^cleanOutAnnotationQueueAndValidate)(NSArray *) = ^(NSArray *lastLocalizationKeys) {
        
        /// Explanation:
        ///  NSLocalizedStringRecord.queue is made to track localizationKey usage in code (as opposed to localizationKey usage in IB files, which is handled right here),
        ///  However, as the decoder decodes the NIB file, it will call `NSBundle -localizedStringForKey:value:table:` to get translated strings.
        ///  Due to our swizzling, this will also fill up NSLocalizedStringRecord.queue.
        ///  So what we do here is we empty out the NSLocalizedStringRecord.queue so that it is empty and then we can start using .queue to track NSLocalizedString() usage
        ///  We also take this opportunity to validate our logic.
        ///
        ///  Update:
        ///  - We could also just disable enqueing into the NSLocalizedStringRecord while MFUINibDecoderIsDecoding() == YES - That should be simpler.
        
        for (NSDictionary *localizationKeyData in lastLocalizationKeys) {
            unpackLocalizationKeyData(localizationKeyData, ^(NSString *localizationKey, NSString *developmentString, NSString *uiString, NSString *uiStringNibKey) {
                NSDictionary *fromQueue = [NSLocalizedStringRecord.queue dequeue];
                assert(fromQueue != nil);
                assert([localizationKey isEqual:fromQueue[@"key"]]);
                assert([developmentString isEqual:fromQueue[@"value"]]);
                assert(YES || [@"abcdefg" isEqual: fromQueue[@"table"]]); /// Not sure if / how we could validate the table. Should be equal to the filename of the archive that we're decoding?
            });
        }
    };

    
    ///
    /// Main logic
    ///
    
    /// Validate
    assert(true || topLevelObjects != nil && topLevelObjects.count > 0);
    assert(accumulator != nil && accumulator.count > 0);
    
    /// Print
    NSLog(@"-------------------");
    printf("%s", [[NSString stringWithFormat:@"LocStrings: SWOOOZLE, %@\n%@", topLevelObjects, accumulator] cStringUsingEncoding:NSUTF8StringEncoding]); /// Need to use printf since NSLog truncates the output.
    
    /// Declare state for loop
    BOOL lastWasNSDev = NO;
    BOOL setLastWasNSDev = NO;
    NSMutableArray <NSMutableDictionary *> *lastLocalizationKeys = [NSMutableArray array];
    NSMutableArray <NSMutableDictionary *> *lastMarkerLocalizationKeys = [NSMutableArray array];
    NSMutableArray <NSMutableDictionary *> *lastWindowTitleLocalizationKeys = [NSMutableArray array];
    
    for (NSDictionary *kvPair in accumulator) {
    
        /// Extract
        NSString *key = kvPair[@"key"];
        id value = kvPair[@"value"];
        
        /// Process
        if ([key isEqual: @"NSKey"]) {
            
            /// Collect localization keys
            [lastLocalizationKeys addObject:@{
                @"NSKey": value,
            }.mutableCopy];
            
            
        } else if ([key isEqual:@"NSDev"]) {
            
            /// Collect base-language ui-strings
            lastLocalizationKeys.lastObject[@"NSDev"] = value;
            setLastWasNSDev = YES;
            
        } else if ([key isEqual: @"NSSuperview"] || [key isEqual: @"NSNextResponder"] || [key isEqual: @"NSNextKeyView"] || [key isEqual: @"NSSubviews"]) {
            
            /// Skip links to other views.
            ///     Not sure why/if this makes sense, but I think it does. -> We want the next accessibility Element we iterate over
            ///     to be the container for last localizedStringKeys that we iterated over. I think this is the case if we skip superview.
            
        } else if (lastWasNSDev) {
            
            /// Record NSDev successor
            ///     Note: The item after the NSDev entry always seems to hold the translated UI String for the current language - but
            ///     the key is not always the same
            
            lastLocalizationKeys.lastObject[@"NSDevSuccessor"] = @{
                @"key": key,
                @"value": value,
            };
            
            /// Validate
            BOOL isString = [value isKindOfClass:[NSString class]];
            assert(isString);
            
            /// Special case: NSMarker
            ///     These are then handled in the `NSConnections` case below.
            /// Note:
            ///     The NSMarker key appears for tooltip-strings. (Maybe also elsewhere but I've only seen it on tooltips)
            ///     We have to determine the AccessibilityElement that the tooltip-strings belong to in a special way (using the NSConnections array)
            if ([key isEqual:@"NSMarker"]) {
                /// Extract last key
                NSMutableDictionary *lastKey = lastLocalizationKeys.lastObject;
                [lastLocalizationKeys removeLastObject];
                
                /// Add it to the marker list
                [lastMarkerLocalizationKeys addObject:lastKey];
                
                /// Clean out annotationQueue
                cleanOutAnnotationQueueAndValidate(@[lastKey]);
            }
            
            /// Special case: NSWindowTitle & NSWindowSubtitle
            ///     We handle this case below under `NSWindowView`
            
            BOOL isWindowTitle = [key isEqual: @"NSWindowTitle"];
            BOOL isWindowSubtitle = [key isEqual: @"NSWindowSubtitle"];
            if (isWindowTitle || isWindowSubtitle) {
                
                /// Extract last key
                NSMutableDictionary *lastKeyData = lastLocalizationKeys.lastObject;
                [lastLocalizationKeys removeLastObject];
                
                /// Add it to the windowTitle list
                [lastWindowTitleLocalizationKeys addObject:lastKeyData];
                
                /// Clean out annotationQueue
                cleanOutAnnotationQueueAndValidate(@[lastKeyData]);
                
            }
        } else if ([key isEqual:@"NSWindowView"]) {
            
            /// Find windows in topLevelObjects
            ///     Sidenote: The accumulator doesn't seem to contain a reference to an NSWindow instance. But there's a
            ///     `NSVisibleWindows` key in the accumulator, which contains `NSWindowTemplate` objects. We managed to
            ///     extract a ref to the to the windows' contentView and the window's title but then we didn't pursue that approach further.
            
            NSMutableArray *windows = [NSMutableArray array];
            for (NSObject *object in topLevelObjects) {
                if ([object isKindOfClass:[NSWindow class]]) {
                    [windows addObject:object];
                }
            }
            assert(windows.count >= 1); /// We don't know how to deal with multiple windows
            
            /// Find window for windowView
            NSWindow *matchingWindow = nil;
            for (NSWindow *window in windows) {
                if ([window.contentView isEqual:(NSView *)value]) {
                    matchingWindow = window;
                    break;
                }
            }
            
            /// Annotate the window
            
            for (NSDictionary *localizationKeyData in lastWindowTitleLocalizationKeys) {
                
                unpackLocalizationKeyData(localizationKeyData, ^(NSString *localizationKey, NSString *developmentString, NSString *uiString, NSString *uiStringNibKey) {
                    NSAccessibilityElement *annotation = [UIStringAnnotationHelper createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
                    [UIStringAnnotationHelper addAnnotations:@[annotation] toAccessibilityElement:matchingWindow];
                });
            }
            
            /// Remove processed keys
            [lastWindowTitleLocalizationKeys removeAllObjects];
            
            
        } else if ([key isEqual:@"NSConnections"]) {
            
            /// I think there should only be a single `NSConnections` key at the very end of the accumulator. I would assert this but it's too annoying.
            
            /// Find help-connections
            NSMutableArray <NSIBHelpConnector *>*helpConnections = [NSMutableArray array];
            NSArray *connections = value;
            for (NSIBHelpConnector *connection in connections) {
                if ([connection isKindOfClass:[NSIBHelpConnector class]]) {
                    [helpConnections addObject:connection];
                }
            }
            
            /// Add annotations
            NSMutableArray <NSMutableDictionary *>*processedLocalizationKeys = [NSMutableArray array];
            for (NSMutableDictionary *localizationKeyData in lastMarkerLocalizationKeys) {
                
                unpackLocalizationKeyData(localizationKeyData, ^(NSString *localizationKey, NSString *developmentString, NSString *uiString, NSString *uiStringNibKey) {
                    
                    for (NSIBHelpConnector *connector in helpConnections) {
                        
                        /// Retrieve connector attributes
                        NSString *connectionMarker = [connector marker];
                        NSObject <NSAccessibility>*connectionDestination = (id)[connector destination];
                        NSObject <NSAccessibility>*axConnectionDestination = [Utility getRepresentingAccessibilityElementForObject:connectionDestination];
                        
                        /// Validate
                        assert(axConnectionDestination != nil);
                        
                        if (connectionMarker == uiString) { /// Note that were using == so we're checking pointer-level equality
                            
                            /// Add annotation
                            NSAccessibilityElement *annotation = [UIStringAnnotationHelper createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
                            [UIStringAnnotationHelper addAnnotations:@[annotation] toAccessibilityElement:axConnectionDestination];
                            
                            /// Mark localizationKey as processed
                            [processedLocalizationKeys addObject:localizationKeyData];
                        }
                    }
                });
            }
            
            /// Remove processed keys
            [lastMarkerLocalizationKeys removeObjectsInArray:processedLocalizationKeys];
            
            /// Validate
            ///     Make sure all markerLocalizationKeys have been processed.
            assert(lastMarkerLocalizationKeys.count == 0);
            
        } else {
            
            /// Check if `value` is an accessibility element
            
            BOOL isAccessibilityElement = NO;
            
            if ((NO)) {
                
                /// Approach 1:
                ///     Note: This approach catches NSTextView which doesn't actually participate in the accessibility-view-hierarchy
                
                NSArray *baseAccessibilityProtocols = @[@protocol(NSAccessibility), @protocol(NSAccessibilityElement), @protocol(NSAccessibilityElementLoading)];
                for (Protocol *protocol in baseAccessibilityProtocols) {
                    if ([[value class] conformsToProtocol:protocol]) {
                        isAccessibilityElement = YES;
                        break;
                    }
                }
            } else {
                
                /// Approach 2:
                ///     Note: `isAccessibilityElement` is the modern replacement for `accessibilityIsIgnored`. The docs for that explain it.
                if ([value respondsToSelector:@selector(isAccessibilityElement)]) {
                    isAccessibilityElement = [value isAccessibilityElement];
                }
            }
            
            if (isAccessibilityElement) {
                
                /// Attach localization keys
                /// Notes:
                /// - We assume that the first accessibilityElement we find is the container holding the strings inside the the `lastLocalizationKeys` list.
                /// - This all depends on the order of elements in the `accumulator` (which is what we're iterating over).
                /// - The order of the accumulator is equivalent to the order that elements are decoded by `initWithCoder:`. From my understanding, this is a depth-first-search through the object-hierarchy
                /// - NSKeyedUnarchiver, which is the most common NSCoder subclass (the NSCoder subclass we're dealing with here is UINibDecoder) also implements this object-hierarchy stuff. Maybe its docs are helpful.
                
                if (lastLocalizationKeys.count > 0) {
                    
                    ///
                    /// Update NSLocalizedStringRecord.queue
                    ///
                        
                    cleanOutAnnotationQueueAndValidate(lastLocalizationKeys);
//                    assert([NSLocalizedStringRecord.queue isEmpty]);
                    
                    ///
                    /// Publish data for accessibility inspection
                    ///
                    
                    if ([key isEqual:@"NSMenu"]) {
                        
                        /// Special case - NSMenu
                        ///     Spread out the keys to the NSMenuItems inside the NSMenu
                        
                        for (NSDictionary *localizationKeyData in lastLocalizationKeys) {
                         
                            unpackLocalizationKeyData(localizationKeyData, ^(NSString *localizationKey, NSString *developmentString, NSString *uiString, NSString *uiStringNibKey) {
                               
                                /// Get new ax child
                                NSAccessibilityElement *annotationElement = [UIStringAnnotationHelper createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
                                
                                /// Get menuItem
                                NSMenuItem *item = [(NSMenu *)value itemWithTitle:uiString];
//                                if (!item) {
//                                    /// Fallback
//                                    ///     I think this is necessary for some of the items that are automatically added and translated by macOS.
//                                    item = [(NSMenu *)value itemWithTitle:developmentString];
//                                }
                                if (!item) {
                                    NSDictionary *rename = _menuItemsRenamedBySystem[uiString];
                                    if (rename != nil) {
                                        item = rename[@"menuItem"];
                                    }
                                }
                                
                                if (!item) {
                                    
                                    /// Fallback: Add directly to menu
                                    /// Notes:
                                    /// - We can't tell apart the localizationKeys for the NSMenuTitle from the localizationKeys for the NSMenuItems.
                                    ///     So this case will always hit for the NSMenuTitle afaik.
                                    /// - I think this might fail in a subtle way if the NSMenuTitle is the same as the title for one of its items.
                                    ///     Then we might associate the NSMenuTitle localizationKey with the NSMenuItem instead.
                                    
                                    [UIStringAnnotationHelper addAnnotations:@[annotationElement] toAccessibilityElement:value];


                                    
                                } else {
                                    
                                    /// Regular case: Add to item
                                    [UIStringAnnotationHelper addAnnotations:@[annotationElement] toAccessibilityElement:item];

                                }
                            });
                            
                        }
                        
                    } else {
                        
                        /// Default case
                        ///     Simply add the keys as direct children of the element.
                        
                        
                        /// Get children
                        NSMutableArray <NSAccessibilityElement *>*annotationElements = [NSMutableArray array];
                        for (NSDictionary *localizationKeyData in lastLocalizationKeys) {
                            unpackLocalizationKeyData(localizationKeyData, ^(NSString *localizationKey, NSString *developmentString, NSString *uiString, NSString *uiStringNibKey){
                                
                                NSAccessibilityElement *newElement =
                                [UIStringAnnotationHelper createAnnotationElementWithLocalizationKey:localizationKey
                                                                                    translatedString:uiString
                                                                                   developmentString:developmentString
                                                                              translatedStringNibKey:uiStringNibKey
                                                                                            mergedUIString:nil];
                                
                                [annotationElements addObject:newElement];
                            });
                        }
                        
                        /// Attach children
                        [UIStringAnnotationHelper addAnnotations:annotationElements toAccessibilityElement:value];
                    }
                    
                    /// Clear lastLocalizationKeys
                    [lastLocalizationKeys removeAllObjects];
                }
            }
        }
        
        /// Handle setLastWasNSDev flag
        ///     If setLastWasNSDev was set to YES in this iteration, then for the next iteration lastWasNSDev will be YES.
        
        if (setLastWasNSDev) {
            lastWasNSDev = YES;
        } else {
            lastWasNSDev = NO;
        }
        setLastWasNSDev = NO;
    }
    
    /// Validate
    /// - If our processing was successful, then all these should be empty
    assert([NSLocalizedStringRecord.queue isEmpty]);
    assert(lastLocalizationKeys.count == 0);
    assert(lastMarkerLocalizationKeys.count == 0);
}

@end

///
/// --------------------------------------
///


///
/// Test stuff
///
/// Conclusion:
///     The localization string keys are inside UINibDecoder instances, but NSCoders have this weird 'scoping' mechanism where if they decode a hierarchy of objects, each object can only access the keys for itself inside the coder. This prevents naming conflicts between the keys which is nice, however, I have no clue how to shift the 'scope' around to objects deeper in the hierarchy. I can only manage to access top level keys.
///
///     So Instead, what we'll do, is we'll let outside objects methods pass an NSDictionary to an UINibCoder instance, and then have the coder record (some of) the kv-pairs its decoding into that NSDictionary, so that initWithCoder: can then later inspect those kv-pairs.

#if FALSE
//- (Class)swizzled_classForClassName:(NSString *)codedName {
//    
//    /// Print
//    NSLog(@"Decoding %@  object ...", codedName);
//    
//    /// Call og
//    return [self swizzled_classForClassName:codedName];
//}

- (id)swizzled_decodeObjectForKey:(NSString *)key {
    
    /// Call og
    id result = [self swizzled_decodeObjectForKey:key];
    
    /// Print
    NSLog(@"Decoding object for key %@ -> %@ (%llx)", key, result, (int64_t)self);
    
    
    /// Pause
    
    if ([key isEqual:@"NSDrawMatrix"]) {
        
    }
    
    if ([key isEqual:@"NSContents"]) {
        
    }
    
    if ([key isEqual:@"NSObjectsValues"]) {
        
    }
    if ([key isEqual:@"NSSubviews"]) {
        
    }
    
    if ([key isEqual:@"NSKey"]) { /// NSDev and NSKey are used by [NSLocalizedString initWithCoder:]
        
    }
    
    if ([key isEqual:@"NSWindowRect"]) { /// test
        
    }
    
    /// Return
    return result;
}

- (BOOL)swizzled_containsValueForKey:(NSString *)key {
    
    /// Print
    /// Note: Disabling bc not that interesting (for now)
//    NSLog(@"Decoder checking for key %@", key);
    
    /// Call og
    return [self swizzled_containsValueForKey:key];
}

- (id)swizzled_decodePropertyListForKey:(NSString *)key {
    
    /// Print
    NSLog(@"Decoding property list for key: %@", key);
    
    /// Call og
    return [self swizzled_decodePropertyListForKey:key];
}

- (id)swizzled_decodeObjectOfClass:(Class)aClass forKey:(NSString *)key {
    
    
    /// Print
    /// This just calls decodeObjectOfClasses:
//    NSLog(@"Decoding object of type %@ for key %@", [aClass className], key);
    
    /// Call og
    return [self swizzled_decodeObjectOfClass:aClass forKey:key];
}

- (id)swizzled_decodeObjectOfClasses:(NSSet<Class> *)classes forKey:(NSString *)key {
    
    /// Call og
    id result = [self swizzled_decodeObjectOfClasses:classes forKey:key];
    
    /// Print
    if (classes.count == 1) {
        NSLog(@"Decoding object of type %@ for key %@ -> %@ (%llx)", classes.anyObject, key, result, (int64_t)self);
    } else {
        NSLog(@"Decoding objects of types %@ for key %@ -> %@ (%llx)", classes.description, key, result, (int64_t)self);
    }
    
    
    
    /// Return
    return result;
    
}

- (NSArray *)swizzled_decodeArrayOfObjectsOfClasses:(NSSet<Class> *)classes forKey:(NSString *)key {
    
    /// Print
    NSLog(@"Decoding array of objects of type %@ for key %@", classes.debugDescription, key);
    
    /// Call og
    return [self swizzled_decodeArrayOfObjectsOfClasses:classes forKey:key];
}

- (void)swizzled_decodeValueOfObjCType:(const char *)type at:(void *)data size:(NSUInteger)size {
    
    /// Call og
    [self swizzled_decodeValueOfObjCType:type at:data size:size];
    
    /// Print
    NSLog(@"Decoding value of objc type: %s, size: %lu", type, (unsigned long)size);
    
}


- (id)swizzled_nextGenericKey {
    
    id result = [self swizzled_nextGenericKey];
    NSLog(@"Decoder queried nextGenericKey: %@", result);
    return result;
}

- (id)swizzled_decodeObject {
    
    id result = [self swizzled_decodeObject];
    NSLog(@"Decoding non-keyed object -> %@", result);
    return result;
}

- (void)swizzled_replaceObject:(id)arg1 withObject:(id)arg2 {
    
    NSLog(@"Decoder replacing object %@ -> %@", arg1, arg2);
    [self swizzled_replaceObject:arg1 withObject:arg2];
}

- (void)swizzled_finishDecoding {
    NSLog(@"Decoder finishing (%llx)", (int64_t)self);
    [self swizzled_finishDecoding];
}

- (BOOL)swizzled_validateAndIndexData:(id)arg1 error:(id*)arg2 {
    NSLog(@"Decoder validate & index (data)");
    BOOL result = [self swizzled_validateAndIndexData:arg1 error:arg2];
    return result;
}
- (BOOL)swizzled_validateAndIndexClasses:(const void*)arg1 length:(unsigned long long)arg2 {
    NSLog(@"Decoder validate & index (classes)");
    BOOL result = [self swizzled_validateAndIndexClasses:arg1 length:arg2];
    return result;
}
- (BOOL)swizzled_validateAndIndexObjects:(const void*)arg1 length:(unsigned long long)arg2 {
    NSLog(@"Decoder validate & index (objects)");
    BOOL result = [self swizzled_validateAndIndexObjects:arg1 length:arg2];
    return result;
}
- (BOOL)swizzled_validateAndIndexKeys:(const void*)arg1 length:(unsigned long long)arg2 {
    NSLog(@"Decoder validate & index (keys)");
    BOOL result = [self swizzled_validateAndIndexKeys:arg1 length:arg2];
    return result;
}
- (BOOL)swizzled_validateAndIndexValues:(const void*)arg1 length:(unsigned long long)arg2 {
    NSLog(@"Decoder validate & index (values)");
    BOOL result = [self swizzled_validateAndIndexValues:arg1 length:arg2];
    return result;
}

+ (void)load {
    
    /// This approach is from here: https://stackoverflow.com/a/19631868/10601702
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        swizzleMethod([self class], @selector(decodeObjectForKey:), @selector(swizzled_decodeObjectForKey:));
//        swizzleMethod([self class], @selector(classForClassName:), @selector(swizzled_classForClassName:));
        swizzleMethod([self class], @selector(containsValueForKey:), @selector(swizzled_containsValueForKey:));
//        swizzleMethod([self class], @selector(decodeObjectOfClass:forKey:), @selector(swizzled_decodeObjectOfClass:forKey:));
        swizzleMethod([self class], @selector(decodePropertyListForKey:), @selector(swizzled_decodePropertyListForKey:));
        swizzleMethod([self class], @selector(decodeArrayOfObjectsOfClasses:forKey:), @selector(swizzled_decodeArrayOfObjectsOfClasses:forKey:));
        swizzleMethod([self class], @selector(decodeObjectOfClasses:forKey:), @selector(swizzled_decodeObjectOfClasses:forKey:));
        swizzleMethod([self class], @selector(decodeValueOfObjCType:at:size:), @selector(swizzled_decodeValueOfObjCType:at:size:));
        swizzleMethod([self class], @selector(nextGenericKey), @selector(swizzled_nextGenericKey));
        swizzleMethod([self class], @selector(decodeObject), @selector(swizzled_decodeObject));
        swizzleMethod([self class], @selector(replaceObject:withObject:), @selector(swizzled_replaceObject:withObject:));
        swizzleMethod([self class], @selector(finishDecoding), @selector(swizzled_finishDecoding));
        
        swizzleMethod([self class], @selector(validateAndIndexData:error:), @selector(swizzled_validateAndIndexData:error:));
        swizzleMethod([self class], @selector(validateAndIndexClasses:length:), @selector(swizzled_validateAndIndexClasses:length:));
        swizzleMethod([self class], @selector(validateAndIndexObjects:length:), @selector(swizzled_validateAndIndexObjects:length:));
        swizzleMethod([self class], @selector(validateAndIndexKeys:length:), @selector(swizzled_validateAndIndexKeys:length:));
        swizzleMethod([self class], @selector(validateAndIndexValues:length:), @selector(swizzled_validateAndIndexValues:length:));
        
//        [Swizzle swizzleAllMethodsInClass:[self class]];
    });
    
}

@end

#endif
