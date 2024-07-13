//
//  NSObject+LocalizationKeyAnnotations.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 09.07.24.
//

/**
 
 In this file we're trying to get a callback that fires whenever any UI Strings are changed throughout the app.
 
 Explanation:
 
    We found that AppKit seems to publish all UI Strings in the AXTitle or AXValue accessibility attributes, so if we can detect changes of those attributes, we can detect all UI String changes (as long as the UI Strings are handled by AppKit)! We tried to swizzle the getters and setters but that didn't work. However, AppKit conveniently sends NSAccessibilityValueChangedNotification and NSAccessibilityTitleChangedNotification whenever these values change, so if we can intercept those, we can detect UIString changes!
    -  The best way we found to do this is to swizzle private `- accessibilityPostNotification:` methods which are found throughout AppKit. I'm not entirely sure this works in all cases but it seems to be pretty good from what I can tell.
        
    Approach 1:
    The most robust and straightforward way of monitoring the AXTitle and AXValue change-notifications would be using the standard AXObserverAddNotification() API to receive the notifications after AppKit sends them. 
    However, these notificaitons are meant for Assistive Apps as a way to control an app, not for apps to introspect themselves (what we're trying to do) and I think the notifications don't contain a reference back to the underlying object but only to the accessibiltyElement that is representing the underlying object. Now what we're ultimately trying to do is to publish to the AXUI API, the localization keys for each AXUIElement that contains a localizable string - and for that we might not need a reference to the underlying NSObject represented by the AXUIElement at all. We could also probably somehow reconstruct the reference by recursively traversing the `[NSObject<NSAccessibility> accessibilityChildren]` until we somehow find and identify the child that is represented by the AXUIElement which we received a notification for, so I don't think this would really be an issue.
    The other hypothetical issue I thought of is that, when we programmatically set a UIString on an NSObject right after the object is loaded, but before that object is added to the view hierarchy, then perhaps the AXTitle- and AXValue-changed-notifications won't be sent, because the NSObject isn't observed by the AXUI API, yet. I haven't tested this so I'm not sure it's an issue. But this hypothetical problem and the complicated nature of this approach has lead me to try another approach first:
 
    Approach 2:
    Instead of trying to observe the AXUI notifications that are being sent, we could instead try to intercept that code that sends the notifications. From playing around in LLDB, I found these functions which seem to be internally used by AppKit to send the notifications:
        NSAccessibilityPostNotification
        NSAccessibilityPostNotificationWithUserInfo
        NSAccessibilityPostNotificationForObservedElementWithUserInfo
    However, these are C functions which we cannot intercept as far as I know. Also I saw that NSCell doesn't seem to invoke these functions at all, if it finds that there are no AX observers trying to inspect the app.
    However, what we found is that NSCell seem to be handling the text in all the basic macOS UI elements that we tested at the time of writing (NSTextField, NSButton, NSMenuItem) and when the UIString changes, it always Consistently seems to call `- accessibilityPostNotification:`! So by just intercepting that, we should be able to catch most UI String updates. Then we regexed around in the AppKit symbol table using LLDB and found all the swizzable methods (not pure C functions) containing the words 'accessibility' and 'post' or 'send'. 
 
 Methods:
 
     Methods we might want to intercept
     (To detect any UIString updates)
     ([x] means we are intercepting, [-] means we're not intercepting, [?] means we might want to intercept this in the future)
     
     These are from accessibilityNotificationPostingSymbolsFromLLDB.txt
     ```
     [x] -[NSCell(NSCellAccessibility) accessibilityPostNotification:]
     [x] -[NSText(NSTextAccessibilityPrivate) accessibilityPostNotification:]
     [x] -[NSText(NSTextAccessibilityPrivate) accessibilityPostNotification:withNotificationElement:]
     [x] -[NSControl(NSControlAccessibilityAdditions) accessibilityPostNotification:context:]
     [x] -[NSWindow(NSWindowAccessibility) accessibilityPostNotification:]
     [x] -[NSMenu postAccessibilityNotification:]
     [?] -[NSMenu _performActionWithHighlightingForItemAtIndex:sendAccessibilityNotification:]
     [x] -[NSSecureTextView(NSTextAccessibilityPrivate) accessibilityPostNotification:]
     [?] -[NSSecureTextView(NSTextAccessibilityPrivate) _accessibilityPostValueChangeNotificationAfterDelay]
     [?] -[NSWindow(NSRemoteWindowAccessibility) accessibilitySendDeferredNotifications]
     [?] -[NSWindow(NSRemoteWindowAccessibility) accessibilityAddDeferredNotification:]
     [?] -[NSObject(NSAccessibilityNotifications) accessibilitySupportsNotifications]
     [?] -[NSObject(NSAccessibilityNotifications) accessibilityShouldSendNotification:]     NOTE: I've seen this be called when AXApplicationDeactivated maybe we should intercept this.
     [?] -[NSCell(NSCellAccessibility) accessibilityShouldSendNotification:]
     [?] -[NSView(NSViewAccessibility) accessibilityShouldSendNotification:]
     
     [-] NSAccessibilityPostNotification
     [-] NSAccessibilityPostNotificationWithUserInfo
     [-] NSAccessibilityPostNotificationForObservedElementWithUserInfo
     [-] NSAccessibilityPostApplicationActivated
     [-] _NSAccessibilityPostDragTrackingNotificationForObject
     [-] _NSAccessibilityUnregisterUniqueIdForUIElementAndSendDestroyedNotification
     [-] _NSAccessibilityRemoveAllObserversAndSendDestroyedNotification
     ```
 */

