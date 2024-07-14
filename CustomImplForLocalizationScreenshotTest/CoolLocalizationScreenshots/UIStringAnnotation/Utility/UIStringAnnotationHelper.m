//
//  UIStringAnnotationHelper.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 10.07.24.
//

///
/// This class defines helper functions for annotating an NSObject with the localizedStringKey(s) for the UIString inside that NSObject.
///
/// These annotations are made through the Accessibility API, so then our XCUI tests can also see these annotations.
/// (-> and use them to find the location of where a certain localizedStringKey is used inside a screenshot of the UI. This information
/// will then be displayed to human translators, providing them with context.)
///

#import "UIStringAnnotationHelper.h"
#import "UINibDecoderIntrospection.h"
#import "NSLocalizedStringRecord.h"
#import "Utility.h"
#import "NSString+Additions.h"

@implementation UIStringAnnotationHelper

///
/// Definitions
///

+ (NSDictionary <NSAccessibilityAttributeName, NSString *>*)AXUIStringAttributeToSelectorMap {
    
    /// This maps' keys declare all the AXAttributes that hold UIStrings. The values are the selectors for retrieving the respective attribute from an `NSObject<Accessibility>`
    ///     We can't really use this since compiler complains when we try to use these selectors.
    ///     I guess we can use `getUIStringsFromAccessibilityElement:` instead
    
    assert(false);
    
    NSDictionary *map = @{
        NSAccessibilityValueAttribute: NSStringFromSelector(@selector(accessibilityValue)),
        NSAccessibilityTitleAttribute: NSStringFromSelector(@selector(accessibilityTitle)),
        NSAccessibilityPlaceholderValueAttribute: NSStringFromSelector(@selector(accessibilityPlaceholderValue)),
        NSAccessibilityHelpAttribute: NSStringFromSelector(@selector(accessibilityHelp)),
    };
    
    return map;
}


+ (NSArray *)allUserFacingStringAttributes {
    assert(false);
    return [self getUserFacingStringsFromAccessibilityElement:[[NSView alloc] init]].allKeys;
}

