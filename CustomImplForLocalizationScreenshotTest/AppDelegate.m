//
//  AppDelegate.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

#import "AppDelegate.h"
#import "Utility.h"
#import "UINibDecoder+LocalizationKeyAnnotation.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSTextField *setInCodeLabel;
@property (weak) IBOutlet NSTextField *setInCodeLabel2;
@property (weak) IBOutlet NSMenuItem *setInCodeMenuItem;
@property (weak) IBOutlet NSButton *setInCodeButton;

@property (strong) IBOutlet NSWindow *window;
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
    NSLog(envString);
    
    /// Print all command-line arguments
    NSLog(@"Printing all command-line arguments:");
    NSLog(@"Arguments: %@", [NSProcessInfo.processInfo.arguments componentsJoinedByString:@" | "]);
    
    /// Test using NSLocalizedString
    
    NSString *localizedString = NSLocalizedString(@"label-from-objc.1", @"This is set in objc");
    self.setInCodeLabel.stringValue = localizedString;
    NSString *localizedString2 = NSLocalizedString(@"label-from-objc.2", @"This is also set in objc");
    self.setInCodeLabel2.stringValue = localizedString2;
    
    /// NOTE: Found this key by calling listMethods() on NSString instance inside NSLocalizedString [initWithCoder:]: `un_localizedStringKey`
    ///     But it doesn't work here.
    

    
    /// TEsttinggg
    [self startToggling];
    
}

- (void)startToggling {
    
    /// Inspect the app with Accessibility Inspector for this to start sending AX Notifications.
    
//    self.window.title = @"a";
    self.setInCodeMenuItem.title = @"a";
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
//        self.window.title = @"b";
        self.setInCodeMenuItem.title = @"b";
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startToggling];
        });
    });
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


@end
