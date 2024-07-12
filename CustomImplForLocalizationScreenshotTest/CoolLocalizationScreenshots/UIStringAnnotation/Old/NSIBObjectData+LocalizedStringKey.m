//
//  NSView+LocalizedStringKey.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 07.07.24.
//

///
/// This stuff is unused now
///
/// This class used to swizzle initWithCoder, and then observe the kvPairs extracted by UINibDecoder, and then finally it used to extract LocalizedStringKeys from those kvPairs and publish them through the Accessibility API. However, I think we only catch all the LocalizedStringKeys by replacing the loadNib: function, ORRRR by doing this stuff in the top-level [UINibDecoder - decodeObjectForKey:] call - which would also simplify things. So we're doing that.
///

#if FALSE

#import "NSIBObjectData+LocalizedStringKey.h"
#import "Swizzle.h"
#import "Utility.h"
#import "UINibDecoder+LocalizationKeyAnnotation.h"
#import "AppKit/NSAccessibility.h"

#import "objc/runtime.h"

#import "dlfcn.h"
#import <mach-o/dyld.h>

#import "AppKit/AppKit.h"

@implementation NSIBObjectData (LocalizedStringKey)



+ (void)load {
    
    /// TODO: Only swizzle while taking Localization Screenshots.
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzleMethod([self class], @selector(initWithCoder:), @selector(swizzled_initWithCoder:));
    });
}

- (NSMutableDictionary *)associatedStorage {
    
    const char *key = "localizationScreenshotAssociatedStorage";
    
    NSMutableDictionary *storage = objc_getAssociatedObject(self, key);
    if (storage == nil) {
        storage = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, key, storage, OBJC_ASSOCIATION_RETAIN);
    }
    
    return storage;
}

- (instancetype)swizzled_initWithCoder:(NSCoder *)coder
{
    
    /// Add accumulator
    NSMutableArray *accumulator = [NSMutableArray array];
    [(UINibDecoder *)coder addKVPairAccumulator: accumulator];
    
    /// Call og method
    NSIBObjectData *obj = [self swizzled_initWithCoder:coder]; /// This calls the original implementation, due to swizzling
    
    /// Remove accumulator
    [(UINibDecoder *)coder removeKVPairAccumulator: accumulator];
    
    /// Log
    NSLog(@"LocStrings: STORRREEE, %@", accumulator);
    
    /// Store
    [self associatedStorage][@"kvPairAccumulator"] = accumulator; /// We don't need to do this since we're not doing shit in awakeFromNib anymore
        
    /// Parse accumulated KVPairs
    /// Notes from when we swizzled NSView instead of NSIBObjectData, and used to call annotateUIElements from awakeFromNib:
    /// - We're doing this here instead of in initWithCoder (where the kvPairs are accumulated) because we thought it would would fix an issues with
    ///     setting the accessibilityChildren. We fixed the issues now, but I'm not sure putting this in awakeFromNib was necessary.
    
    [self annotateUIElements:accumulator];
    
    /// Return
    return obj;
}

