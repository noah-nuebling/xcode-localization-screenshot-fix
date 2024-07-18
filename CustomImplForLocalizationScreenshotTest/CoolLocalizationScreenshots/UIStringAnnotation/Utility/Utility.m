//
//  Utility.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 08.07.24.
//

#import "Utility.h"
@import ObjectiveC.runtime;
@import AppKit;
#import "NSString+Additions.h"
#import "dlfcn.h"
#import "objc/runtime.h"

@implementation Utility

NSArray<Class> *searchClasses(NSDictionary<MFClassSearchCriterion, id> *criteria) {

    /// Validate
    assert([criteria isKindOfClass:[NSDictionary class]]);
    
    /// Extract criteria
    Protocol *protocol = criteria[MFClassSearchCriterionProtocol];
    Class baseClass = criteria[MFClassSearchCriterionSuperclass];
    NSString *namePrefixNS = criteria[MFClassSearchCriterionClassNamePrefix];
    NSString *frameworkNameNS = criteria[MFClassSearchCriterionFrameworkName];
    
    /// Validate 
    /// - at least one criterion
    assert(protocol != nil || baseClass != nil || namePrefixNS != nil || frameworkNameNS != nil);
    
    /// Validate 
    /// - no extra criteria
    NSMutableDictionary *criteriaMutable = criteria.mutableCopy;
    criteriaMutable[MFClassSearchCriterionProtocol] = nil;
    criteriaMutable[MFClassSearchCriterionSuperclass] = nil;
    criteriaMutable[MFClassSearchCriterionClassNamePrefix] = nil;
    criteriaMutable[MFClassSearchCriterionFrameworkName] = nil;
    assert(criteriaMutable.count == 0);
    
    /// Preprocess baseClass
//    BOOL baseClassIsMetaClass = class_isMetaClass(baseClass);
//    NSString *baseClassName = NSStringFromClass(baseClass);
    
    /// Preprocess namePrefix
    const char *namePrefix = NULL;
    if (namePrefixNS) {
        namePrefix = [namePrefixNS cStringUsingEncoding:NSUTF8StringEncoding];
    }
    
    /// Preprocess frameworkName
    
    void *frameworkHandle = NULL;
    if (frameworkNameNS != nil) {
        const char *frameworkName = [frameworkNameNS cStringUsingEncoding:NSUTF8StringEncoding];
        const char *frameworkPath = searchFrameworkPath(frameworkName);
        frameworkHandle = dlopen(frameworkPath, RTLD_LAZY | RTLD_GLOBAL); /// Maybe we could/should use `RTLD_NOLOAD` here for better performance?
        assert(frameworkHandle != NULL);
    }
    
    /// Find classes
    /// `objc_enumerateClasses` is only available on macOS 13.0 and later. Alternatives are  `objc_copyClassNamesForImage`, `objc_copyClassList`, `objc_getClassList`.
    
    NSMutableArray *result = [NSMutableArray array];
    objc_enumerateClasses(frameworkHandle, namePrefix, protocol, baseClass, ^(Class _Nonnull aClass, BOOL * _Nonnull stop){
        [result addObject:aClass];
    });
    
    /// Release framework handle
    dlclose(frameworkHandle);
    
    /// Return
    return result;
}

