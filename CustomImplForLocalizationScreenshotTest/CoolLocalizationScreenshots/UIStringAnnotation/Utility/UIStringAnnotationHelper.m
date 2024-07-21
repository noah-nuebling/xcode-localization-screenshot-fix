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
#import "objc/runtime.h"
#import "AppKitIntrospection.h"

@implementation UIStringAnnotationHelper

///
/// Definitions
///

//+ (NSDictionary <NSAccessibilityAttributeName, NSString *>*)AXUIStringAttributeToSelectorMap {
//    
//    /// This maps' keys declare all the AXAttributes that hold UIStrings. The values are the selectors for retrieving the respective attribute from an `NSObject<Accessibility>`
//    ///     We can't really use this since compiler complains when we try to use these selectors.
//    ///     I guess we can use `getUIStringsFromAccessibilityElement:` instead
//    
//    assert(false);
//    
//    NSDictionary *map = @{
//        NSAccessibilityValueAttribute: NSStringFromSelector(@selector(accessibilityValue)),
//        NSAccessibilityTitleAttribute: NSStringFromSelector(@selector(accessibilityTitle)),
//        NSAccessibilityPlaceholderValueAttribute: NSStringFromSelector(@selector(accessibilityPlaceholderValue)),
//        NSAccessibilityHelpAttribute: NSStringFromSelector(@selector(accessibilityHelp)),
//    };
//    
//    return map;
//}

//+ (NSAccessibilityAttributeName _Nullable)getAttributeForAccessibilityNotification:(NSAccessibilityNotificationName)notification {
//    
//    NSDictionary *map = @{
//        NSAccessibilityValueChangedNotification: NSAccessibilityValueAttribute,
//        NSAccessibilityTitleChangedNotification: NSAccessibilityTitleAttribute,
//    };
//    NSAccessibilityAttributeName result = map[notification];
//    return result;
//}

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
    
    /// Determine whether this was called for code annotation or nib annotation
    BOOL isCodeAnnotation = translatedStringNibKey == nil;
    if (!isCodeAnnotation) {
        assert(mergedUIString == nil);
    }
    
    /// Create & init element
    NSAccessibilityElement *element = [[NSAccessibilityElement alloc] init];
    [element setAccessibilityEnabled:YES/*NO*/];
    [element setAccessibilityRole:isCodeAnnotation ? @"MFCodeLocalizationKeyRole" : @"MFNibLocalizationKeyRole"];
    
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
    [self _addAnnotations:annotations toAccessibilityElement:object forceValidation:NO additionalUIStringHolder:nil];
}
+ (void)addAnnotations:(NSArray<NSAccessibilityElement *>*)annotations toAccessibilityElement:(NSObject<NSAccessibility>*)object withAdditionalUIStringHolder:(NSObject *)additionalUIStringHolder {
    [self _addAnnotations:annotations toAccessibilityElement:object forceValidation:NO additionalUIStringHolder:additionalUIStringHolder];
}


+ (void)_addAnnotations:(NSArray<NSAccessibilityElement *>*)annotations toAccessibilityElement:(NSObject<NSAccessibility>*)element forceValidation:(BOOL)forceValidation additionalUIStringHolder:(NSObject *_Nullable)additionalUIStringHolder {
    
    /// Reusable annotations adder & validator
    ///     Note: We used to try to set the stringKeys as an attribute instead of in child elements. But we can't find unused attributes, and the new AX API won't let you set values for custom keys I think. We also tried using the private NSAccessibilitySetObjectValueForAttribute but it also doesn't let you set completely custom attributes.
    
    /// Validate
    assert([element isAccessibilityElement]);
    
    /// Set new parent on children
    for (NSAccessibilityElement *annotation in annotations) {
        [annotation setAccessibilityParent:element];
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
            
            /// Main Check - accessibilityElement
            annotationMatchesObject = [self annotationElement:annotation describesSomeUIStringOnAccessibilityElement:element additionalUIStringHolder:additionalUIStringHolder];
            
            /// Fallback check - `_menuItemsRenamedBySystem`
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
                    
                    unpackLocalizedStringRecord(record);
                    
                    if ([self accessibilityElement:element containsUIString:m_localizedStringFromRecord] && m_localizedStringFromRecord.length > 0) {
                        uiStringWasProbablyOverridenBySystem = YES;
                    }
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
            NSLog(@"UIStringAnnotation: Error: Annotation %@ describes a uiString that was not found on the object %@ which we wanted to attach the annotation to\n(uiStrings found on object: %@)\n. There might be a bug in the code. Sometimes this also happens because the uiString that the annotation describes isn't settable on the object.",
                  annotationDescription(annotation), element, getUIStringsFromAXElement(element));
            assert(false);
        }
    }
    
    /// Get old children
    NSMutableArray *children = [element accessibilityChildren/*InNavigationOrder*/].mutableCopy; /// Not sure whether to use `InNavigationOrder`
    if (children == nil) {
        children = [NSMutableArray array];
    }
    
    ///Combine children
    [children addObjectsFromArray:annotations];
    
    /// Set children
    [element setAccessibilityChildren/*InNavigationOrder*/:children.copy]; /// Not sure .copy is useful or necessary
};


