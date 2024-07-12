//
//  NSIBHelpConnector.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 10.07.24.
//

#import <Foundation/Foundation.h>
#import "AppKit/AppKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSIBHelpConnector : NSObject

/// Declare minimal interface for the private NSIBHelpConnector class so we can inspect it it inside our NibAnnotation code

- (NSString *)marker;       /// Note: Label and marker were the same exactly NSString instance in the example I've seen - the UI string of the tooltip
- (NSString *)label;

- (NSString *)file;         /// Note: file was "NSToolTipHelpKey" in the example I've seen.

- (NSObject *)source;       /// Note: source was nil in the example I've seen
- (NSObject *)destination;  /// Note: destination was the object that owned the tooltip in the example I've seen

@end

@interface NSAccessibilityProxy : NSObject
@end
//@interface NSAccessibilityReparentingProxy : NSAccessibilityProxy
//@end
@interface NSAccessibilityProxy (Introspection)
- (id)realElement;
- (id)fauxParent;
@end


@interface NSWindowTemplate : NSObject

/// Declare minimal interface for the private NSWindowTemplate class so we can inspect it it inside our NibAnnotation code
///     (These are all the methods that don't take any arguments)

- (id)subtitle;
- (id)title;

/// Interesting?

- (id)identifier;
- (id)className;

- (long long)titleVisibility;

- (id)contentViewController;
- (id)tabbingIdentifier;
- (id)userInterfaceItemIdentifier;

- (id)frameAutosaveName;
- (id)toolbar;
- (id)appearance;
- (id)nibInstantiate;
- (Class)windowClassForNibInstantiate;

/// Not interesting

- (void)dealloc;
- (id)init;
- (long long)contentTitlebarSeparatorStyle;
- (long long)level;
- (CGSize)maxSize;
- (CGSize)minSize;
- (bool)allowsToolTipsWhenApplicationIsInactive;
- (long long)animationBehavior;
- (unsigned long long)autoPositionMask;
- (bool)autorecalculatesKeyViewLoop;
- (unsigned long long)backingType;
- (unsigned long long)collectionBehavior;
- (CGSize)contentMaxSize;
- (CGSize)contentMinSize;
- (bool)hasDynamicDepthLimit;
- (bool)hasShadow;
- (bool)hidesOnDeactivate;
- (unsigned long long)interfaceStyle;
- (bool)isDeferred;
- (bool)isOneShot;
- (bool)isReleasedWhenClosed;
- (bool)isRestorable;
- (CGSize)maxFullScreenContentSize;
- (bool)maxFullScreenContentSizeIsSet;
- (CGSize)minFullScreenContentSize;
- (bool)minFullScreenContentSizeIsSet;
- (bool)showsToolbarButton;
- (unsigned long long)styleMask;
- (long long)tabbingMode;
- (bool)titlebarAppearsTransparent;
- (long long)titlebarSeparatorStyle;
- (long long)toolbarStyle;
- (bool)wantsToBeColor;
- (unsigned long long)windowBackingLocation;
- (unsigned long long)windowSharingType;

@end

@interface NSWindowTemplate (Introspection)

- (NSView *)windowView;

@end

NS_ASSUME_NONNULL_END