const char *searchFrameworkPath(const char *frameworkName) {
    
    /// Can't get dlopen to find any frameworks without hardcoding the path, so we're making our own framework searcher
    
    /// Preprocess framework name
    char *frameworkSubpath = NULL;
    asprintf(&frameworkSubpath, "%s.framework/%s", frameworkName, frameworkName);
    
    /// Define constants
    const char *frameworkSearchPaths[] = {
        "/System/Library/Frameworks",
        "/System/Library/PrivateFrameworks",
        "/Library/Frameworks",
    };
    
    /// Search for the framework
    const char *result = NULL;
    for (int i = 0; i < sizeof(frameworkSearchPaths)/sizeof(char *); i++) {
        
        const char *frameworkSearchPath = frameworkSearchPaths[i];
        
        char *frameworkPath;
        asprintf(&frameworkPath, "%s/%s", frameworkSearchPath, frameworkSubpath);
        
        void *handle = dlopen(frameworkPath, RTLD_LAZY | RTLD_GLOBAL); /// Should we use `RTLD_NOLOAD`? Not sure about the option flags.
        
        bool frameworkWasFound = handle != NULL;
        if (frameworkWasFound) {
            int closeRet = dlclose(handle);
            if (closeRet != 0) {
                char *error = dlerror();
                NSLog(@"dlclose failed with error %s", error);
                assert(false);
            }
        }
        
        if (frameworkWasFound) {
            result = frameworkPath;
            break;
        }
    }
    
    /// Return frameworkPath
    if (result != NULL) {
        return result;
    }
    
    ///
    /// Fallback: objc runtime
    ///
    
    /// Not sure this is actually slower than the main appriach. Should be more robust though.
    
    char *frameworkSubpath2 = NULL; /// Why are we using another subpath: When using dlopen `...AppKit.framework/AppKit` works, but in the objc imageNames `...AppKit.framework/Versions/C/AppKit` appears.
    asprintf(&frameworkSubpath2, "%s.framework", frameworkName);
    
    unsigned int imageCount;
    const char **imagePaths = objc_copyImageNames(&imageCount); /// The API is called imageNames, but it returns full framework paths from what I can tell.
    
    for (int i = 0; i < imageCount; i++) {
        const char *imagePath = imagePaths[i];
        bool frameworkSubpathIsInsideImagepath = strstr(imagePath, frameworkSubpath2) != NULL;
        if (frameworkSubpathIsInsideImagepath) {
            result = imagePath;
            break;
        }
    }
    
    free(imagePaths);
    
    assert(result != NULL);
    return result;
    
}


BOOL classInheritsMethod(Class class, SEL selector) {
    
    /// Returns YES if the class inherits the method for `selector` from its superclass, instead of defining its own implementation.
    /// Note: Also see `class_copyMethodList`
    
    /// Main check
    Method classMethod = class_getInstanceMethod(class, selector);
    Method superclassMethod = class_getInstanceMethod(class_getSuperclass(class), selector);
    BOOL classInherits = classMethod == superclassMethod;
    
    /// ?
    assert(classMethod != NULL); /// Not sure if this is good or necessary
    
    /// Return
    return classInherits;
}

NSArray<Class> *getClassesFromFramework(NSString *frameworkNameNS) {
    
    /// Unused at the moment
    ///     - but might be useful if we want to support pre macOS 13.0
    assert(false);
    
    /// Trying to write cool confusing c code without comments 😎
    
    static NSMutableDictionary *_cache = nil;
    if (_cache == nil) {
        _cache = [NSMutableDictionary dictionary];
    }
    
    NSArray *resultFromCache = _cache[frameworkNameNS];
    if (resultFromCache != nil) {
        return resultFromCache;
    }
    
    bool frameworkIsSpecified = frameworkNameNS != nil && frameworkNameNS.length != 0;
    
    char *frameworkPathComponent = NULL;
    if (frameworkIsSpecified) {
        const char *frameworkName = [frameworkNameNS cStringUsingEncoding:NSUTF8StringEncoding];
        asprintf(&frameworkPathComponent, "/%s.framework/", frameworkName);
    }
    
    unsigned int count;
    Class *classes = objc_copyClassList(&count);
    
    NSMutableArray<Class> *result = [NSMutableArray array];
    
    for (int i = 0; i < count; i++) {
        
        Class class = classes[i];
        
        bool classIsInFramework = !frameworkIsSpecified || (strstr(class_getImageName(class), frameworkPathComponent) != NULL);
        
        if (classIsInFramework) {
            [result addObject:class];
        }
    }
    free(classes);
    
    _cache[frameworkNameNS] = result;
    
    return result;
}

#define MFRecursionCounterBaseKey @"MFRecursionCounterBaseKey"

NSMutableDictionary *_recursionCounterDict(void) {
    /// Get/init base dict
    NSMutableDictionary *counterDict = NSThread.currentThread.threadDictionary[MFRecursionCounterBaseKey];
    if (counterDict == nil) {
        counterDict = [NSMutableDictionary dictionary];
        NSThread.currentThread.threadDictionary[MFRecursionCounterBaseKey] = counterDict;
    }
    return counterDict;
}

NSInteger recursionCounterBegin(id key) {
    NSMutableDictionary *counterDict = _recursionCounterDict();
    NSInteger recursionDepth = [counterDict[key] integerValue]; /// This resolves to 0 if `counterDict[key]` is nil
    counterDict[key] = @(recursionDepth + 1);
    return recursionDepth;
    
}

