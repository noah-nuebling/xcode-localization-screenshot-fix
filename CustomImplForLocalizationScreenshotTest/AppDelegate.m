//
//  AppDelegate.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import "AppDelegate.h"
#import "Utility.h"
#import "NibDecodingAnalysis.h"
#import "NSString+Additions.h"
#import "objc/runtime.h"

@interface AppDelegate ()

/// CodeTestsPanel outlets

@property (weak) IBOutlet NSPanel *codeTestsPanel;

@property (weak) IBOutlet NSTextField *codeTextField;
@property (weak) IBOutlet NSSearchField *codeSearchField;
@property (weak) IBOutlet NSPopUpButton *codeMenuPopupButton;
@property (weak) IBOutlet NSMenuItem *codeMenuItemOne;
@property (weak) IBOutlet NSMenuItem *codeMenuItemTwo;
@property (weak) IBOutlet NSMenuItem *codeMenuItemThree;

@property (weak) IBOutlet NSTextField *codeLabel;
@property (weak) IBOutlet NSButton *codeCheckbox;
@property (weak) IBOutlet NSButton *codeButton;
@property (weak) IBOutlet NSSwitch *codeSwitch;

@property (weak) IBOutlet NSTextField *codeTableViewLabel;
@property (weak) IBOutlet NSTableView *codeTableView;
@property (weak) IBOutlet NSScrollView *codeTableScrollView;

@property (weak) IBOutlet NSSegmentedControl *codeSegmentedControl;
@property (weak) IBOutlet NSTabView *codeTabView;

@property (weak) IBOutlet NSOutlineView *codeOutlineView;
@property (unsafe_unretained) IBOutlet NSTextView *codeTextView;
@property (weak) IBOutlet NSScrollView *codeTextScrollView;

@property (weak) IBOutlet NSPathControl *codePathControl;
@property (weak) IBOutlet NSRuleEditor *codeRuleEditor;
@property (weak) IBOutlet NSSliderTouchBarItem *tbSlider;
@property (weak) IBOutlet NSTextField *tbLabel;
@property (weak) IBOutlet NSButton *tbButton;
@property (weak) IBOutlet NSTouchBarItem *tbSegmentedControlItem;
@property (weak) IBOutlet NSSegmentedControl *tbSegmentedControl;

/// TestsWindow outlets

@property (strong) IBOutlet NSWindow *testsWindow;

/// MainMenu outlets

@property (weak) IBOutlet NSMenu *aboutMenuItem;
@property (weak) IBOutlet NSMenuItem *preferencesMenuItem;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    /// Print all environment variables
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    NSLog(@"Printing all environment variables:");
    NSMutableString *envString = [@"" mutableCopy];
    for (NSString *key in env) {
        NSString *value = [env objectForKey:key];
        [envString appendFormat:@"\n%@ = %@", key, value];
    }
    NSLog(@"%@", envString);
    
    /// Print all command-line arguments
    NSLog(@"Printing all command-line arguments:");
    NSLog(@"Arguments: %@", [NSProcessInfo.processInfo.arguments componentsJoinedByString:@" | "]);
    
    /// Test setting uiStrings
    [self localizedStringAssigningTests];
    
}

