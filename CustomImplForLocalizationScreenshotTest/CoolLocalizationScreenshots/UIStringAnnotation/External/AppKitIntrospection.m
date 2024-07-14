//
//  AppKitIntrospection.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 14.07.24.
//

#import "AppKitIntrospection.h"
#import "objc/runtime.h"

@implementation NSCell (MFIntrospection)

- (id)rawContents {
    
    /// Define an accessor method for the `_contents` instance var. This lets us get the raw internal value without the sideeffetcts of `- objectValue`.
    
    Ivar ivar = class_getInstanceVariable([self class], "_contents");
    if (ivar != NULL) {
        return object_getIvar(self, ivar);
    }
    return nil;
}

@end