void recursionCounterEnd(id key) {
    NSMutableDictionary *counterDict = _recursionCounterDict();
    NSInteger recursionDepth = [counterDict[key] integerValue];
    assert(recursionDepth > 0);
    counterDict[key] = @(recursionDepth - 1);
}

void countRecursions(id recursionDepthKey, void (^workload)(NSInteger recursionDepth)) {
    NSInteger depth = recursionCounterBegin(recursionDepthKey);
    workload(depth);
    recursionCounterEnd(recursionDepthKey);
}

void _recursionSwitch(id selfKey, SEL _cmdKey, void (^onFirstRecursion)(void), void (^onOtherRecursions)(void)) {
    
    assert(false);
    
    id key = stringf(@"%p|%s", selfKey, sel_getName(_cmdKey));
    
    countRecursions(key, ^(NSInteger recursionDepth) {
        if (recursionDepth == 0) {
            onFirstRecursion();
        } else {
            onOtherRecursions();
        }
    });
}

void BREAKPOINT(id context) { /// Be able to break inside c macros
    
}

NSString *pureString(id value) {
    
    /// Pass in an NSString or an NSAttributedString and get a simple NSString
    
    NSString *result = nil;
    
    if ([value isKindOfClass:[NSString class]]) {
        result = value;
    } else if ([value isKindOfClass:[NSAttributedString class]]) {
        result = [(NSAttributedString *)value string];
    } else if (value == nil) {
        result = nil;
    } else {
        assert(false);
    }
    
    return result;
}

NSString *typeNameFromEncoding(const char *typeEncoding) { /// Credit ChatGPT & Claude
    
    NSMutableString *typeName = [NSMutableString string];
    NSUInteger index = 0;
    
    /// Handle type qualifiers
    while (typeEncoding[index] && strchr("rnNoORV", typeEncoding[index])) {
        switch (typeEncoding[index]) {
            case 'r': [typeName appendString:@"const "]; break;
            case 'n': [typeName appendString:@"in "]; break;
            case 'N': [typeName appendString:@"inout "]; break;
            case 'o': [typeName appendString:@"out "]; break;
            case 'O': [typeName appendString:@"bycopy "]; break;
            case 'R': [typeName appendString:@"byref "]; break;
            case 'V': [typeName appendString:@"oneway "]; break;
        }
        index++;
    }
    
    /// Handle base type
    NSString *baseTypeName;
    switch (typeEncoding[index]) {
        case 'c': baseTypeName = @"char"; break;
        case 'i': baseTypeName = @"int"; break;
        case 's': baseTypeName = @"short"; break;
        case 'l': baseTypeName = @"long"; break;
        case 'q': baseTypeName = @"long long"; break;
        case 'C': baseTypeName = @"unsigned char"; break;
        case 'I': baseTypeName = @"unsigned int"; break;
        case 'S': baseTypeName = @"unsigned short"; break;
        case 'L': baseTypeName = @"unsigned long"; break;
        case 'Q': baseTypeName = @"unsigned long long"; break;
        case 'f': baseTypeName = @"float"; break;
        case 'd': baseTypeName = @"double"; break;
        case 'B': baseTypeName = @"bool"; break;
        case 'v': baseTypeName = @"void"; break;
        case '*': baseTypeName = @"char *"; break;
        case '@': baseTypeName = @"id"; break;
        case '#': baseTypeName = @"Class"; break;
        case ':': baseTypeName = @"SEL"; break;
        case '[': baseTypeName = @"array"; break;
        case '{': baseTypeName = @"struct"; break;
        case '(': baseTypeName = @"union"; break;
        case 'b': baseTypeName = @"bit field"; break;
        case '^': baseTypeName = @"pointer"; break;
        case '?': baseTypeName = @"unknown"; break;
        default:
            NSLog(@"typeEncoding: %s is unknown", typeEncoding);
            assert(false);
    }
    
    [typeName appendString:baseTypeName];
    
    /// Handle additional type information
    if (strlen(typeEncoding) > index + 1) {
        NSString *fullTypeEncoding = [NSString stringWithUTF8String:typeEncoding];
        return [NSString stringWithFormat:@"%@ [%@]", typeName, fullTypeEncoding];
    } else {
        return typeName;
    }
}

