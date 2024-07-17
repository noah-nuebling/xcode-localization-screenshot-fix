//
//  AppDelegate.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import "AppDelegate.h"
#import "Utility.h"
#import "UINibDecoder+LocalizationKeyAnnotation.h"
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
//    [self localizedStringAssigningTests];
    /// TEsttinggg
    [self uiStringChangeDetectionTests];
    
}

- (void)localizedStringAssigningTests {
    
    NSString *localizedString = NSLocalizedString(@"label-from-objc.1", @"This is set in objc");
    self.codeButton.stringValue = localizedString;
    NSString *localizedString2 = NSLocalizedString(@"label-from-objc.2", @"This is also set in objc");
    self.codeButton.stringValue = localizedString2;
}

- (void)uiStringChangeDetectionTests {
    
    NSString *thisCharString = @"AA";
    
    #define _TEST_UISTRING(propertyName, setter) \
        do { \
        NSLog(@"--- TEST: Toggling %s (\"%@\") ... ---", #propertyName, thisCharString); \
        setter(thisCharString); \
        thisCharString = nextCharString(thisCharString); \
    } while(0)
    
    #define TEST_UISTRING(property) \
        do { \
            NSLog(@"--- TEST: Toggling %s (\"%@\") ... ---", #property, thisCharString); \
            property = thisCharString; \
            thisCharString = nextCharString(thisCharString); \
        } while(0)
        
    #define TEST_ATTRIBUTED_UISTRING(property) \
        do { \
            NSLog(@"--- TEST: Toggling %s (\"%@\") ... ---", #property, thisCharString); \
            property = thisCharString.attributed; \
            thisCharString = nextCharString(thisCharString); \
        } while(0)
    
    NSLog(@"-----------------------------");
    NSLog(@"BEGIN CHANGE DETECTION TESTS:");
    NSLog(@"-----------------------------");
    
    TEST_UISTRING(_codeTextField.stringValue);
    TEST_ATTRIBUTED_UISTRING(_codeTextField.attributedStringValue);
    TEST_UISTRING(_codeTextField.placeholderString);
    TEST_ATTRIBUTED_UISTRING(_codeTextField.placeholderAttributedString);
    TEST_UISTRING(_codeTextField.toolTip);
    
    TEST_UISTRING(_codeSearchField.stringValue);
    TEST_UISTRING(_codeSearchField.placeholderString);
    TEST_ATTRIBUTED_UISTRING(_codeSearchField.placeholderAttributedString);
    TEST_UISTRING(_codeSearchField.toolTip);
    
//    TEST_UISTRING(_codeMenuPopupButton.title); /// Not settable
//    TEST_UISTRING(_codeMenuPopupButton.stringValue); /// Not settable
    TEST_UISTRING(_codeMenuPopupButton.toolTip);
    
    TEST_UISTRING(_codeMenuItemOne.title);
    TEST_ATTRIBUTED_UISTRING(_codeMenuItemOne.attributedTitle);
    TEST_UISTRING(_codeMenuItemOne.toolTip);
    
    TEST_UISTRING(_codeCheckbox.title);
    TEST_ATTRIBUTED_UISTRING(_codeCheckbox.attributedTitle);
    TEST_UISTRING(_codeCheckbox.alternateTitle);
    TEST_ATTRIBUTED_UISTRING(_codeCheckbox.attributedAlternateTitle);
//    TEST_UISTRING(_codeCheckbox.stringValue); /// Not settable, is @"1" if the checkbox is ticked
//    TEST_ATTRIBUTED_UISTRING(_codeCheckbox.attributedStringValue);
    
    TEST_UISTRING(_codeButton.title);
    TEST_UISTRING(_codeSwitch.toolTip);
    
    TEST_UISTRING(_codeTableView.toolTip);
    TEST_UISTRING(_codeTableView.tableColumns[0].title);
    TEST_UISTRING(_codeTableScrollView.toolTip);
    TEST_UISTRING(_codeTableView.tableColumns[0].headerToolTip);
    
    TEST_UISTRING(_codeSegmentedControl.toolTip);
    _TEST_UISTRING("_codeSegmentedControl segmentOne label", ^(NSString *newValue) { [self->_codeSegmentedControl setLabel:newValue forSegment:0]; } );
    _TEST_UISTRING("_codeSegmentedControl segmentOne tooltip", ^(NSString *newValue) { [self->_codeSegmentedControl setToolTip:newValue forSegment:0]; } );
    
    TEST_UISTRING(_codeTabView.toolTip);
    TEST_UISTRING(_codeTabView.tabViewItems[0].toolTip);
    TEST_UISTRING(_codeTabView.tabViewItems[0].label);
    
    TEST_UISTRING(_codeOutlineView.tableColumns[0].title);
    
    TEST_UISTRING(_codeTextView.string);
    _TEST_UISTRING("_codeTextView textStorage attributedString", ^(NSString *newValue) {
        [self->_codeTextView.textStorage replaceCharactersInRange:NSMakeRange(0, self->_codeTextView.textStorage.length) withAttributedString:newValue.attributed];
    });
    TEST_UISTRING(_codeTextView.toolTip);
    
    TEST_UISTRING(_codeTestsPanel.title); /// Setting these sends a bazillion duplicated NSAccessibilityNotifications, so we're doing this last
    TEST_UISTRING(_codeTestsPanel.subtitle);
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
    
    /// Takes an NSString containing a character and returns an NSString containing the next unicode characte between A and Z.
    
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
