//
//  AppKitIntrospection.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 14.07.24.
//

#import "AppKitIntrospection.h"
#import "objc/runtime.h"


id getIvar(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar != NULL) return object_getIvar(object, ivar);
    return nil;
}

@implementation NSCell (MFIntrospection)

- (id)rawContents {
    
    /// Define an accessor method for the `_contents` instance var. This lets us get the raw internal value without the sideeffetcts of `- objectValue`.
    return getIvar(self, "_contents");
}

@end

@implementation NSToolbarItem (MFIntrospection)

- (nonnull id)rawItemViewer {
    return getIvar(self, "_itemViewer");
}

@end