- (void)annotateUIElements:(NSArray *)accumulator {
    
    NSLog(@"-------------------");
    NSLog(@"LocStrings: SWOOOZLE, %@", accumulator);
    
    NSMutableArray <NSString *> *lastLocalizationKeys = [NSMutableArray array];
    
    for (NSDictionary *kvPair in accumulator) {
        
        NSString *key = kvPair[@"key"];
        id value = kvPair[@"value"];
        
        if ([key isEqual: @"NSKey"]) {
            
            /// Collect localizaiton keys
            [lastLocalizationKeys addObject:value];
            
        } else if ([key isEqual: @"NSSuperview"]) {
            
            /// Skip superview
            ///     Not sure why/if this makes sense, but I think it does. -> If we skip the superview we can be very certain that the next accessibility Element we iterate over is the container for last localizedStringKeys that we iterated over.
            
        } else {
            
            /// Check if `value` is an accessibility element
            
            BOOL isAccessibilityElement = NO;
            NSArray *baseAccessibilityProtocols = @[@protocol(NSAccessibility), @protocol(NSAccessibilityElement), @protocol(NSAccessibilityElementLoading)];
            for (Protocol *protocol in baseAccessibilityProtocols) {
                if ([[value class] conformsToProtocol:protocol]) {
                    isAccessibilityElement = YES;
                    break;
                }
            }
            
            if (isAccessibilityElement) {
                
                /// Attach localization keys
                /// Notes:
                /// - We assume that the next accessibility element we find is the container holding the string translated by the `lastLocalizationKeys`
                /// - This all depends on the order of elements in the accumulator (which is what we're iterating over).
                /// - The order of the accumulator is equivelent to the order that elements are decoded by `initWithCoder:`. From my understanding, this is a depth-first-search through the object-hierarchy
                /// - NSKeyedUnarchiver, which is the most common NSCoder subclass (the NSCoder subclass we're dealing with here is UINibDecoder) also implements this object-hierarchy stuff. Maybe its docs are helpful.
                
                if (lastLocalizationKeys.count > 0) {
                    
                    NSString *axString = [lastLocalizationKeys componentsJoinedByString:@", "];
                    
                    /// Idea 1: Store as attribute
                    /// Note: I can't find unused attributes, and the new AX API won't let you set values for custom keys I think. We also tried using the private NSAccessibilitySetObjectValueForAttribute but it also doesn't let you set completely custom attributes.
                    //                    [(NSAccessibilityElement *)value setAccessibilityHelp:axString];
                    
                    /// Idea 2: Add child
                    NSMutableArray *children = [(NSAccessibilityElement *)value accessibilityChildren/*InNavigationOrder*/].mutableCopy;
                    if (children == nil) {
                        children = [NSMutableArray array];
                    }
                    NSAccessibilityElement *newChild = [NSAccessibilityElement accessibilityElementWithRole:@"MFLocalizedStringKeysRole" frame:NSZeroRect label:axString parent:value];
                    [newChild setAccessibilityEnabled:NO];
                    [children addObject:newChild];
                    [(id<NSAccessibility>)value setAccessibilityChildren/*InNavigationOrder*/:children];
                    
                    /// Clear lastLocalizationKeys
                    [lastLocalizationKeys removeAllObjects];
                }
            }
        }
        
        
    }
}



///
/// Private AX stuff
///

void NSAccessibilitySetObjectValueForAttribute3(id target, id value, NSAccessibilityAttributeName attribute) {
    
    /// Notes:
    /// - This makes the private function `NSAccessibilitySetObjectValueForAttribute` function available which is used internally by standard functions such as `setAccessibilityHelp:`
    /// - We get the function pointer directly from lldb. Using `extern` or `dlsym` to get the function pointer from code didn't work for some reason.
    /// - This function isn't actually that useful since you cannot pass in completely custom attributes. Instead you have to pass in one of the the constants from `NSAccessibilityAttributeName`.
    ///     (Not even other string instances with the same content as one of the `NSAccessibilityAttributeName`s will work, it has to be exactly one of the `NSAccessibilityAttributeName` instances.)
    /// - I think we'll just use setAccessibilityHelp: instead of this
    ///
    /// Update:
    /// - I just had the idea for making the non-hard-coded version work: Perhaps we could use```AppKit`NSAccessibilitySetObjectValueForAttribute``` or ```AppKit`NSAccessibilitySetObjectValueForAttribute:``` as the symbol name instead of just ```NSAccessibilitySetObjectValueForAttribute```? Maybe that would have helped loading stuff with dlsym.
    /// - Also maybe setting "Other Linker Flags" in build setting would have helped.
    
    /// Define function pointer
    /// - Might have to update this on restart or for new macOS versions. Use `image lookup -s NSAccessibilitySetObjectValueForAttribute` in lldb to get new value..
    void (*theFunction)(id, id, NSString *, NSString *, int64_t) = (void *)0x18f39d6dc;
    
    /// Define flags
    /// Note: Just making sure the registers look exactly like when this function is called from `setAccessibilityHelp:`. That's also why we pass in attribute twice. Not sure it's necessary.
    int64_t flags = 0;
    
    /// Step 3: Call the function
    theFunction(target, value, attribute, attribute, flags);
    
}