#pragma mark - Extract UI Srings

NSDictionary<NSString *, NSString *> *getUIStringsFromAdditionalUIStringHolder(NSObject *uiStringHolder) {
    
    /// Only use this when necessary and explain why. Use `getUIStringsFromAXElement:` whenever possible.
    ///
    /// Why is it bad to use this?
    ///     In the end we always need to attach our annotations to a specific ax-element. The client code of this class should be finding the AX elements they want ot attach an annotation to and then the code in here should automatically
    ///     find the uiStrings inside the passed-in ax elements - even if that means traversing related non-ax elements.
    /// Why is it sometimes necessary?
    ///     Sometimes the `ax-Element which represents the UI Element that should be annotated` does not have *any* reference to the object that actually holds the uiString from the annotation. In those cases,
    ///     it's necessary for the client code to pass in a uiString-holder object additionally to the ax-element so that the code in here can validate that the uiStrings from the annotation are present on the uiElement.
    ///     Those special cases are what this method is for. Otherwise we should try to find all the uiStrings on the ax-elements to keep things clean for the client code.
    
    /// Validate input
    if ([uiStringHolder respondsToSelector:@selector(isAccessibilityElement)] && [(id)uiStringHolder isAccessibilityElement]) {
        assert(false);
    }
    
    /// Declare result
    NSDictionary<NSString *, NSString *> *result = nil;
    
    /// Special: NSTableColumn
    /// Why this is necessary:
    ///     `NSTableHeaderCell`, which is the axElement we want to annotate, doesn't hold any reference to the object which
    ///     the cell is representing ( the `NSTableColumn`), and which holds the tooltip which the annotation contains the localizationKey for.
    ///     Usually, `NSCell` instances hold a reference to the object that they are representing through the `controlView` property, but that doesn't seem to be the case for
    ///     `NSTableHeaderCell`. That's why this code gets the uiStrings directly from the `NSTableColumn`.

    if ([uiStringHolder isKindOfClass:[NSTableColumn class]]) {
        NSTableColumn *column = (id)uiStringHolder;
        result = @{
            @"headerToolTip": column.headerToolTip,
            @"title": column.title,
        };
    }
    
    assert(result != nil);
    return result;
}