#import "UIStringChangeDetector.h"
#import "Swizzle.h"
#import "NSLocalizedStringRecord.h"
#import "UIStringAnnotationHelper.h"
#import "UINibDecoder+LocalizationKeyAnnotation.h"

@interface UIStringChangeInterceptor : NSObject
@end

@implementation UIStringChangeInterceptor

+ (void)onNotification:(NSAccessibilityNotificationName)notification postedBy:(id)object result:(void *)result {
    [self onNotification:notification postedBy:object context:nil element:nil result:result];
}

+ (void)onNotification:(NSAccessibilityNotificationName)notification postedBy:(id<NSAccessibility>)object context:(id)context element:(id)element result:(void *)result {
    
    /// TODO: Implement change-detection for tooltips and placeholders
    
    /// Validate
    ///     I'm pretty sure the notification-posting-methods all return void, we're just catching the `result` to double check.
    assert(true || result == 0); /// On AXMoved notifs I've seen the result be non-zero
    assert([object isKindOfClass:[NSObject class]]);
    assert(true || [object isAccessibilityElement]); /// This doesn't always hold true, not sure why
    assert(context == 0 || [context isKindOfClass:[NSObject class]]);
    assert(element == 0 || [element isKindOfClass:[NSObject class]]);
    
    /// Extract
    BOOL isUIStringChange = [notification isEqual:NSAccessibilityTitleChangedNotification] || [notification isEqual:NSAccessibilityValueChangedNotification];
    
    if (isUIStringChange) {
        
        /// Check if we're currently decoding an Nib file
        BOOL isDecodingNibFile = MFIsLoadingNib();
        
        /// Log
        if (context == 0 && element == 0 && result == 0) {
            NSLog(@"UIStringChangeInterceptor: %@ postedNotification: %@ - isDecodingNibFile: %d", object, notification, isDecodingNibFile);
        } else {
            NSLog(@"UIStringChangeInterceptor: %@ postedNotification: %@ (context: %@, element %@ return: %lld) - isDecodingNibFile: %d", object, notification, context, element, (int64_t)result, isDecodingNibFile);
        }
        
        if (isDecodingNibFile) {
            /// In this case our UINibDecoder code is handling string annotations, and we don't want to annotate ui elements here.
        } else {
            
            /// Publish localization keys on the changed element:
            ///     (aka `annotate` the elements)
            NSAccessibilityAttributeName changedAttribute = [UIStringAnnotationHelper getAttributeForAccessibilityNotification:notification];
            NSArray *records = [self extractBestElementsFromLocalizedStringRecordForObject:object withChangedAttribute:changedAttribute];
            
            if (records.count > 0) {
                NSLog(@"UIStringChangeInterceptor: publishing keys: %@ on object: %@", records, object);
            } else {
                NSLog(@"UIStringChangeInterceptor: not publishing keys on object: %@ since queue is empty", object);
            }
        
            for (NSDictionary *r in records) {
                [NSLocalizedStringRecord unpackRecord:r callback:^(NSString * _Nonnull key, NSString * _Nonnull value, NSString * _Nonnull table, NSString * _Nonnull result) {
                    
                    NSAccessibilityElement *annotation = [UIStringAnnotationHelper createAnnotationElementWithLocalizationKey:key translatedString:result developmentString:value translatedStringNibKey:nil mergedUIString:nil];
                    [UIStringAnnotationHelper addAnnotations:@[annotation] toAccessibilityElement:object];
                }];
                
                
            }
        }
        
    }
}