- (void)localizedStringAssigningTests {
        
    #define TEST_UISTRING(__localizedStringMacro, __property) \
    do { \
        id localizedString = __localizedStringMacro; /** id since it might be localizedAttributedString */\
        NSLog(@"--- TEST: Toggling %s (\"%@\") ... ---", #__property, pureString(localizedString)); \
        __property = localizedString; \
    } while(0)
    #define TEST_UISTRING_(__localizedStringMacro, __propertyDescription, __setter) \
    do { \
        id localizedString = __localizedStringMacro; \
        NSLog(@"--- TEST: Toggling %s (\"%@\") ... ---", #__propertyDescription, pureString(localizedString)); \
        __setter(localizedString); \
    } while(0)
    
    NSLog(@"-----------------------------");
    NSLog(@"BEGIN CHANGE DETECTION TESTS:");
    NSLog(@"-----------------------------");
    
    TEST_UISTRING(NSLocalizedString(@"test-string.AA", @"Test string with id AA"), _codeTextField.stringValue);
    TEST_UISTRING(NSLocalizedAttributedString(@"test-string.BA", @"Test string with id BA"), _codeTextField.attributedStringValue);
    TEST_UISTRING(NSLocalizedString(@"test-string.CA", @"Test string with id CA"), _codeTextField.placeholderString);
    TEST_UISTRING(NSLocalizedAttributedString(@"test-string.DA", @"Test string with id DA"), _codeTextField.placeholderAttributedString);
    TEST_UISTRING(NSLocalizedString(@"test-string.EA", @"Test string with id EA"), _codeTextField.toolTip);
    
    TEST_UISTRING(NSLocalizedString(@"test-string.FA", @"Test string with id FA"), _codeSearchField.stringValue);
    TEST_UISTRING(NSLocalizedString(@"test-string.GA", @"Test string with id GA"), _codeSearchField.placeholderString);
    TEST_UISTRING(NSLocalizedAttributedString(@"test-string.HA", @"Test string with id HA"), _codeSearchField.placeholderAttributedString);
    TEST_UISTRING(NSLocalizedString(@"test-string.IA", @"Test string with id IA"), _codeSearchField.toolTip);
    
    //    TEST_UISTRING(NSLocalizedString(@"test-string.JA", @"Test string with id JA"), _codeMenuPopupButton.title); /// Not settable
    //    TEST_UISTRING(NSLocalizedString(@"test-string.KA", @"Test string with id KA"), _codeMenuPopupButton.stringValue); /// Not settable
    TEST_UISTRING(NSLocalizedString(@"test-string.LA", @"Test string with id LA"), _codeMenuPopupButton.toolTip);
    
    TEST_UISTRING(NSLocalizedString(@"test-string.MA", @"Test string with id MA"), _codeMenuItemOne.title);
    TEST_UISTRING(NSLocalizedAttributedString(@"test-string.NA", @"Test string with id NA"), _codeMenuItemOne.attributedTitle);
    TEST_UISTRING(NSLocalizedString(@"test-string.OA", @"Test string with id OA"), _codeMenuItemOne.toolTip);
    
    TEST_UISTRING(NSLocalizedString(@"test-string.PA", @"Test string with id PA"), _codeCheckbox.title);
    TEST_UISTRING(NSLocalizedAttributedString(@"test-string.QA", @"Test string with id QA"), _codeCheckbox.attributedTitle);
    TEST_UISTRING(NSLocalizedString(@"test-string.RA", @"Test string with id RA"), _codeCheckbox.alternateTitle);
    TEST_UISTRING(NSLocalizedAttributedString(@"test-string.SA", @"Test string with id SA"), _codeCheckbox.attributedAlternateTitle);
    //    TEST_UISTRING(NSLocalizedString(@"test-string.TA", @"Test string with id TA"), _codeCheckbox.stringValue); /// Not settable, is @"1" if the checkbox is ticked
    //    TEST_UISTRING(NSLocalizedString(@"test-string.UA", @"Test string with id UA"), _codeCheckbox.attributedStringValue);
    
    TEST_UISTRING(NSLocalizedString(@"test-string.VA", @"Test string with id VA"), _codeButton.title);
    TEST_UISTRING(NSLocalizedString(@"test-string.WA", @"Test string with id WA"), _codeSwitch.toolTip);
    
    TEST_UISTRING(NSLocalizedString(@"test-string.XA", @"Test string with id XA"), _codeTableView.toolTip);
    TEST_UISTRING(NSLocalizedString(@"test-string.YA", @"Test string with id YA"), _codeTableView.tableColumns[0].title);
    TEST_UISTRING(NSLocalizedString(@"test-string.ZA", @"Test string with id ZA"), _codeTableScrollView.toolTip);
    TEST_UISTRING(NSLocalizedString(@"test-string.AB", @"Test string with id AB"), _codeTableView.tableColumns[0].headerToolTip);
    
    TEST_UISTRING(NSLocalizedString(@"test-string.BB", @"Test string with id BB"), _codeSegmentedControl.toolTip);
    TEST_UISTRING_(NSLocalizedString(@"test-string.CB", @"Test string with id CB"), _codeSegmentedControl segmentOne label, ^(NSString *newValue) { [self->_codeSegmentedControl setLabel:newValue forSegment:0]; } );
    TEST_UISTRING_(NSLocalizedString(@"test-string.DB", @"Test string with id DB"), _codeSegmentedControl segmentTwo tooltip, ^(NSString *newValue) { [self->_codeSegmentedControl setToolTip:newValue forSegment:1]; } );
    
    TEST_UISTRING(NSLocalizedString(@"test-string.EB", @"Test string with id EB"), _codeTabView.toolTip);
    TEST_UISTRING(NSLocalizedString(@"test-string.FB", @"Test string with id FB"), _codeTabView.tabViewItems[0].label);
    TEST_UISTRING(NSLocalizedString(@"test-string.GB", @"Test string with id GB"), _codeTabView.tabViewItems[0].toolTip);
    
    TEST_UISTRING(NSLocalizedString(@"test-string.HB", @"Test string with id HB"), _codeOutlineView.tableColumns[0].title);
    
    TEST_UISTRING(NSLocalizedString(@"test-string.IB", @"Test string with id IB"), _codeTextView.string);
    TEST_UISTRING_(NSLocalizedString(@"test-string.JB", @"Test string with id JB"), _codeTextView textStorage attributedString, ^(NSString *newValue) { [self->_codeTextView.textStorage replaceCharactersInRange:NSMakeRange(0, self->_codeTextView.textStorage.length) withAttributedString:newValue.attributed]; });
    TEST_UISTRING(NSLocalizedString(@"test-string.LB", @"Test string with id LB"), _codeTextView.toolTip);
    
    TEST_UISTRING(NSLocalizedString(@"test-string.MB", @"Test string with id MB"), _codePathControl.toolTip);
    TEST_UISTRING(NSLocalizedString(@"test-string.NB", @"Test string with id NB"), _codePathControl.placeholderString);
    
    TEST_UISTRING(NSLocalizedString(@"test-string.OB", @"Test string with id OB"), _codeRuleEditor.toolTip); /// ruleEditor.formattingStringsFilename and .formattingDictionary contain localized strings, but I'm not sure how to handle that.
    
    /// TouchBarItem
    /// Not implementing TouchBarItems.
    ///     The slider isn't its own axUIElement it's a container for 4 different axUIElements. But the slider itself holds the customizationLabel. Too complicated.
    
//    TEST_UISTRING(NSLocalizedString(@"test-string.PB", @"Test string with id PB"), _tbSlider.label); ///
//    TEST_UISTRING(NSLocalizedString(@"test-string.QB", @"Test string with id QB"), _tbSlider.customizationLabel); ///
    
//    TEST_UISTRING(NSLocalizedString(@"test-string.RB", @"Test string with id RB"), _tbLabel.stringValue);
//    TEST_UISTRING(NSLocalizedAttributedString(@"test-string.SB", @"Test string with id SB"), _tbLabel.placeholderAttributedString);
    
//    TEST_UISTRING(NSLocalizedString(@"test-string.TB", @"Test string with id TB"), _tbButton.title);
//    TEST_UISTRING(NSLocalizedAttributedString(@"test-string.UB", @"Test string with id UB"), _tbButton.attributedAlternateTitle);
//    TEST_UISTRING(NSLocalizedString(@"test-string.VB", @"Test string with id VB"), _tbButton.toolTip);
    
//    TEST_UISTRING(NSLocalizedString(@"test-string.WB", @"Test string with id WB"), _tbSegmentedControlItem.customizationLabel); /// Can only find customizationLabel on the item, and that isn't settable.
//    TEST_UISTRING(NSLocalizedString(@"test-string.XB", @"Test string with id XB"), _tbSegmentedControl.toolTip);
//    TEST_UISTRING_(NSLocalizedString(@"test-string.YB", @"Test string with id YB"), _tbSegmentedControl segmentOne label, ^(NSString *newValue) { [self->_tbSegmentedControl setLabel:newValue forSegment:0]; } );
//    TEST_UISTRING_(NSLocalizedString(@"test-string.ZB", @"Test string with id ZB"), _tbSegmentedControl segmentTwo tooltip, ^(NSString *newValue) { [self->_tbSegmentedControl setToolTip:newValue forSegment:1]; } );
    
    /// Window
    
    TEST_UISTRING(NSLocalizedString(@"test-string.AC", @"Test string with id AC"), _codeTestsPanel.title); /// Setting these sends a bazillion duplicated NSAccessibilityNotifications, so we're doing this last
    TEST_UISTRING(NSLocalizedString(@"test-string.BC", @"Test string with id BC"), _codeTestsPanel.subtitle);
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

///
/// Helper
///

static NSString *nextCharString(NSString *charString) {
    
    /**
     
     Everytime this is called, it creates a new unique string. E.g. AA -> BA -> CA, ...
     Now we're hardcoding these strings in our testing code so we don't need this anymore.
     */
    
    assert(false);
    
    const char *innerString = [charString cStringUsingEncoding:NSUTF8StringEncoding];
    long nOfDigits = strlen(innerString);
    char string[nOfDigits];
    strcpy(string, innerString);
    
    int i = 0;
    while (true) {
        string[i] += 1;
        if (string[i] > 'Z') {
            /// Overflow
            string[i] = 'A';
            i++;
            if (i >= nOfDigits) { /// Digit overflow.
                i = 0;
            }
        } else {
            break;
        }
    }
    string[nOfDigits] = 0;
    return [NSString stringWithCString:string encoding:NSUTF8StringEncoding];
}


@end
