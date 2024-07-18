//
//  NSObject+LocalizationKeyAnnotations.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 09.07.24.
//

#import "UIStringChangeDetector.h"
#import "Swizzle.h"
#import "NSLocalizedStringRecord.h"
#import "UIStringAnnotationHelper.h"
#import "UINibDecoder+LocalizationKeyAnnotation.h"
#import "NSString+Additions.h"
#import "SystemRenameTracker.h"
#import "AppKitIntrospection.h"
#import "Utility.h"
#import "NSString+Additions.h"
#import "objc/runtime.h"

@interface UIStringChangeInterceptor : NSObject
@end

@implementation UIStringChangeInterceptor

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

#pragma mark - Idea: Swizzle setters

/**
 
 Placeholder setters from lldb:
    (I found these by using `breakpoint set -n setPlaceholderString:` and `breakpoint set -n setPlaceholderAttributedString:`
    and then seeing where lldb put the breakpoints in the Breakpoints Navigator.)
 
 ```
 Cells:
 -[NSTextFieldCell setPlaceholderString:]
 -[NSTextFieldCell setPlaceholderAttributedString:]
 -[NSFormCell setPlaceholderString:]
 -[NSFormCell setPlaceholderAttributedString:]
 -[NSPathCell setPlaceholderString:]
 -[NSPathCell setPlaceholderAttributedString:]
 
 NSTextView:
 -[NSTextView(NSPrivate) setPlaceholderString:]
 -[NSTextView (NSPrivate) setPlaceholderAttributedString:]
 
 Cell-backed views:
 -[NSTextField setPlaceholderString:]
 -[NSTextField setPlaceholderAttributedString:]
 -[NSPathControl setPlaceholderString:]
 -[NSPathControl setPlaceholderAttributedString:]
 
 Private stuff for specific apps:
 -[ABCollectionViewltem setPlaceholderString:]
 -[NSSearchToolbarltem(NSSearchToolbarPrivateForNews) setPlaceholderString]
 ```
 
 ToolTip setters from lldb:
    (Found these with `breakpoint set -n setPlaceholderString:` and `image lookup --regex --name ".*[Ss]et.*[Tt]ool[Tt]ip.*" -- AppKit`
 
 ```

 NSObject subclasses:
 -[NSMenuItem setToolTip:]
 -[NSStatusItem setToolTip:]
 -[NSWindowTab setToolTip:]
 -[NSTabBarItem setToolTip:]
 -[NSTabViewItem setToolTip:]
 -[NSToolbarItem setToolTip:] 
 -[NSSegmentItem setToolTip:] x redundant due to `NSSegmentItemLabelCell`
 
 NSView:
 -[NSView setToolTip:]
 
 NSView subclasses:
 -[NSTableView setToolTip:]
 -[NSTabButton setToolTip:]
 
 Special names:

 -[NSTableColumn setHeaderToolTip:]
 -[NSSegmentedControl setToolTip:forSegment:]
 -[NSSegmentedCell setToolTip:forSegment:]      /// Strange that there's a tooltip setter for a cell
 -[NSSegmentItem setToolTipTag:]                /// This is probably not a string
 
 Apple Internal stuff:
 -[NSSuggestionItem setToolTip:]
 
 Special names (Apple Internal stuff):
 -[QLControlSegment setToolTip:]
 -[NSRolloverButton setToolTipString:]
 -[NSRolloverButton setAlternateToolTipString:]
 -[NSToolTipPanel setToolTipString:]
 
 Legacy stuff:
 -[NSMatrix setToolTip:forCell:]
 
 ```
 
 */

@implementation NSButton (MFUIStringChangeDetection)

@end

@implementation NSObject (MFUIStringChangeDetection)


