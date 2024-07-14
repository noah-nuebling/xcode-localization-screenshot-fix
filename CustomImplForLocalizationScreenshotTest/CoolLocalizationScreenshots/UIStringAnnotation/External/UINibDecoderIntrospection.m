//
//  UINibDecoderDefinitions.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 11.07.24.
//

#import <Foundation/Foundation.h>
#import "UINibDecoderIntrospection.h"
#import "objc/runtime.h"

@implementation NSWindowTemplate (Introspection)

- (NSView *)windowView {
    
    /// Define an accessor method for the `windowView` instance var.
    ///     I'm not sure why the class doesn't define its own accessor. (Perhaps there's a category by Apple that defines an accessor?)
    
    Ivar ivar = class_getInstanceVariable([self class], "windowView");
    if (ivar != NULL) {
        return object_getIvar(self, ivar);
    }
    return nil;
}
@end

@implementation NSAccessibilityProxy (Introspection)

- (id)realElement {
    Ivar ivar = class_getInstanceVariable([self class], "_realElement");
    if (ivar != NULL) {
        return object_getIvar(self, ivar);
    }
    return nil;
}
- (id)fauxParent {
    Ivar ivar = class_getInstanceVariable([self class], "_fauxParent");
    if (ivar != NULL) {
        return object_getIvar(self, ivar);
    }
    return nil;
}
@end