+ (NSDictionary *)getUserFacingStringsFromAccessibilityElement:(NSObject<NSAccessibility> *)element {
    
    /// Validate
    assert([element isAccessibilityElement]);
    
    /// TEST
    if ([element isKindOfClass:[NSTableHeaderCell class]]) {
        
    }
    
    /// Special case: tooltip
    /// Explanation:
    ///     Tooltips are usually published through the AX API under the NSAccessibilityHelpAttribute, but not always. E.g. on NSMenuItem's
    ///     the NSAccessibilityHelpAttribute is not set to the tooltip for some reason (macOS 15.0 Beta 2). Also when you manually set the
    ///     NSAccessibilityHelpAttribute in IB it will differ from the tooltip.
    ///     Since tooltips aren't consistently available through the AX API, we need to get tooltips directly from the object instead.
    
    NSObject *toolTipHolder = [Utility getRepresentingToolTipHolderForObject:element];
    
    NSString *toolTip = nil;
    if ([toolTipHolder respondsToSelector:@selector(toolTip)]) {
        toolTip = [(id)toolTipHolder toolTip];
    }
    if (toolTip == nil) {
        if ([toolTipHolder respondsToSelector:@selector(buttonToolTip)]) { /// Not sure what this is but the autocomplete suggests this selector
            toolTip = [(id)toolTipHolder buttonToolTip];
        }
    }
    if (toolTip == nil) {
        if ([toolTipHolder respondsToSelector:@selector(headerToolTip)]) { /// Not sure what this is but the autocomplete suggests this selector
            toolTip = [(id)toolTipHolder headerToolTip];
        }
    }
    
    /// Get values from AX API.
    
    NSMutableDictionary *result = @{
        
        /// Localizable strings that appear visually in the UI
        NSAccessibilityTitleAttribute:                          [element accessibilityTitle] ?: NSNull.null,                        /// Regular UIStrings
        NSAccessibilityValueAttribute:                          [element accessibilityValue] ?: NSNull.null,                        /// Regular UIStrings
        NSAccessibilityPlaceholderValueAttribute:               [element accessibilityPlaceholderValue] ?: NSNull.null,             /// Placeholders
        @"toolTip":                                             toolTip ?: NSNull.null,                                             /// Tooltips
        
        /// HelpAttribute
        ///     Localizable string that usually appears visually in the UI as a tooltip, but not always
        NSAccessibilityHelpAttribute:                           [element accessibilityHelp] ?: NSNull.null,                         /// Voice Over Stuff & Sometimes tooltips
        
        /// Localizable strings that only appear in Assistive Apps like VoiceOver
        ///     (I might have missed some)
        NSAccessibilityDescriptionAttribute:                    [element accessibilityLabel] ?: NSNull.null,                        /// Voice Over Stuff
        NSAccessibilityValueDescriptionAttribute:               [element accessibilityValueDescription] ?: NSNull.null,             /// Voice Over Stuff
        NSAccessibilityRoleDescriptionAttribute:                [element accessibilityRoleDescription] ?: NSNull.null,              /// Voice Over Stuff
        NSAccessibilityHorizontalUnitDescriptionAttribute:      [element accessibilityHorizontalUnitDescription] ?: NSNull.null,    /// Voice Over Stuff
        NSAccessibilityVerticalUnitDescriptionAttribute:        [element accessibilityVerticalUnitDescription] ?: NSNull.null,      /// Voice Over Stuff
        NSAccessibilityMarkerTypeDescriptionAttribute:          [element accessibilityMarkerTypeDescription] ?: NSNull.null,        /// Voice Over Stuff
        NSAccessibilityUnitDescriptionAttribute:                [element accessibilityUnitDescription] ?: NSNull.null,              /// Voice Over Stuff
        //        ???:                                                    [element accessibilityUserInputLabels] ?: NSNull.null,              /// Voice Over Stuff
        //        ???:                                                    [element accessibilityAttributedUserInputLabels] ?: NSNull.null,    /// Voice Over Stuff
    }.mutableCopy;
    
    /// Special case: NSSegmentedControl
    ///     The segmented control holds labels and tooltips for each of its segments.
    if ([element isKindOfClass:[NSSegmentedCell class]]) {
        NSInteger segmentCount = [(NSSegmentedCell *)element segmentCount];
        for (int i = 0; i < segmentCount; i++) {
            NSString *label = [(NSSegmentedCell *)element labelForSegment:i];
            NSString *toolTip = [(NSSegmentedCell *)element toolTipForSegment:i];
            result[stringf(@"segment.%d.label", i)] = label;
            result[stringf(@"segment.%d.toolTip", i)] = toolTip;
        }
    }   
    
    /// Return
    return result;
}


+ (NSAccessibilityAttributeName _Nullable)getAttributeForAccessibilityNotification:(NSAccessibilityNotificationName)notification {
    
    NSDictionary *map = @{
        NSAccessibilityValueChangedNotification: NSAccessibilityValueAttribute,
        NSAccessibilityTitleChangedNotification: NSAccessibilityTitleAttribute,
    };
    NSAccessibilityAttributeName result = map[notification];
    return result;
}

///
/// Main interface
///

