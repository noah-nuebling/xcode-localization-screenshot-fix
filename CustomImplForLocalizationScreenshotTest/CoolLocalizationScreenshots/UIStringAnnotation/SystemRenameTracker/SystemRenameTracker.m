//
//  SystemRenameTracker.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 14.07.24.
//

#import "SystemRenameTracker.h"
#import "AppKit/AppKit.h"
#import "Utility.h"
#import "objc/runtime.h"

///
/// We record whether the system is currently inside a routine that might set a uiString on a uiElement.
/// The UIStringChangeDetector can then know if it's dealing with a uiString change caused by the system or by the current program by calling `MFSystemIsChangingUIStrings()`.
///
/// Update: This is obsolete now I think, because we can now analyze the address of the uiString-setter-methods' caller to see if the setter was called by a system framework or by the application code.

#pragma mark - RenameDepth definitions

#define MFSystemRenameDepthKey @"MFSystemRenameDepth"

NSInteger MFSystemRenameDepth(void) {
    return [NSThread.currentThread.threadDictionary[MFSystemRenameDepthKey] integerValue];
}
static void MFSystemRenameDepthIncrement(void) {
    NSInteger d = MFSystemRenameDepth() + 1;
    NSThread.currentThread.threadDictionary[MFSystemRenameDepthKey] = @(d);
}
static void MFSystemRenameDepthDecrement(void) {
    NSInteger d = MFSystemRenameDepth() - 1;
    assert(d >= 0);
    NSThread.currentThread.threadDictionary[MFSystemRenameDepthKey] = @(d);
}

BOOL MFSystemIsChangingUIStrings(void) {
    return MFSystemRenameDepth() > 0;
}

#pragma mark - RenamedItems definitions

///
/// See NSApplication swizzling
///

static NSMutableDictionary *_menuItemsRenamedBySystem = nil;
NSMutableDictionary *MFMenuItemsRenamedBySystem(void) {
    return _menuItemsRenamedBySystem;
}


#pragma mark - NSApplication swizzling

///
/// [NSApplication validateMenuItem:] sets some localizedStrings that aren't defined in our app.
///
/// We record these renames in `_menuItemsRenamedBySystem` to validate our localizedString annotations that are based on the Nib file decoding.

@implementation NSApplication (MFNibAnnotation)

+ (void)load {
    
    swizzleMethod([self class], @selector(validateMenuItem:), MakeInterceptorFactory(BOOL, (NSMenuItem *menuItem), {
        
        NSString *beforeTitle = [menuItem title];
        MFSystemRenameDepthIncrement();
        BOOL result = OGImpl(menuItem);
        MFSystemRenameDepthDecrement();
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
        
    }));
}

@end

#pragma mark - NSWindow swizzling

@implementation NSWindow (MFUIStringAnnotation)

+ (void)load {

    swizzleMethodOnClassAndSubclasses([NSWindow class], @{ @"framework": @"AppKit" }, @selector(validateUserInterfaceItem:), MakeInterceptorFactory(BOOL, (id item), {
        MFSystemRenameDepthIncrement();
        BOOL result = OGImpl(item);
        MFSystemRenameDepthDecrement();
        return result;
    }));
}

@end

#pragma mark - NextStepFrame swizzling

@interface NSNextStepFrame : NSView
@end

@implementation NSNextStepFrame (MFUIStringAnnotation)

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([NSNextStepFrame class], @{ @"framework": @"AppKit" }, @selector(_updateTitleProperties:), MakeInterceptorFactory(void, (id inputValue), {
        MFSystemRenameDepthIncrement();
        OGImpl(inputValue);
        MFSystemRenameDepthDecrement();
    }));
}

@end

#pragma mark - TokenFieldCell swizzling

@implementation NSTokenFieldCell (MFUIStringAnnotation)

+ (void)load {

    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(_attributedStringForRepresentedObjects:), MakeInterceptorFactory(id, (id representedObjects), {
        MFSystemRenameDepthIncrement();
        id result = OGImpl(representedObjects);
        MFSystemRenameDepthDecrement();
        return result;
    }));
}

@end

#pragma mark - NSButtonAppearanceBasedVisualProvider swizzling

///
/// [NSButtonAppearanceBasedVisualProvider updateTextFieldIfNecessary] sets some localizedStrings that aren't defined in our app. (For example "Done" or "Fertig")
///

@interface NSButtonAppearanceBasedVisualProvider : NSObject

@end

@implementation NSButtonAppearanceBasedVisualProvider (MFUIStringAnnotation)

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(updateTextFieldIfNecessary), MakeInterceptorFactory(void, (), {
        MFSystemRenameDepthIncrement();
        OGImpl();
        MFSystemRenameDepthDecrement();
    }));
}

@end

#pragma mark - NSTextFieldCell swizzling

///
/// For some reason [NSTextFieldCell -init] seemingly sets the AXValue to "Field" and then to empty string.
///

@implementation NSTextFieldCell (MFUIStringAnnotation)

+ (void)load {
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(init), MakeInterceptorFactory(NSTextFieldCell *, (), {
        MFSystemRenameDepthIncrement();
        NSTextFieldCell *result = OGImpl();
        MFSystemRenameDepthDecrement();
        return result;
    }));
}

@end


#pragma mark - NSTableHeaderView swizzling

///
/// [NSTableHeaderView -_preparedHeaderFillerCell] creates a tableHeaderCell and inits it with empty strings and `AXRoleDescription = "Taste zum Sortieren";`
///