+ (NSArray <NSDictionary *>*)extractBestElementsFromLocalizedStringRecordForObject:(id<NSAccessibility>)object withChangedAttribute:(NSAccessibilityAttributeName)changedAttribute {
    
    /// TODO: Make this work
    
    /// Get localized strings composing this upate
    NSArray *localizedStringsComposingThisUpdate = nil;
    
    /// Get the updated UI string from the object
    NSDictionary *uiStrings = [UIStringAnnotationHelper getUserFacingStringsFromAccessibilityElement:object];
    NSString *updatedUIString = uiStrings[changedAttribute];
    
    /// Get NSLocalizedString()'s which make up the new UIString
    if (_localizedStringsComposingNextUpdate != nil) {
        
        /// Explanation:
        ///     This case is intended to occur when the application code has called NSLocalizedString() several times, and then composed the resulting raw localizedStrings together
        ///     before setting them as a UIString to the UIElement `object`. In this case, we can't determine with high confidence which entries in the
        ///     NSLocalizedStringRecord belong to `object`, since no UIStrings on `object` exactly match any of the strings in the NSLocalizedStringRecord.
        ///     So for this case, we require the application code to call `nextUIStringUpdateIsComposedOfRawLocalizedStrings:`
        ///     to let us know which raw localized strings compose the new UIString that was set on `object`.
        
        assert(![_localizedStringsComposingNextUpdate containsObject:updatedUIString]);
        localizedStringsComposingThisUpdate = _localizedStringsComposingNextUpdate;
        
    } else {
        
        /// Explanation:
        ///     This means that the UIString that changed on the element is exactly equal to one of the entries in the NSLocalizedStringRecord.
        ///     So we have high confidence that exactly this entry in the NSLocalizedStringRecord belongs to `object`, and we'll only extract that one.
        ///     This
        
        localizedStringsComposingThisUpdate = @[updatedUIString];
    }
    
    /// Update global state
    _localizedStringsComposingNextUpdate = nil;
    
    /// Find matches in NSLocalizedStringRecord
    NSMutableArray <NSDictionary *> *matchingLocalizedStringRecords = nil;
    for (NSString *localizedString in localizedStringsComposingThisUpdate) {
        for (NSDictionary *localizedStringRecord in NSLocalizedStringRecord.queue.peekAll) {
            [NSLocalizedStringRecord unpackRecord:localizedStringRecord callback:^(NSString * _Nonnull key, NSString * _Nonnull value, NSString * _Nonnull table, NSString * _Nonnull result) {
                BOOL isPerfectMatch = [result isEqual:localizedString] && result.length > 0;
                if (isPerfectMatch) {
                    [matchingLocalizedStringRecords addObject:localizedStringRecord];
                }
            }];
        }
    }
    
    /// Validate
    if (matchingLocalizedStringRecords.count == localizedStringsComposingThisUpdate.count) {
        NSLog(@"UIStringChangeDetector: Something went wrong! Remember to call `nextUIStringUpdateIsComposedOfRawLocalizedStrings:` before setting a UIString to an object - if that UIString has been altered after being retrieved from NSLocalizedString()");
        assert(false);
    }
    
    /// Remove the matching records from the record 
    ///     (the record of records? weird naming)
    ///     (We totally misuse the queue here. Should probably not use queue at all.)
    [NSLocalizedStringRecord.queue._rawStorage removeObjectsInArray:matchingLocalizedStringRecords];
    
    /// Return
    return matchingLocalizedStringRecords;
}

static NSArray <NSString *>*_localizedStringsComposingNextUpdate = nil;
+ (void)nextUIStringUpdateIsComposedOfRawLocalizedStrings:(NSArray <NSString *>*)rawLocalizedStrings {
    
    assert(_localizedStringsComposingNextUpdate == nil);
    _localizedStringsComposingNextUpdate = rawLocalizedStrings;
}

@end

///
/// Intercept NSCell
///

@implementation NSCell (MFUIStringInterception)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [Swizzle swizzleMethodsOnClass:[self class] swizzlePrefix:@"swizzled_" swizzledSelectors:@selector(swizzled_accessibilityPostNotification:), nil];
    });
}

- (void *)swizzled_accessibilityPostNotification:(NSAccessibilityNotificationName)notificationName {
    /// Notes:
    /// - This is called all the time by common UI elements when the UI String changes.
    void *result = (void *)[self swizzled_accessibilityPostNotification:notificationName];
    [UIStringChangeInterceptor onNotification:notificationName postedBy:self result:result];
    return result;
}

@end

/// Intercept NSText

@implementation NSText (MFUIStringInterception)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [Swizzle swizzleMethodsOnClass:[self class]
                                 swizzlePrefix:@"swizzled_"
                             swizzledSelectors:
         @selector(swizzled_accessibilityPostNotification:withNotificationElement:),
         @selector(swizzled_accessibilityPostNotification:),
         nil];
    });
}

- (void *)swizzled_accessibilityPostNotification:(NSAccessibilityNotificationName)notificationName {
    /// Notes:
    /// - This is invoked by NSTextView, when the text selection or text value changes
    void *result = (void *)[self swizzled_accessibilityPostNotification:notificationName];
    [UIStringChangeInterceptor onNotification:notificationName postedBy:self context:NULL element:NULL result:result];
    return result;
}