NSDictionary<NSString *, NSString *> *getUIStringsFromAXElement(NSObject<NSAccessibility> *element) {
    
    /// Note that the returned uiStrings are purely NSStrings (not NSAttributedStrings) (and also NSNull.null instances)
    ///     We don't care about the attributes in this class.
    
    /// Validate
    assert([element isAccessibilityElement]);
    
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
    
    NSMutableDictionary<NSString *, NSString *> *result = @{
        
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
    
    /// Special case: NSSegmentedCell
    ///     The segmented cell holds labels and tooltips for each of its segments.
    ///     The segmented cell has and accessibilityChild "mock element" for each of its segments. It would be better to attach out annotation directly to those.
    ///     (which would render this code here obsolete) But it doesn't matter that much.
    if ([element isKindOfClass:[NSSegmentedCell class]]) {
        NSInteger segmentCount = [(NSSegmentedCell *)element segmentCount];
        for (int i = 0; i < segmentCount; i++) {
            NSString *label = [(NSSegmentedCell *)element labelForSegment:i];
            NSString *toolTip = [(NSSegmentedCell *)element toolTipForSegment:i];
            result[stringf(@"segment.%d.label", i)] = label;
            result[stringf(@"segment.%d.toolTip", i)] = toolTip;
        }
    }
    
    /// Special case: NSToolbarItemViewer
    if ([element isKindOfClass:objc_getClass("NSToolbarItemViewer")]) { /// NSToolbarItem's ax representatives are NSToolbarItemViewer instances. But for FlexibleSpaceItem, the itemViewer is not an axElement.
        NSToolbarItem *item = [(NSToolbarItemViewer *)element item];
        result[@"label"] = item.label;
        result[@"paletteLabel"] = item.paletteLabel;
        result[@"toolTip"] = item.toolTip;
    }
    
    /// Special case: alternate title
    ///     The alternateTitle is only present on NSButton. I think it's not stored in any ax attribute but not totally sure.
    if ([element respondsToSelector:@selector(alternateTitle)]) {
        result[@"alternateTitle"] = [(id)element alternateTitle];
        result[@"title"] = [(id)element title]; /// Also fetch the 'title' for good measure. Not sure this is necessary. But perhaps this won't be present as an ax attribute if the alternateTitle is currently displayed in the UI. 
    }
    
    /// Cleanup and validation
    for (id key in result.allKeys) {
        
        id value = result[key];
        
        /// Strip out NSNull
        ///     We need to use NSNull in the dict literal, but don't want to return it
        BOOL isNSNull = [value isEqual:NSNull.null];
        BOOL isNSString = [value isKindOfClass:[NSString class]];
        
        if (isNSNull) {
            [result removeObjectForKey:key];
        } else if (!isNSString) {
            assert([key isEqual:NSAccessibilityValueAttribute]);
            result[key] = [value description]; /// Convert value attribute to string instead of deleting it. It's very unlikely to contain a UI String, but this should help with debugging.
        }
    }
    
    /// Return
    return result;
}

+ (BOOL)additionalUIStringHolder:(NSObject *)object containsUIString:(NSString *)uiString {
    
    /// Use `accessibilityElement:containsUIString:` whenever possible. See getUIStringsFromNonAXElement() for discussion.
    
    /// Validate input
    assert(uiString.length > 0);
    if ([object respondsToSelector:@selector(isAccessibilityElement)] && [(id)object isAccessibilityElement]) {
        assert(false);
    }
    
    /// Main logic
    BOOL objectContainsUIString = NO;
    NSDictionary *uiStringsFromObject = uiStringsFromObject = getUIStringsFromAdditionalUIStringHolder(object);
    for (id uiStringFromObjectttt in uiStringsFromObject.allValues) {
        NSString *uiStringFromObject = pureString(uiStringFromObjectttt);
        if ([uiStringFromObject isEqual:uiString] && uiStringFromObject.length > 0) {
            objectContainsUIString = YES;
            break;
        }
    }
    
    return objectContainsUIString;
}

+ (BOOL)accessibilityElement:(NSObject<NSAccessibility> *)object containsUIString:(NSString *)uiString {
    
    /// Validate input
    assert(uiString.length > 0);
    assert([object isAccessibilityElement]);
    
    /// Main logic
    BOOL objectContainsUIString = NO;
    NSDictionary *uiStringsFromObject = uiStringsFromObject = getUIStringsFromAXElement(object);
    for (NSAccessibilityAttributeName attributeName in uiStringsFromObject.allKeys) {
        NSString *uiStringFromObject = pureString(uiStringsFromObject[attributeName]);
        if ([uiStringFromObject isEqual:uiString] && uiStringFromObject.length > 0) {
            objectContainsUIString = YES;
            break;
        }
    }
    
    ///
    /// Special cases
    ///
    
    /// Shouldn't we put these special cases into `getUserFacingStringsFromAccessibilityElement:` instead?
    
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
    
    if (!objectContainsUIString) {
        
        /// Special case: NSTabView
        /// Explanation:
        ///     We can't find any axElement that represents the tabViewItem's directly
        ///         (Also see notes on that inside `getRepresentingAccessibilityElementForObject:`)
        ///     That's why we pretend that the tabView holds the tabViewItem's strings, so that our validation code allows us to attach
        ///     the annotations for the item directly to the tabView. Maybe we should use `forceValidation_` instead of this.
        
        if ([object isKindOfClass:[NSTabView class]]) {
            NSTabView *tabView = (id)object;
            for (NSTabViewItem *item in tabView.tabViewItems) {
                BOOL uiStringIsLabel = [[item label] isEqual:uiString];
                BOOL uiStringIsToolTip = [[item toolTip] isEqual:uiString];
                objectContainsUIString = uiStringIsLabel || uiStringIsToolTip;
                if (objectContainsUIString) break;
            }
        }
    }
    
    if (NO && !objectContainsUIString) {
        
        /// In this code we tried to check the `accessibilityTitleUIElement` property to find the uiString, but this doesn't seem to be necessary anymore with the other special-case-code we've implemented here and in geUIStringsFromAccessibilityElement
        
        NSObject<NSAccessibility>*titleUIElement = [(id)object accessibilityTitleUIElement];
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

+ (BOOL)annotationElement:(NSAccessibilityElement *)element describesSomeUIStringOnAccessibilityElement:(NSObject <NSAccessibility>*)object additionalUIStringHolder:(NSObject *_Nullable)additionalUIStringHolder {
    
    /// Validate input
    assert([object isAccessibilityElement]);
    
    /// Get uiString from annotation
    NSString * uiStringFromElement = getUIStringFromAnnotation(element);
    
    /// Call core
    BOOL elementDescribesObject = [self accessibilityElement:object containsUIString:uiStringFromElement];
    if (!elementDescribesObject && additionalUIStringHolder != nil) {
        elementDescribesObject = [self additionalUIStringHolder:additionalUIStringHolder containsUIString:uiStringFromElement];
    }
    
    /// Return
    return elementDescribesObject;
}

NSString *getUIStringFromAnnotation(NSAccessibilityElement *element) {
    NSDictionary *elementData = [element accessibilityValue];
    NSString *uiStringFromElement = elementData[@"mergedUIString"];
    if (uiStringFromElement == nil || [uiStringFromElement isEqual:[NSNull null]] || uiStringFromElement.length == 0) {
        uiStringFromElement = elementData[@"string"];
    }
    return uiStringFromElement;
}
NSString *annotationDescription(NSAccessibilityElement *element) {
    NSDictionary *elementData = [element accessibilityValue];
    return [elementData description];
}

@end