@implementation NSTableHeaderView (MFUIStringAnnotation)

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(_preparedHeaderFillerCell), MakeInterceptorFactory(void *, (), {
        MFSystemRenameDepthIncrement();
        void *result = OGImpl();
        MFSystemRenameDepthDecrement();
        return result;
    }));
}
@end

#pragma mark - NSThemeFrame swizzle

@interface NSFrameView : NSView
@end

@interface NSTitledFrame : NSFrameView
@end

@interface NSThemeFrame : NSTitledFrame
@end

@implementation NSThemeFrame (MFUIStringAnnotation)

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(_size:ofCell:withTitle:), MakeInterceptorFactory(void, (NSSize *sizePtr, id cell, id title), {
        MFSystemRenameDepthIncrement();
        OGImpl(sizePtr, cell, title);
        MFSystemRenameDepthDecrement();
    }));
}

@end

#pragma mark - NSMenuBarImpl swizzle

///
/// This sets the string of some menu item(s)(?) to the Apple Icon 
///

@interface NSCocoaMenuImpl : NSResponder
@end

@interface NSMenuBarImpl : NSCocoaMenuImpl
@end

@implementation NSResponder (MFUIStringAnnotation_NSMenuBarImpl) /// Can't make a category on `NSMenuBarImpl` due to linker errors. NSResponder is the closest superclass we can link against..

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses(object_getClass(objc_getClass("NSMenuBarImpl")), @{ @"framework": @"AppKit" }, @selector(appleMenuItem), MakeInterceptorFactory(id, (), {
        MFSystemRenameDepthIncrement();
        id result = OGImpl();
        MFSystemRenameDepthDecrement();
        return result;
    }));
    
}
@end

#pragma mark - NSMenuItem swizzling

///
/// Separator items have their string set to @"" I think
///

@implementation NSMenuItem (MFUIStringAnnotation)

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(_configureAsSeparatorItem), MakeInterceptorFactory(void, (), {
        MFSystemRenameDepthIncrement();
        OGImpl();
        MFSystemRenameDepthDecrement();
    }));
}

@end

#pragma mark - NSMenuItemView swizzling

@interface NSMenuItemView : NSView
@end

@implementation NSView (MFUIStringAnnotation_NSMenuItemView) /// Can't swizzle directly on NSMenuItemView due to linker errors

+ (void)load {
    
    /// We initially wanted to swizzle `updateStandardTitle:`, but we can't find it through the objc runtime even though it is called.
    ///     -> Maybe it's defined in a protocol extension or sth weird like that?
    /// Instead we swizzle `_initStandardMenuItem` which is a caller of updateStandardTitle:
    swizzleMethodOnClassAndSubclasses(objc_getClass("NSMenuItemView"), @{ @"framework": @"AppKit" }, @selector(_initStandardMenuItem), MakeInterceptorFactory(void, (), {
        MFSystemRenameDepthIncrement();
        OGImpl();
        MFSystemRenameDepthDecrement();
    }));
    
    
}
@end

#pragma mark - NSTextField swizzling

///
/// Textfields call [setStringValue: @""] on themselves during init
///

@implementation NSTextField (MFUIStringAnnotation)

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(initWithFrame:), MakeInterceptorFactory(id, (NSRect frame), {
        MFSystemRenameDepthIncrement();
        id result = OGImpl(frame);
        MFSystemRenameDepthDecrement();
        return result;
    }));
}

@end

#pragma mark - NSCell swizzling

///
/// NCell call [setStringValue: @""] on themselves during init
///

@implementation NSCell (MFUIStringAnnotation)

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(initTextCell:), MakeInterceptorFactory(id, (id value), {
        MFSystemRenameDepthIncrement();
        id result = OGImpl(value);
        MFSystemRenameDepthDecrement();
        return result;
    }));
}

@end

#pragma mark - NSLegacySegmentItem swizzling

///
/// I saw that "NSLegacySegmentItem" calls [setStringValue: <Value from IB>] on NSSegmentItemLabelCell, but after the loadNib routine is already done. Not sure what's going on.
///

@interface NSLegacySegmentItem : NSObject
@end

@implementation NSObject (MFUIStringAnnotation_NSLegacyItem) /// Can't create a category on NSLegacySegmentItem due to linker errors

+ (void)load {
    swizzleMethodOnClassAndSubclasses(objc_getClass("NSLegacySegmentItem"), @{ @"framework": @"AppKit" }, @selector(_recalcRectsForCell:), MakeInterceptorFactory(void, (id cell), {
        MFSystemRenameDepthIncrement();
        OGImpl(cell);
        MFSystemRenameDepthDecrement();
    }));
}

@end

#pragma mark - NSTabViewItem swizzling

///
/// `_computeDisplayedSizeOfString:` calls `[NSTabViewLabelCell setStringValue:<String From IB>]`, but after the nib loading routine is done it seems.
///     ^ Same thing for `_resetToolTipIfNecessary` and `drawLabel:inRect:`
///

@implementation NSTabViewItem (MFUIStringAnnotation)

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(_computeDisplayedSizeOfString:), MakeInterceptorFactory(NSSize, (id string), {
        MFSystemRenameDepthIncrement();
        NSSize result = OGImpl(string);
        MFSystemRenameDepthDecrement();
        return result;
    }));
    
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(_resetToolTipIfNecessary), MakeInterceptorFactory(void, (), {
        MFSystemRenameDepthIncrement();
        OGImpl();
        MFSystemRenameDepthDecrement();
    }));
    
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(drawLabel:inRect:), MakeInterceptorFactory(void, (bool drawLabel, NSRect rect), {
        MFSystemRenameDepthIncrement();
        OGImpl(drawLabel, rect);
        MFSystemRenameDepthDecrement();
    }));
}

@end