void listMethods(id obj) {
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList([obj class], &methodCount);
    
    NSLog(@"Methods for %@:", NSStringFromClass([obj class]));
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        char returnType[5000];
        method_getReturnType(method, returnType, 5000);
        unsigned int nOfArgs = method_getNumberOfArguments(method);
        NSMutableArray *argTypes = [NSMutableArray array];
        for (int i = 2; i < nOfArgs; i++) { /// Start at 2 to skip the `self` and `_cmd` args
            char argType[5000];
            method_getArgumentType(method, i, argType, 5000);
            [argTypes addObject:typeNameFromEncoding(argType)];
        }
        
        NSLog(@"(%@)%@ (%@)", typeNameFromEncoding(returnType), NSStringFromSelector(selector), [argTypes componentsJoinedByString:@", "]);
    }
    
    free(methods);
}

void printClassHierarchy(NSObject *obj) {
    
    /// Get the class of the object
    Class cls = object_getClass(obj);

    NSLog(@"Class hierarchy of object %@:", obj);
    while (cls) {
        NSLog(@"Class: %@", NSStringFromClass(cls));
        cls = class_getSuperclass(cls);  // Move to the superclass
    }
}

+ (NSObject <NSAccessibility> * _Nullable)getRepresentingAccessibilityElementForObject:(id)object {
    
    /// This function tries to to find the object that represents `object` in the accessibility hierarchy. This can be `object` itself or a related object.
    /// Explanation:
    /// Many Objects use an NSCell internally to draw content and also to handle accessibility stuff.
    /// In the accessibility hierarchy, only the NSCell will show up, the encapsulating view is 'represented' by it but doesn't appear in the accessibility hierarchy itself.
    /// The represented object itself will have its `isAccessibilityElement` property set to NO, and it will have one child - the NSCell,
    /// which has its `isAccessibilityElement` set to true - which makes it show up in the accessibility hierarchy.
    /// This function is made for this NSCell scenario, but might also work in other situations.

    
    /// Simple case
    if ([object respondsToSelector:@selector(isAccessibilityElement)] && [object isAccessibilityElement]) {
        return object;
    }
    
    /// Special cases
    if ([object isKindOfClass:[NSTableColumn class]]) {
        return [(NSTableColumn *)object headerCell];
    }
    if ([object isKindOfClass:objc_getClass("NSSegmentItemLabelCell")]) {
        id segmentItemLabelView = [(id)object controlView];
        object = segmentItemLabelView; /// We don't return here so this is handled by the if (NSSegmentItemLabelView) statement below.
    }
    if ([object isKindOfClass:objc_getClass("NSSegmentItemLabelView")]) {
        NSSegmentedCell *cell = [(id)[[(id)object superview] superview] cell];
        assert([cell respondsToSelector:@selector(isAccessibilityElement)] && [cell isAccessibilityElement]);
        return cell;
    }
    if ([object isKindOfClass:[NSTabViewItem class]]) {
        /// Get tabView
        ///     Each single tabViewButton is selectable in the Accessibility Inspector. It would be ideal to set our annotation to that.
        ///     But I can't find the corresponding elements in the view hierarchy or the accessibility hierarchy.
        ///     So we just assign the annotation to the tabView.
        NSTabView *tabView = [(NSTabViewItem *)object tabView];
        return tabView;
    }
    
    /// Default: Search childen
    NSArray *children = [object accessibilityChildren];
    for (NSObject<NSAccessibility> *child in children) {
        NSObject<NSAccessibility> *childRepresenter = [self getRepresentingAccessibilityElementForObject:child];
        if (childRepresenter != nil) {
            return childRepresenter;
        }
    }
    
    /// Nil return
    id axParent = [object accessibilityParent];
    NSLog(@"Error: Couldn't find accessibilityElement representing object %@. AXParent: %@", object, axParent);
    assert(false);
    return nil;
}

+ (NSObject *)getRepresentingToolTipHolderForObject:(NSObject *)object {
    
    /// For NSCells, return their controlView
    ///     -> Those hold the tooltips, while the cell holds all the other UIStrings.
    ///     -> Not sure making this a separate function makes any sense. I guess we wanted to make it symmetrical with `getRepresentingAccessibilityElementForObject:`, which is kind of the inverse of this method - on NSCells and their controlViews. 
    NSObject *result = nil;
    if ([object isKindOfClass:[NSCell class]]) {
        result = [(NSCell *)object controlView];
    }
    
    /// Fallback to the object itself
    if (result == nil) {
        result = object;
    }
    
    /// Return
    return result;
}



@end