//void NSAccessibilitySetObjectValueForAttribute1(id<NSAccessibility> target, const NSAccessibilityAttributeName attribute, NSObject *object) {
//    
//    /// Notes:
//    /// - Making NSAccessibilitySetObjectValueForAttribute available, doing it dynamically since there's a linker error when using `extern` - not sure why
//    /// - Loading /System/Library/Frameworks/Security.framework/Security and getting the SecTranslocateIsTranslocatedURL function (as we do in MMF) works here as well. But the appKit stuff doesn't.
//    
//    /// Step 1: Load the framework dynamically
//    /// Notes:
//    /// - /System/Library/Frameworks/AppKit.framework/AppKit
//    /// - /System/Library/Frameworks/AppKit.framework/Versions/C/Resources/BridgeSupport/AppKit.dylib
//    /// - /System/iOSSupport/System/Library/PrivateFrameworks/JITAppKit.framework/JITAppKit
//    /// - ```/System/Library/Frameworks/_GroupActivities_AppKit.framework/_GroupActivities_AppKit```
//    /// - ```/System/Library/Frameworks/_AppIntents_AppKit.framework/_AppIntents_AppKit```
//    void *appKitHandle = dlopen("/System/Library/Frameworks/AppKit.framework/AppKit", RTLD_LAZY);
//    if (!appKitHandle) {
//        NSLog(@"Failed to open AppKit.framework");
//        return;
//    }
//    
//    /// Step 2: Get the function pointer
//    void (*theFunction)(id<NSAccessibility>, const NSAccessibilityAttributeName, NSObject *);
//    theFunction = (void (*)(id<NSAccessibility>, const NSAccessibilityAttributeName, NSObject *))dlsym(appKitHandle, "NSAccessibilitySetObjectValueForAttribute");
//    if (!theFunction) {
//        NSLog(@"Failed to find symbol NSAccessibilitySetObjectValueForAttribute");
//        dlclose(appKitHandle); // Close the handle on failure
//        return;
//    }
//    
//    /// Step 3: Call the function
//    theFunction(target, attribute, object);
//    
//    /// Step 4: Close the handle
//    dlclose(appKitHandle);
//    
//}
//
//typedef void (*NSAccessibilitySetObjectValueForAttributeFunc)(id<NSAccessibility>, NSAccessibilityAttributeName, id);
//
//NSAccessibilitySetObjectValueForAttributeFunc FindNSAccessibilitySetObjectValueForAttribute(void) {
//    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
//        const char *image_name = _dyld_get_image_name(i);
//        if (strstr(image_name, "/System/Library/Frameworks/AppKit.framework/") != NULL) {
//            void *handle = dlopen(image_name, RTLD_LAZY);
//            if (handle) {
//                Dl_info info;
//                void *symbol = dlsym(handle, "NSAccessibilitySetObjectValueForAttribute");
//                if (symbol && dladdr(symbol, &info)) {
//                    return (NSAccessibilitySetObjectValueForAttributeFunc)info.dli_saddr;
//                }
//                dlclose(handle);
//            }
//        }
//    }
//    return NULL;
//}
//
//void NSAccessibilitySetObjectValueForAttribute2(id<NSAccessibility> target, NSAccessibilityAttributeName attribute, id object) {
//    static NSAccessibilitySetObjectValueForAttributeFunc originalFunc = NULL;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        originalFunc = FindNSAccessibilitySetObjectValueForAttribute();
//    });
//    
//    if (originalFunc) {
//        originalFunc(target, attribute, object);
//    } else {
//        NSLog(@"Failed to locate NSAccessibilitySetObjectValueForAttribute");
//    }
//}

@end

#endif