+ (void)uiStringHasChangedFrom:(id)oldValue toValue:(id)newValue onObject:(id)object selector:(SEL)selector recursionDepth:(NSInteger)recursionDepth {
    
    BOOL isString = newValue == nil || [newValue isKindOfClass:[NSString class]] || [newValue isKindOfClass:[NSAttributedString class]];
    
    if (!isString) {
        NSLog(@"    UIStringChangeDetector: New value %@ is not a string", newValue);
        return;
    }
    
    oldValue = pureString(oldValue);
    newValue = pureString(newValue);

    if (MFIsLoadingNib() || MFSystemIsChangingUIStrings()) {
        
    } else {
        
        if (oldValue != newValue && ![oldValue isEqual:newValue]) {
            if (recursionDepth == 0) {
                NSLog(@"    UIStringChangeDetector: [%s \"%@\"] (recursionDepth %ld) (on %@)", sel_getName(selector), newValue, (long)recursionDepth, object);
            } else {
                
            }
                
        }
        
    }
}

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([NSObject class], @"AppKit", @selector(setToolTip:), MakeInterceptorFactory(void, (NSString *newValue), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            OGImpl(newValue);
            [UIStringChangeInterceptor uiStringHasChangedFrom:nil toValue:newValue onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
    swizzleMethodOnClassAndSubclasses([NSObject class], @"AppKit", @selector(setStringValue:), MakeInterceptorFactory(void, (NSString *newValue), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            OGImpl(newValue);
            [UIStringChangeInterceptor uiStringHasChangedFrom:nil toValue:newValue onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
    swizzleMethodOnClassAndSubclasses([NSObject class], @"AppKit", @selector(setAttributedStringValue:), MakeInterceptorFactory(void, (NSAttributedString *newValue), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            OGImpl(newValue);
            [UIStringChangeInterceptor uiStringHasChangedFrom:nil toValue:newValue onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
//    swizzleMethodOnClassAndSubclasses([NSObject class], @"AppKit", @selector(setObjectValue:), MakeInterceptorFactory(void, (, NSObject *newValue), {
//        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
//            OGImpl(, newValue);
//            [UIStringChangeInterceptor uiStringHasChangedFrom:nil toValue:newValue onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
//        });
//    }));
    swizzleMethodOnClassAndSubclasses([NSObject class], @"AppKit", @selector(setPlaceholderString:), MakeInterceptorFactory(void, (NSString *newValue), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            OGImpl(newValue);
            [UIStringChangeInterceptor uiStringHasChangedFrom:nil toValue:newValue onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
    swizzleMethodOnClassAndSubclasses([NSObject class], @"AppKit", @selector(setPlaceholderAttributedString:), MakeInterceptorFactory(void, (NSAttributedString *newValue), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            OGImpl(newValue);
            [UIStringChangeInterceptor uiStringHasChangedFrom:nil toValue:newValue onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
    swizzleMethodOnClassAndSubclasses([NSObject class], @"AppKit", @selector(setTitle:), MakeInterceptorFactory(void, (NSString *newValue), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            OGImpl(newValue);
            [UIStringChangeInterceptor uiStringHasChangedFrom:nil toValue:newValue onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
    swizzleMethodOnClassAndSubclasses([NSObject class], @"AppKit", @selector(setAttributedTitle:), MakeInterceptorFactory(void, (NSAttributedString *newValue), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            OGImpl(newValue);
            [UIStringChangeInterceptor uiStringHasChangedFrom:nil toValue:newValue onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
    swizzleMethodOnClassAndSubclasses([NSObject class], @"AppKit", @selector(setAlternateTitle:), MakeInterceptorFactory(void, (NSString *newValue), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            OGImpl(newValue);
            [UIStringChangeInterceptor uiStringHasChangedFrom:nil toValue:newValue onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
    swizzleMethodOnClassAndSubclasses([NSObject class], @"AppKit", @selector(setAttributedAlternateTitle:), MakeInterceptorFactory(void, (NSAttributedString *newValue), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            OGImpl(newValue);
            [UIStringChangeInterceptor uiStringHasChangedFrom:nil toValue:newValue onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
}

@end

@implementation NSSegmentedControl (MFUIStringChangeDetection)

+ (void)load {
//    swizzleMethods([self class], true, @"AppKit", @"swizzled_", 
//                   @selector(swizzled_),
//                   nil);
    
    swizzleMethodOnClassAndSubclasses([self class], @"AppKit", @selector(setToolTip:forSegment:), MakeInterceptorFactory(void,  (NSString *newValue, NSInteger segment), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            NSString *before = [m_self toolTipForSegment:segment];
            OGImpl(newValue, segment);
            id after = [m_self toolTipForSegment:segment];
            [UIStringChangeInterceptor uiStringHasChangedFrom:before toValue:after onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
}

- (void)swizzled_setToolTip:(NSString *)newValue forSegment:(NSInteger)segment {
    
}

@end

@implementation NSTableColumn (MFUIStringChangeDetection)

+ (void)load {
    swizzleMethodOnClassAndSubclasses([self class], @"AppKit", @selector(setHeaderToolTip:), MakeInterceptorFactory(void, (NSString *newValue), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            NSString *before = [m_self headerToolTip];
            OGImpl(newValue);
            id after = [m_self headerToolTip];
            [UIStringChangeInterceptor uiStringHasChangedFrom:before toValue:after onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
}

@end

@implementation NSTextView (MFUIStringChangeDetection)

+ (void)load {

    
    swizzleMethodOnClassAndSubclasses([self class], @"AppKit", /*@selector(setPlaceholderString:)*/ /*@selector(setPlaceholderAttributedString:) */ @selector(didChangeText), MakeInterceptorFactory(void, (), {
        countRecursions(@"uiStringChanges", ^(NSInteger recursionDepth) {
            NSAttributedString *before = nil;
            OGImpl();
            NSAttributedString *after = [m_self textStorage];
            [UIStringChangeInterceptor uiStringHasChangedFrom:before toValue:after onObject:m_self selector:m__cmd recursionDepth:recursionDepth];
        });
    }));
}

//- (void)swizzled_setPlaceholderString:(NSString *)newValue {
//    NSString *before = [(id)self placeholderString];
//    [self swizzled_setPlaceholderString:newValue];
//    NSString *after = [(id)self placeholderString];
//    [UIStringChangeInterceptor uiStringHasChangedFrom:before toValue:after onObject:self];
//}
//- (void)swizzled_setPlaceholderAttributedString:(NSAttributedString *)newValue {
//    NSAttributedString *before = [(id)self placeholderAttributedString];
//    [self swizzled_setPlaceholderAttributedString:newValue];
//    NSAttributedString *after = [(id)self placeholderAttributedString];
//    [UIStringChangeInterceptor uiStringHasChangedFrom:before toValue:after onObject:self];
//}

@end

@implementation NSSearchFieldCell (MFUIStringChangeDetection)

+ (void)load {
//    swizzleMethods([self class], false, nil, @"swizzled_", /// We really don't have to be editing subclasses here
//                   @selector(swizzled_setObjectValue:), /// TEST - this should automaticlly be swizzled if we swizzle it on NSCell, but doesn't work currently
//                   nil);
}

//- (void)swizzled_setObjectValue:(id)newValue {
//    NSString *before = [self rawContents];
//    [self swizzled_setObjectValue:newValue];
//    id after = [self rawContents];
//    [UIStringChangeInterceptor uiStringHasChangedFrom:before toValue:after onObject:self];
//}

@end

@implementation NSCell (MFUIStringChangeDetection)

+ (void)load {
    
    
//    swizzleMethods([self class], true, @"AppKit", @"swizzled_",
//                   @selector(swizzled_setObjectValue:),
//                   @selector(swizzled_setAttributedStringValue:),
//                   ni+l);

//    swizzleMethods([self class], true, @"AppKit", @"swizzled_",
//                   @selector(swizzled_setPlaceholderString:),
//                   @selector(swizzled_setPlaceholderAttributedString:), 
//                   nil);
}

//- (void)swizzled_setObjectValue:(id)newValue {
//    NSString *before = [self rawContents];
//    [self swizzled_setObjectValue:newValue];
//    id after = [self rawContents];
//    [UIStringChangeInterceptor uiStringHasChangedFrom:before toValue:after onObject:self];
//}

//- (void)swizzled_setAttributedStringValue:(NSAttributedString *)attributedStringValue {
//    NSString *before = [self rawContents];
//    [self swizzled_setAttributedStringValue:attributedStringValue];
//    id after = [self rawContents];
//    [UIStringChangeInterceptor uiStringHasChangedFrom:before toValue:after onObject:self];
//}

//- (void)swizzled_setPlaceholderString:(NSString *)placeholder {
//    NSString *before = [(id)self placeholderString];
//    [self swizzled_setPlaceholderString:placeholder];
//    NSString *after = [(id)self placeholderString];
//    if ((YES)) { /// When changing the placeholder on an NSTextField, apparently an NSTextView instance also changes its placeholder, so this is redundant
//        [UIStringChangeInterceptor uiStringHasChangedFrom:before toValue:after onObject:self];
//    }
//}
//- (void)swizzled_setPlaceholderAttributedString:(NSAttributedString *)placeholder {
//    NSAttributedString *before = [(id)self placeholderAttributedString];
//    [self swizzled_setPlaceholderAttributedString:placeholder];
//    NSAttributedString *after = [(id)self placeholderAttributedString];
//    if ((YES)) { /// When changing the placeholder on an NSCell, apparently an NSTextView instance also changes its placeholder, so this is redundant
//        [UIStringChangeInterceptor uiStringHasChangedFrom:before toValue:after onObject:self];
//    }
//}

@end



#pragma mark - Idea: Swizzle `accessibilityPostNotification:`
 
///
/// This was a decent idea in principle, but the way that macOS sends the accessibility notifications seemed too buggy and unreliable.
/// So we'll try swizzling setters instead.
/// (Also the NSNotifications are only sent for changes of the main UIStrings anyways (AXTitleChanged and AXValueChanged). Therefore, tooltips, placeholders and more obscure localizable properties such as NSAccessibilityDescriptionAttribute don't have any change notifications anyways and therefore we would have to rely on swizzling setters for those anyways.)
///
/// Here are some problems I saw with the NSAccessibilty Notifications when testing them:
/// - For NSWindowTitle and NSWindowSubtitle, 10 notifications are sent in a row.
/// - For NSCheckbox, NSButton, NSTextView, NSMenuItem title/stringValue changes, the notifications don't seem to be sent at all. (I've definitely seen the NSMenuItem changes produce AXNotifications before but during the last test I ran they didn't)
/// - For NSTextFieldCell the notification seems to be sent before the value actually changed. But for NSSearchFieldCell the notification is sent after the value is changed. The docs say the notifications should be sent after the value is changed.
///


/// Old notes from the top of the file

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

#if FALSE

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
    
    BOOL isNotUIStringChange =
    [notification isEqual:NSAccessibilityResizedNotification]
    || [notification isEqual:NSAccessibilityMovedNotification]
    || [notification isEqual:NSAccessibilityWindowMovedNotification]
    || [notification isEqual:NSAccessibilitySelectedChildrenMovedNotification]
    || [notification isEqual:NSAccessibilityFocusedWindowChangedNotification]
    || [notification isEqual:NSAccessibilityMainWindowChangedNotification]
    || [notification isEqual:NSAccessibilitySelectedTextChangedNotification];
    
    BOOL isUIStringChange = [notification isEqual:NSAccessibilityTitleChangedNotification] || [notification isEqual:NSAccessibilityValueChangedNotification];
    
    if ((YES || isUIStringChange) && !isNotUIStringChange) {
        
        if (MFIsLoadingNib() || MFSystemIsChangingUIStrings()) {
            /// Explanation:
            /// - If we're loading an Nib file, the UINibDecoder code is handling string annotations, and we don't want to annotate ui elements here.
            /// - If the system's menuItemValidation is changing uiStrings, we don't want to annotate that since the UIStrings don't come from our app.
        } else {
            
            /// Get newUIString
            NSAccessibilityAttributeName changedAttribute = [UIStringAnnotationHelper getAttributeForAccessibilityNotification:notification] ?: stringf(@"(unhandled: %@)", notification);
            NSString *newUIString = [UIStringAnnotationHelper getUserFacingStringsFromAccessibilityElement:object]; //changedAttribute ? [UIStringAnnotationHelper getUserFacingStringsFromAccessibilityElement:object][changedAttribute] : NSNull.null;
            
            /// Log
            NSString *logMessage = stringf(@"UIStringChangeInterceptor: %@ changedAttribute: %@ toNewValue: %@", object, changedAttribute, newUIString);
            if (context != 0 || element != 0 || result != 0) {
                logMessage = [logMessage stringByAppendingString:stringf(@" (context: %@, element %@ return: %lld)", context, element, (int64_t)result)];
            }
            if (MFIsLoadingNib()) {
                logMessage = [@"(isDecodingNib) " stringByAppendingString:logMessage];
            }
            if (MFSystemIsChangingUIStrings()) {
                logMessage = [@"(systemIsRenamingUIStrings) " stringByAppendingString:logMessage];
            }
            NSLog(@"%@", logMessage);
            
            /// Publish localization keys on the changed element:
            ///     (aka `annotate` the elements)
            NSArray *records = [self extractBestElementsFromLocalizedStringRecordForObject:object withChangedAttribute:changedAttribute];
            
//            if (records.count > 0) {
//                NSLog(@"UIStringChangeInterceptor: publishing keys: %@ on object: %@", records, object);
//            } else {
//                NSLog(@"UIStringChangeInterceptor: not publishing keys on object: %@ since queue is empty", object);
//            }
        
            for (NSDictionary *r in records) {
                [NSLocalizedStringRecord unpackRecord:r callback:^(NSString * _Nonnull key, NSString * _Nonnull value, NSString * _Nonnull table, NSString * _Nonnull result) {
                    
                    NSAccessibilityElement *annotation = [UIStringAnnotationHelper createAnnotationElementWithLocalizationKey:key translatedString:result developmentString:value translatedStringNibKey:nil mergedUIString:nil];
                    [UIStringAnnotationHelper addAnnotations:@[annotation] toAccessibilityElement:object];
                }];
                
                
            }
        }
        
    }
}

///
/// Intercept NSCell
///

@implementation NSCell (MFUIStringInterception)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzleMethods([self class], true, @"AppKit", @"swizzled_", @selector(swizzled_accessibilityPostNotification:), nil);
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
        
        swizzleMethods([self class], true, @"AppKit", @"swizzled_", 
                       @selector(swizzled_accessibilityPostNotification:withNotificationElement:),
                       @selector(swizzled_accessibilityPostNotification:), nil);
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
        swizzleMethods([self class], true, @"AppKit", @"swizzled_", @selector(swizzled_accessibilityPostNotification:context:), nil);
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

/// Update: Seems like this is not necessary. The title of the window is stored in an nscell

@implementation NSWindow (MFUIStringInterception)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzleMethods([self class], true, @"AppKit", @"swizzled_", @selector(swizzled_accessibilityPostNotification:), nil);
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
        swizzleMethods([self class], true, @"AppKit", @"swizzled_", @selector(swizzled_postAccessibilityNotification:), nil);
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
        swizzleMethods([self class], true, @"AppKit", @"swizzled_", @selector(swizzled_accessibilityPostNotification:), nil);
    });
}

- (void *)swizzled_accessibilityPostNotification:(NSAccessibilityNotificationName)notificationName {
    assert(false); /// Untested, see if this works
    void *result = (void *)[self swizzled_accessibilityPostNotification:notificationName];
    [UIStringChangeInterceptor onNotification:notificationName postedBy:self result:result];
    return result;
}


@end

#endif

///
/// ------------------------------------------------------------------------------------
///

#pragma mark - Idea: Trackable String

#if FALSE

///
/// Trackable string
///

/// Explanation:
/// We tried to swizzle `retain` on `NSString` to see when the NSString is stored on another object. This could replace most of our NibAnnotation and CodeAnnotation logic.
/// However, after bit of testing, I don't think this can be used for UINibDecoder. During decoding I see lots of calls to `swizzled_retain` from  `-[UINibDecoder decodeObjectForKey:]`, but not from any actual objects that the NSString is stored on. I think that -[UINibDecoder decodeObjectForKey:] first retrieves and retains the NSString, and then it stores the NSString on some object, but without calling `retain` again? Maybe it's "transferring the ownership" somehow - meaning that ARC is smart enough to just omit  `release` calls instead of introducing additional `retain` calls.

@implementation NSString (Tracking)

+ (void)load {
    /// Don't compile this in release builds!
    
    if ((NO)) { /// Turn this off as it doesn't seem to work.
        [Swizzle swizzleMethodsOnClass:[self class] swizzlePrefix:@"swizzled_" swizzledSelectors:@selector(swizzled_retain), nil];
    }
}
- (void)setIsTracked:(BOOL)doTrack {
    assert(false);
    const char *key = "MFTrackingStorage_IsTracked";
    objc_setAssociatedObject(self, key, @(doTrack), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)isTracked {
    assert(false);
    const char *key = "MFTrackingStorage_IsTracked";
    NSNumber *isTracked = objc_getAssociatedObject(self, key);
    return [isTracked isEqual:@YES];
}

- (instancetype)swizzled_retain {
    
    if (![self isKindOfClass:[NSString class]]) {
        assert(false);
    }
    
    /// Log
    if ([self isTracked]) {
        NSLog(@"String %@ has been retained", self);
    }
    
    /// Return
    return [self swizzled_retain];
}

@end

#endif

#pragma mark - Idea: Swizzle accessibiliy setters

#if FALSE

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

#pragma mark - Other weird ideas

/// Other weird Ideas:
///

/// 1. Swizzle `NSObject - alloc` for classes that a localized string might be stored on. Then use alloc to keep a list of all object instances, periodically check all instances' ivars for the localized string.
///   -> Not sure if this would be unusably slow, also if we do this, we'd still have to do a lot of swizzling on NSString, MarkdownParser, etc, to retain metadata about localizationKeys when a string is copied or another string is created based on the old string. I don't know how to make this robust.
/// 2. Swizzle retain on NSString to see when localized string is stored on an object (Doesn't work, see below)
/// 3. Use KV-Observation
///   -> I thought KV-Observation might catch stuff on subclasses that our swizzler missed, but now that we added the `includeSubclasses` feature to our swizzling function, I don't think there's any benefit to KV-Observation.