+ (NSAccessibilityElement *)createAnnotationElementWithLocalizationKey:(NSString *_Nonnull)localizationKey
                                                      translatedString:(NSString *_Nonnull)translatedString
                                                     developmentString:(NSString *_Nullable)developmentString
                                                translatedStringNibKey:(NSString *_Nullable)translatedStringNibKey
                                                        mergedUIString:(NSString *_Nullable)mergedUIString {
    
    /// Notes:
    ///     `mergedUIString` explanation:
    ///     The idea is that the `translatedString` is always the string exactly as it was returned by NSLocalizedString(). In simple cases, `translatedString` is *also* exactly equal to the uiString of the accessibilityElement we're annotating. However, in more complex cases, the string that was returned by NSLocalizedString() might be modified or merged with another string before being set as the uiString of an accessibiliy element. In these cases, `mergedUIString` should be set to the uiString exactly as it appears in the uiElement. That way the annotation always contains the UI String exactly as it appears in the element it is annotating. We plan to use this to validate that the annotation actually belongs to the accessibilityElement we're annotating.
    
    /// Reusable AccessibilityElement creator
    
    /// Create & init element
    NSAccessibilityElement *element = [[NSAccessibilityElement alloc] init];
    [element setAccessibilityEnabled:YES/*NO*/];
    [element setAccessibilityRole:@"MFLocalizationKeyRole"];
    
    /// Set value
    [element setAccessibilityValue:@{
        @"key": localizationKey,
        @"string": translatedString,
        @"devString": developmentString ?: NSNull.null,
        @"nibKey": translatedStringNibKey ?: NSNull.null,
        @"mergedUIString": mergedUIString ?: NSNull.null,
    }];
    
    /// Store debug data
    ///     These values will be visible to us in Accessibility Inspector
    ///     We set the `valueDescription` because the actual `value` field will show up as `Empty` in Accessibility Inspector if we set it to a Dictionary.
    ///     If this doesn't work we could also JSON encode the dict.
    
    /// Set label
    NSString *label = [@[localizationKey, translatedString] componentsJoinedByString:@"="];
    [element setAccessibilityLabel:label];
    
    /// Set value description
    NSString *valueDescription = [[[element accessibilityValue] debugDescription] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    [element setAccessibilityValueDescription:valueDescription];
    
    /// Return
    return element;
};


+ (void)extendAnnotationElement:(NSAccessibilityElement *)element withEntriesOfDict:(NSDictionary *)extension {
    
    /// Get
    NSMutableDictionary *dict = [(NSDictionary *)[element accessibilityValue] mutableCopy];
    
    /// Validate
    BOOL overlappingKeys = [[NSSet setWithArray:dict.allKeys] intersectsSet:[NSSet setWithArray:extension.allKeys]];
    assert(!overlappingKeys);
    
    /// Extend
    [dict addEntriesFromDictionary:extension];
    
    /// Set value
    [element setAccessibilityValue:dict];
    
    /// Set value description
    NSString *valueDescription = [[[element accessibilityValue] debugDescription] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    [element setAccessibilityValueDescription:valueDescription];
    
}

+ (void)addAnnotations:(NSArray<NSAccessibilityElement *>*)annotations toAccessibilityElement:(NSObject<NSAccessibility>*)object {
    [self _addAnnotations:annotations toAccessibilityElement:object forceValidation:NO];
}
+ (void)forceValidation_addAnnotations:(NSArray<NSAccessibilityElement *>*)annotations toAccessibilityElement:(NSObject<NSAccessibility>*)object {
    [self _addAnnotations:annotations toAccessibilityElement:object forceValidation:YES];
}

+ (void)_addAnnotations:(NSArray<NSAccessibilityElement *>*)annotations toAccessibilityElement:(NSObject<NSAccessibility>*)object forceValidation:(BOOL)forceValidation {
    
    /// Reusable annotations adder & validator
    ///     Note: We used to try to set the stringKeys as an attribute instead of in child elements. But we can't find unused attributes, and the new AX API won't let you set values for custom keys I think. We also tried using the private NSAccessibilitySetObjectValueForAttribute but it also doesn't let you set completely custom attributes.
    
    /// Validate
    assert([object isAccessibilityElement]);
    
    /// Set new parent on children
    for (NSAccessibilityElement *annotation in annotations) {
        [annotation setAccessibilityParent:object];
    }
    
    /// Validation
    for (NSAccessibilityElement *annotation in annotations) {
        
        /// Declare result
        BOOL annotationMatchesObject = NO;
        __block BOOL uiStringWasProbablyOverridenBySystem = NO;
        
        if (forceValidation) {
            /// Force validation
            annotationMatchesObject = YES;
        } else {
            
            /// Main Check
            annotationMatchesObject = [self annotationElement:annotation describesSomeUIStringOnAccessibilityElement:object];
            
            /// Fallback check
            if (!annotationMatchesObject) {
                
                /// Explanation:
                ///     It seems that when AppKit decodes an Nib file, some of the menu items are first set to localizedStrings from the stringTables defined
                ///     by our app, but then after the Nib file has been loaded, when a menuItem is accessed for the first time, the uiString for the menuItem is
                ///     automatically overriden by AppKit - with a value that comes from an Apple-defined string table.
                ///     For example, the "Show Spelling and Grammar" menu item is automatically
                ///     translated to "Rechtschreibung und Grammatik einblenden", and this translation comes from the Apple-defined `MenuCommands` stringTable.
                ///     For these cases, our normal validation logic won't work, so we make an exception here: when an item doesn't validate normally
                ///     (annotationMatchesObject is false) then we check if the NSLocalizedStringRecord has recorded any string retrievals from system-defined stringTables,
                ///     where the retrieved UI string matches any uiString of the object we're inspecting right now. If yes, then we let this annotation pass.
                ///
                ///     Update: We now added `_menuItemsRenamedBySystem` which could replace this validation logic, and probably make NSLocalizedStringRecord.systemSet
                ///     and NSLocalizedStringRecord.systemQueue obsolete (We introduced those for this specific validation code)
                
                
                for (NSDictionary *record in NSLocalizedStringRecord.systemSet) {
                    [NSLocalizedStringRecord unpackRecord:record callback:^(NSString * _Nonnull key, NSString * _Nonnull value, NSString * _Nonnull table, NSString * _Nonnull retrievedSystemString) {
                        if ([self accessibilityElement:object containsUIString:retrievedSystemString] && retrievedSystemString.length > 0) {
                            uiStringWasProbablyOverridenBySystem = YES;
                        }
                    }];
                    if (uiStringWasProbablyOverridenBySystem) {
                        
                        /// Extend annotation
                        [self extendAnnotationElement:annotation withEntriesOfDict:@{
                            @"probablyOverridenBySystemString": record,
                        }];
                        
                        /// Break
                        break;
                    }
                }
            }
        }
        
        /// Validate
        BOOL isValid = annotationMatchesObject || uiStringWasProbablyOverridenBySystem;
        if (!isValid) {
            NSLog(@"UIStringAnnotation: Error: Annotation %@ describes a uiString that was not found on the object we wanted to attach it to (uiStrings found on object: %@). There might be a bug in the code. Sometimes this also happens because the uiString that the annotation describes isn't settable on the object.",
                  [UIStringAnnotationHelper annotationDescription:annotation], [UIStringAnnotationHelper getUserFacingStringsFromAccessibilityElement:object]);
            assert(false);
        }
    }
    
    /// Get old children
    NSMutableArray *children = [object accessibilityChildren/*InNavigationOrder*/].mutableCopy; /// Not sure whether to use `InNavigationOrder`
    if (children == nil) {
        children = [NSMutableArray array];
    }
    
    ///Combine children
    [children addObjectsFromArray:annotations];
    
    /// Set children
    [object setAccessibilityChildren/*InNavigationOrder*/:children.copy]; /// Not sure .copy is useful or necessary
};


///
/// Validation
///

+ (BOOL)accessibilityElement:(NSObject<NSAccessibility> *)object containsUIString:(NSString *)uiString {
    
    /// Validate input
    assert(uiString.length > 0);
    
    /// Main logic
    BOOL objectContainsUIString = NO;
    
    NSDictionary *uiStringsFromObject = [self getUserFacingStringsFromAccessibilityElement:object];
    for (NSAccessibilityAttributeName attributeName in uiStringsFromObject.allKeys) {
        NSString *uiStringFromObject = uiStringsFromObject[attributeName];
        if ([uiStringFromObject isEqual:uiString] && uiStringFromObject.length > 0) {
            objectContainsUIString = YES;
            break;
        }
    }
    
    if (!objectContainsUIString) {
        
        /// Special case: NSMenu
        /// Explanation:
        ///     NSMenus contain a localizable string: their 'title'. however the title is not actually visible in the UI, and also is not published through any accessibility attributes.
        /// Further weirdness:
        ///     NSMenus also link to an `accessibilityTitleUIElement` which seems to be the NSMenuItem which
        ///     opens the menu (if the menu is a submenu) However the title of this NSMenuItem (aka the titleUIElement) can be different than the title of the NSMenu
        ///     itself. So we can't use that to validate the `uiString`. Instead we check the 'title' property of the NSMenu, that seems to work.
        ///     Really, we could probably  be ignoring the menu titles altogether as they seem to be unused, but Xcode does generate localizedStrings for them.
        ///
        
        if ([object isKindOfClass:[NSMenu class]]) {
            BOOL uiStringIsTitle = [[((NSMenu *)object) title] isEqual:uiString];
            objectContainsUIString = uiStringIsTitle;
        }
    }
    
    if (!objectContainsUIString) {
        
        /// Special case: NSWindow titles
        /// Explanation:
        ///     NSWindow have both their `title` and their `subtitle` inside their `AXTitle` attribute. But the `title` and `subtitle` have separate
        ///     localizedStrings. So we check the `title` and `subtitle` properties directly.
        
        if ([object isKindOfClass:[NSWindow class]]) {
            BOOL uiStringIsTitle = [[((NSWindow *)object) title] isEqual:uiString];
            BOOL uiStringIsSubtitle = [[((NSWindow *)object) subtitle] isEqual:uiString];
            objectContainsUIString = uiStringIsTitle || uiStringIsSubtitle;
        }
        
    }
    
    if (NO && !objectContainsUIString) {
        
        /// In this code we tried to check the `accessibilityTitleUIElement` property to find the uiString, but this doesn't seem to be necessary anymore with the other special-case-code we've implemented here and in geUIStringsFromAccessibilityElement
        
        NSObject<NSAccessibility>*titleUIElement = [object accessibilityTitleUIElement];
        if (titleUIElement != nil) {
            if ([titleUIElement isKindOfClass:[NSAccessibilityProxy class]]) {
                titleUIElement = [(NSAccessibilityProxy *)titleUIElement realElement];
            }
            objectContainsUIString = [self accessibilityElement:titleUIElement containsUIString:uiString];
        }
    }
    
    /// Return
    return objectContainsUIString;
}

+ (BOOL)annotationElement:(NSAccessibilityElement *)element describesSomeUIStringOnAccessibilityElement:(NSObject <NSAccessibility>*)object {
    
    /// Validate input
    assert([object isAccessibilityElement]);
    
    /// Get uiString from element
    NSString * uiStringFromElement = [self getUIStringFromAnnotation:element];
    
    /// Call core
    BOOL elementDescribesObject = [self accessibilityElement:object containsUIString:uiStringFromElement];
    
    /// Return
    return elementDescribesObject;
}

///
/// Element handlers
///


+ (NSString *)getUIStringFromAnnotation:(NSAccessibilityElement *)element {
    NSDictionary *elementData = [element accessibilityValue];
    NSString *uiStringFromElement = elementData[@"mergedUIString"];
    if (uiStringFromElement == nil || [uiStringFromElement isEqual:[NSNull null]] || uiStringFromElement.length == 0) {
        uiStringFromElement = elementData[@"string"];
    }
    return uiStringFromElement;
}
+ (NSString *)annotationDescription:(NSAccessibilityElement *)element {
    NSDictionary *elementData = [element accessibilityValue];
    return [elementData description];
}

@end