- (void *)swizzled_accessibilityPostNotification:(NSAccessibilityNotificationName)notificationName withNotificationElement:(id)element {
    /// Notes:
    /// - This seems to be called by `swizzled_accessibilityPostNotification:`
    void *result = (void *)[self swizzled_accessibilityPostNotification:notificationName withNotificationElement:element];
    [UIStringChangeInterceptor onNotification:notificationName postedBy:self context:NULL element:element result:result];
    return result;
}

@end

/// Intercept NSControl

@implementation NSControl (MFUIStringInterception)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [Swizzle swizzleMethodsOnClass:[self class] swizzlePrefix:@"swizzled_" swizzledSelectors:@selector(swizzled_accessibilityPostNotification:context:), nil];
    });
}

- (void *)swizzled_accessibilityPostNotification:(NSAccessibilityNotificationName)notificationName context:(id)context {
    assert(false); /// Untested, see if this works
    void *result = (void *)[self swizzled_accessibilityPostNotification:notificationName context:context];
    [UIStringChangeInterceptor onNotification:notificationName postedBy:self context:context element:NULL result:result];
    return result;
}

@end

/// Intercept NSWindow

@implementation NSWindow (MFUIStringInterception)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [Swizzle swizzleMethodsOnClass:[self class] swizzlePrefix:@"swizzled_" swizzledSelectors:@selector(swizzled_accessibilityPostNotification:), nil];
    });
}

- (void *)swizzled_accessibilityPostNotification:(NSAccessibilityNotificationName)notificationName {
    /// Notes:
    /// - This is invoked when the window title changes
    void *result = (void *)[self swizzled_accessibilityPostNotification:notificationName];
    [UIStringChangeInterceptor onNotification:notificationName postedBy:self result:result];
    return result;
}

@end

/// Intercept NSMenu

@implementation NSMenu (MFUIStringInterception)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [Swizzle swizzleMethodsOnClass:[self class] swizzlePrefix:@"swizzled_" swizzledSelectors:@selector(swizzled_postAccessibilityNotification:), nil];
    });
}

- (void *)swizzled_postAccessibilityNotification:(NSAccessibilityNotificationName)notificationName {
    /// Notes:
    /// - This is called by NSMenu when it opens, closes, selection changes. Perhaps also when the menu title changes or sth but I haven't tested that.
    void *result = (void *)[self swizzled_postAccessibilityNotification:notificationName];
    [UIStringChangeInterceptor onNotification:notificationName postedBy:self result:result];
    return result;
}

@end

/// Intercept NSSecureTextView

/// This is private so we have to declare the interface it first


@interface NSSecureTextView : NSView /// Not sure what the superclass is
@end

@implementation NSSecureTextView (MFUIStringInterception)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [Swizzle swizzleMethodsOnClass:[self class] swizzlePrefix:@"swizzled_" swizzledSelectors:@selector(swizzled_accessibilityPostNotification:), nil];
    });
}

- (void *)swizzled_accessibilityPostNotification:(NSAccessibilityNotificationName)notificationName {
    assert(false); /// Untested, see if this works
    void *result = (void *)[self swizzled_accessibilityPostNotification:notificationName];
    [UIStringChangeInterceptor onNotification:notificationName postedBy:self result:result];
    return result;
}


@end

///
/// ------------------------------------------------------------------------------------
///

#if FALSE

///
/// Old stuff
///

/// We tried to swizzle methods such as `setAccessibilityTitle:` but they are not consistently called when the title changes.
///

@implementation NSTextField (MFUIStringInterception)

///
/// Swizzle
///

+ (void)load {
    

    
    
    swizzleMethod([self class], @selector(setAccessibilityTitle:), @selector(swizzled_setAccessibilityTitle:));
    swizzleMethod([self class], @selector(setAccessibilityLabel:), @selector(swizzled_setAccessibilityLabel:));
    swizzleMethod([self class], @selector(setAccessibilityValue:), @selector(swizzled_setAccessibilityValue:));
}

- (void)swizzled_setAccessibilityTitle:(NSString *)accessibilityTitle {
    [self swizzled_setAccessibilityTitle:accessibilityTitle];
    [self publishLocalizationKeys];
}

- (void)swizzled_setAccessibilityLabel:(NSString *)accessibilityLabel {
    [self swizzled_setAccessibilityLabel:accessibilityLabel];
    [self publishLocalizationKeys];
}

- (void)swizzled_setAccessibilityValue:(id)accessibilityValue {
    [self swizzled_setAccessibilityValue:accessibilityValue];
    [self publishLocalizationKeys];
}

/// Publish

- (void)publishLocalizationKeys {
    NSArray *allTheKeys = [LocalizationKeyState.queue dequeueAll];
    NSLog(@"All the keys: %@", allTheKeys);
}


@end

#endif
