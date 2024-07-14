//
//  SystemRenameTracker.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 14.07.24.
//

#import "SystemRenameTracker.h"
#import "AppKit/AppKit.h"
#import "Swizzle.h"

#pragma mark - RenameDepth definitions

#define MFSystemRenameDepthKey @"MFSystemRenameDepth"

///
/// We record whether the system is currently inside a routine that might set a uiString on a uiElement.
/// The UIStringChangeDetector can then know if it's dealing with a uiString change caused by the system or by the current program by calling `MFSystemIsChangingUIStrings()`.
///

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
    swizzleMethods([self class], false, nil /*@"AppKit"*/, @"swizzled_", @selector(swizzled_validateMenuItem:), nil);
}

- (BOOL)swizzled_validateMenuItem:(NSMenuItem *)menuItem {
    
    
    NSString *beforeTitle = [menuItem title];
    MFSystemRenameDepthIncrement();
    BOOL result = [self swizzled_validateMenuItem:menuItem];
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
    swizzleMethods([self class], false, nil, @"swizzled_", @selector(swizzled_updateTextFieldIfNecessary), nil);
}

- (void *)swizzled_updateTextFieldIfNecessary {
    MFSystemRenameDepthIncrement();
    void *result = [self swizzled_updateTextFieldIfNecessary];
    MFSystemRenameDepthDecrement();
    return result;
}

@end

#pragma mark - NSTextFieldCell swizzling

///
/// For some reason [NSTextFieldCell -init] seemingly sets the AXValue to "Field" and then to empty string.
///

@implementation NSTextFieldCell (MFUIStringAnnotation)

+ (void)load {
    swizzleMethods([self class], true, @"AppKit", @"swizzled_", @selector(swizzled_init), nil);
}

- (instancetype)swizzled_init {
    MFSystemRenameDepthIncrement();
    NSTextFieldCell *result = [self swizzled_init];
    MFSystemRenameDepthDecrement();
    return result;
}

@end


#pragma mark - NSTableHeaderView swizzling

///
/// [NSTableHeaderView -_preparedHeaderFillerCell] creates a tableHeaderCell and inits it with empty strings and `AXRoleDescription = "Taste zum Sortieren";`
///

@implementation NSTableHeaderView (MFUIStringAnnotation)

+ (void)load {
    swizzleMethods([self class], true, @"AppKit", @"swizzled_", @selector(swizzled__preparedHeaderFillerCell), nil);
}

- (void *)swizzled__preparedHeaderFillerCell {
    MFSystemRenameDepthIncrement();
    void *result = [self swizzled__preparedHeaderFillerCell];
    MFSystemRenameDepthDecrement();
    return result;
}

@end
