/**
 This is not actually a header. We just gave it the .h extension to be able to write with Xcode comment formatting.
 
 This file contains property setters from AppKit that we found through LLDB. In this file we sort and filter the output from LLDB to find the setters that are relevant for UIStringChange detection.
 
 --------------------------------------------------------
 
 
 
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
 
 Label Setters from LLDB.
 
 ```
 
 Private:
 -[NSMovePanel setMovePopupFieldLabel:]
 -[NSCloudSharingPanel setShareButtonLabel:]
 
 SegmentedControl:
 -[NSSegmentItem setLabel:]
 -[NSSegmentItemView setLabel:]
 -[NSSegmentedControl setLabel:forSegment:] (Only swizzling setLabel: should be fine)
 -[NSSegmentedCell setLabel:forSegment:]
 
 NSTouchBarItem:
 -[_NSUserDefinedTouchBarItem setLabel:]
 -[_NSSliderTouchBarItemView setLabel:]
 -[NSSliderTouchBarItem setLabel:]
 -[NSTouchBarColorPickerSwitcherItem setLabel:]
 -[NSTouchBarCustomizationPreviewDeletionLabel setLabel:]
 
 -[NSPickerTouchBarItem setLabel:atIndex:]
 -[NSPickerTouchBarItemView setLabel:atIndex:]
 
 -[NSCustomTouchBarItem setCustomizationLabel:]
 -[NSPopoverTouchBarItem setCustomizationLabel:]
 -[NSPickerTouchBarItem setCustomizationLabel:]
 -[NSGroupTouchBarItem setCustomizationLabel:]
 -[NSStepperTouchBarItem setCustomizationLabel:]
 -[NSColorPickerTouchBarItem setCustomizationLabel:]
 -[NSSharingServicePickerTouchBarItem setCustomizationLabel:]
 -[NSSliderTouchBarItem setCustomizationLabel:]
 -[NSCandidateListTouchBarItem setCustomizationLabel:]
 -[NSButtonTouchBarItem setCustomizationLabel:]
 
 -[NSPickerTouchBarItem setCollapsedRepresentationLabel:]
 -[NSPickerTouchBarItemView setCollapsedRepresentationLabel:]
 -[NSPopoverTouchBarItem setCollapsedRepresentationLabel:]
 
 -[NSTouchBarCustomizationPreviewItemContainerView setDeletionLabelString:]
 -[NSTouchBarCustomizationPaletteOverlayWindow setDragLabel:]
 
 Other:
 
 -[NSToolbarItem setLabel:]
 -[NSToolbarItem setPaletteLabel:]
 -[NSTabBarItem setLabel:]
 -[NSTabViewItem setLabel:]
 -[NSTabViewItem set_label:]
 -[NSDockTile setBadgeLabel:]
 -[NSRulerView setLabelString:forValue:]
 -[NSControl _setInToolbarWithIconAndLabel:]
 
 SavePanel:
 -[NSSavePanel setNameFieldLabel:] xxx
 -[NSRemoteSavePanel setNameFieldLabel:]
 -[NSLocalSavePanel setNameFieldLabel:]
 
 Secondary/Debug: (Probably not user-facing)
 -[_NSDebugResponderChainTableCellView setSecondaryLabel:]
 -[_NSDebugTouchBarTableCellView setSecondaryLabel:]
 
 IBConnector: (Not user-facing)
 -[NSNibConnector setLabel:]
 -[NSNibAXAttributeConnector setLabel:]
 -[NSIBUserDefinedRuntimeAttributesConnector setLabel:]
 -[NSIBHelpConnector setLabel:]
 
 Interesting? (Not string setters)
 
 -[NSSegmentItemView setLabelView:]
 -[NSToolbarItem setPossibleLabels:]
 
 Accessiblity:
 
 -[NSAccessibilityIndexedMockUIElement setAssociatedAccessibilityLabel:]
 
 
 -[NSAccessibilityCustomRotor setLabel:]
 -[NSAccessibilityCustomRotorItemResult setCustomLabel:]
 
 -[NSAccessibilityElement setAccessibilityLabel:]
 
 -[NSCell setAccessibilityLabel:]
 -[NSResponder setAccessibilityLabel:]
 -[NSSegmentedCell setAccessibilityLabel:forSegment:]
 
 -[NSCell setAccessibilityUserInputLabels:]
 -[NSCell setAccessibilityAttributedUserInputLabels:]
 -[NSCell setAccessibilityLabelUIElements:]
 -[NSCell setAccessibilityLabelValue:]
 -[NSMenu setAccessibilityUserInputLabels:]
 -[NSMenu setAccessibilityAttributedUserInputLabels:]
 -[NSMenu setAccessibilityLabel:]
 -[NSMenu setAccessibilityLabelUIElements:]
 -[NSMenu setAccessibilityLabelValue:]
 
 -[NSMenuItem setAccessibilityLabel:]
 -[NSMenuItem setAccessibilityUserInputLabels:]
 -[NSMenuItem setAccessibilityAttributedUserInputLabels:]
 -[NSMenuItem setAccessibilityLabelUIElements:]
 -[NSMenuItem setAccessibilityLabelValue:]
 
 -[NSSegmentItem setAccessibilityLabel:]
 
 -[NSResponder setAccessibilityUserInputLabels:]
 -[NSResponder setAccessibilityAttributedUserInputLabels:]
 -[NSResponder setAccessibilityLabelUIElements:]
 -[NSResponder setAccessibilityLabelValue:]
 
 -[NSAccessibilityElement setAccessibilityUserInputLabels:]
 -[NSAccessibilityElement setAccessibilityAttributedUserInputLabels:]
 -[NSAccessibilityElement setAccessibilityLabelUIElements:]
 -[NSAccessibilityElement setAccessibilityLabelValue:]
 
 -[NSComboButton setAccessibilityLabel:]
 
 -[NSSliderAccessory setAccessibilityLabel:]
 -[NSSliderAccessory setAccessibilityUserInputLabels:]
 -[NSSliderAccessory setAccessibilityAttributedUserInputLabels:]
 -[NSSliderAccessory setAccessibilityLabelUIElements:]
 -[NSSliderAccessory setAccessibilityLabelValue:]
 
 -[NSTouchBarCustomizationPreviewSectionShade setAccessibilityLabel:]
 
 -[NSTouchBarCustomizationPalettePresetItem(NSAccessibility) accessibilityLabel]
 
 
 ```
 
 */
