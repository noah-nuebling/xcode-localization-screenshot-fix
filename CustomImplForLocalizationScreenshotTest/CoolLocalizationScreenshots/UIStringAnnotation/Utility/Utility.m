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
#import "AppKitIntrospection.h"
#import "dlfcn.h"
#import "mach-o/dyld.h"
//#import "execinfo.h"

@implementation Utility

NSString *getExecutablePath(void) {
    
    /// Get the path of the current executable.
    
    static uint32_t pathBufferSize = MAXPATHLEN; /// Make this static to store between invocations. For optimization?
    char *pathBuffer = malloc(pathBufferSize); if (pathBuffer == NULL) return NULL; /// ChatGPT and SO tells me to NULL-check my malloc, and that not doing it is "unsafe" and "bad programming". I'm annoyed because that seems extremely unnecessary, but ok.
    int ret = _NSGetExecutablePath(pathBuffer, &pathBufferSize);
    
    if (ret == -1) { /// If the buffer size is not large enough, the buffer size is set to the right value and the function returns -1
        free(pathBuffer);
        pathBuffer = malloc(pathBufferSize); if (pathBuffer == NULL) return NULL;
        ret = _NSGetExecutablePath(pathBuffer, &pathBufferSize);
        if (ret == -1) {
            assert(false);
            return NULL;
        }
    }
    
    NSString *result = [NSString stringWithCString:pathBuffer encoding:NSUTF8StringEncoding];
    free(pathBuffer);
    
    return result;
}

NSString *getImagePath(void *address) {
    
    /// Get the image path of an address.
    /// For example when the address comes from the AppKit framework, the result will be
    ///     `@"/System/Library/Frameworks/AppKit.framework/AppKit"`
    /// Pass in the address of a function and compare the result to `getExecutablePath()` to see if the function is defined inside the current executable (and not by a framework or library.)
    
    Dl_info info;
    int ret = dladdr(address, &info);
    assert(ret != 0); /// 0 is failure code of dladrr()
    
    const char *imagePath = info.dli_fname;
    NSString *result = [NSString stringWithCString:imagePath encoding:NSUTF8StringEncoding];
    assert(result != nil);
    
    return result;
}

NSString *getSymbol(void *address) {
    
    Dl_info info;
    int ret = dladdr(address, &info);
    assert(ret != 0); /// 0 is failure code of dladrr()
    
    const char *symbolName = info.dli_sname;
    NSString *result = [NSString stringWithCString:symbolName encoding:NSUTF8StringEncoding];
    assert(result != nil);
    
    return result;
}


NSArray<Class> *searchClasses(NSDictionary<MFClassSearchCriterion, id> *criteria) {
    
    /// Validate
    assert([criteria isKindOfClass:[NSDictionary class]]);
    
    /// Extract criteria
    Protocol *protocol = criteria[MFClassSearchCriterionProtocol];
    Class baseClass = criteria[MFClassSearchCriterionSuperclass];
    NSString *namePrefixNS = criteria[MFClassSearchCriterionClassNamePrefix];
    NSString *frameworkNameNS = criteria[MFClassSearchCriterionFrameworkName];
    
    /// Map emptyString to nil
    if (namePrefixNS != nil && namePrefixNS.length == 0) {
        namePrefixNS = nil;
    }
    if (frameworkNameNS != nil && frameworkNameNS.length == 0) {
        frameworkNameNS = nil;
    }
    
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
    
    /// Preprocess namePrefix
    const char *namePrefix = NULL;
    if (namePrefixNS) {
        namePrefix = [namePrefixNS cStringUsingEncoding:NSUTF8StringEncoding];
    }
    
    /// Preprocess frameworkName
    ///     -> Get framwork paths
    
    unsigned int frameworkCount;
    const char **frameworkPaths = NULL;
    
    if (frameworkNameNS != nil) {
        const char *frameworkName = [frameworkNameNS cStringUsingEncoding:NSUTF8StringEncoding];
        const char *frameworkPath = searchFrameworkPath(frameworkName);
        frameworkPaths = malloc(sizeof(char *));
        *frameworkPaths = frameworkPath;
        frameworkCount = 1;
    } else {
        /// If the caller hasn't specified a framework, get *all* the frameworks.
        ///     There are 46977 classes in all the frameworks, but it's still quite fast, especially with the macOS 13.0+ implementation.
        frameworkPaths = objc_copyImageNames(&frameworkCount);
    }
    
    /// Get framework handles from framework paths
    void *frameworkHandles[frameworkCount];
    for (int i = 0; i < frameworkCount; i++) {
        const char *frameworkPath = frameworkPaths[i];
        frameworkHandles[i] = dlopen(frameworkPath, RTLD_LAZY | RTLD_GLOBAL); /// Maybe we could/should use `RTLD_NOLOAD` here for better performance?
        assert(frameworkHandles[i] != NULL);
    }
    
    /// Find classes
    NSMutableArray *result = [NSMutableArray array];
    
    for (int i = 0; i < frameworkCount; i++) {
        
        if (@available(macOS 13.0, *)) {
            objc_enumerateClasses(frameworkHandles[i], namePrefix, protocol, baseClass, ^(Class _Nonnull aClass, BOOL * _Nonnull stop){
                [result addObject:aClass];
            });
        } else {
            unsigned int classCount;
            const char **classNames = objc_copyClassNamesForImage(frameworkPaths[i], &classCount);
            for (int i = 0; i < classCount; i++) {
                Class class = objc_getClass(classNames[i]);
                bool hasNamePrefix      = namePrefix == NULL ? true :   strncmp(namePrefix, classNames[i], strlen(namePrefix)) == 0;
                bool conformsToProtocol = protocol == nil ? true :      class_conformsToProtocol(class, protocol);
                bool isSubclass         = baseClass == nil ? true :     classIsSubclass(class, baseClass) && class != baseClass; /// Filter out baseClass since that's how `objc_copyClassNamesForImage()` works.
                if (hasNamePrefix && conformsToProtocol && isSubclass) {
                    [result addObject:class];
                }
            }
        }
    }
    
    /// Release stuff
    free(frameworkPaths);
    for (int i = 0; i < frameworkCount; i++) {
        dlclose(frameworkHandles[i]);
    }
    
    /// Return
    return result;
}

const char *searchFrameworkPath(const char *frameworkName) {
    
    /// Can't get dlopen to find any frameworks without hardcoding the path, so we're making our own framework searcher
    /// 
    /// Update: I just found this in the dlopen docs which explains the problem: (our app was codesigned with entitlements.)
    ///   Note: If the main executable is a set[ug]id binary or codesigned with
    ///   entitlements, then all environment variables are ignored, and only a full
    ///   path can be used.
    
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
    
    /// Not sure this is even slower than the main approach. (If not then this should be the main approach) Should be more robust than the main approach though.
    
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
    
    if (result == NULL) {
        NSLog(@"Error: Couldn't find framework with name %@", frameworkName);
        assert(false);
    }
    return result;
    
}


bool classInheritsMethod(Class class, SEL selector) {
    
    /// Returns YES if the class inherits the method for `selector` from its superclass, instead of defining its own implementation.
    /// Note: Also see `class_copyMethodList`
    
    /// Main check
    Method classMethod = class_getInstanceMethod(class, selector);
    Method superclassMethod = class_getInstanceMethod(class_getSuperclass(class), selector);
    bool classInherits = classMethod == superclassMethod;
    
    /// ?
    assert(classMethod != NULL); /// Not sure if this is good or necessary
    
    /// Return
    return classInherits;
}

bool classIsSubclass(Class potentialSub, Class potentialSuper) {
    
    /// `isSubclassOfClass:` sometimes crashes. I think sending a message to the class might have sideeffects, so we're building a pure c implementation.
    /// This also returns true, if the two classes are the same (just like `isSubclassOfClass:`)
    
    while (true) {
            
        if (potentialSub == potentialSuper) {
            return true;
        }
        potentialSub = class_getSuperclass(potentialSub);
        
        if (potentialSub == NULL) {
            break;
        }
    }
    
    return false;
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

BOOL stringHasOnlyLocaleSharedContent(NSString *string) {
    
    /// Returns YES if the string only contains characters that are likely to be shared between different locales.
    
    /// Get char set
    ///     Note: Only considering letters non-locale-shared. All punctuation, digits etc. will be considered locale-shared.
    NSCharacterSet *localeDistinctCharacters = [NSCharacterSet letterCharacterSet];
    
    /// Search chars
    NSStringCompareOptions compareOptions = 0;
    NSRange localeDistinctCharacterRange = [string rangeOfCharacterFromSet:localeDistinctCharacters options:compareOptions range:NSMakeRange(0, string.length)];
    BOOL hasOnlyLocaleSharedCharacters = localeDistinctCharacterRange.location == NSNotFound;
    
    /// Return
    return hasOnlyLocaleSharedCharacters;
}

NSRegularExpression *formatSpecifierRegex(void) {
    
    /// Regex pattern that matches format specifiers such as %d in format strings.
    /// Notes:
    /// - \ and % are doubled to escape them.
    ///     Update: Removed doubling on % as I don't think that's necessary.
    /// - Matches escaped percent `%%` in a string inside the `escaped_percent` group.
    ///     The content of this group is **not** part of a format specifier, and needs to be filtered out by the client.
    /// - Based on this regex101 pattern: https://regex101.com/r/lu3nWp/
    ///     Not sure this was the best way to translate the pattern. We had to remove the `(?<groupnames>)` and add `(?#comments)` instead.
    
    NSString *pattern =
    @"%"
    "("
        "(?:((?#<argument_position>)[1-9]\\d*)\\$)?"
        "("
            /// Integer specifiers (d, i, o, u, x, X)
            "((?#<flags>)[-'+ #0]*)?"
            "((?#<width>)\\*|\\d*)?"
            "(?:\\.((?#<precision>)\\*|\\d+))?"
            "((?#<length>)(?:hh|h|l|ll|j|z|t|q))?"
            "((?#<type>)[diouxX])"
            "|"  /// Floating point specifiers (f, F, e, E, g, G, a, A)
            "((?#<flags>)[-'+ #0]*)?"
            "((?#<width>)\\*|\\d*)?"
            "(?:\\.((?#<precision>)\\*|\\d+))?"
            "((?#<length>)(?:l|L|q))?"
            "((?#<type>)[fFeEgGaA])"
            "|"  /// String specifiers (s, ls, S)
            "((?#<flags>)[-]?)?"
            "((?#<width>)\\*|\\d*)?"
            "(?:\\.((?#<precision>)\\*|\\d+))?"
            "((?#<type>)(?:s|ls|S))"
            "|"  /// Character specifiers (c, lc, C)
            "((?#<flags>)[-]?)?"
            "((?#<width>)\\*|\\d*)?"
            "((?#<type>)(?:c|lc|C))"
            "|"  /// Pointer specifier
            "((?#<flags>)[-]?)?"
            "((?#<width>)\\*|\\d*)?"
            "((?#<type>)[p])"
            "|"  /// objc object specifier
            "((?#<flags>)[-]?)?"
            "((?#<width>)\\*|\\d*)?"
            "((?#<type>)[@])"
            "|"  /// Written-byte counter specifier
            "((?#<type>)[n])"
        ")"
    ")"
    "|"  /// Percent sign (%%)
    "((?#<escaped_percent>)%%)";

    
    NSRegularExpressionOptions options = 0;
    NSError *error;
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
    if (error != nil) {
        NSLog(@"Failed to create formatSpeciferRegex. Error: %@", error);
        assert(false);
    }
    
    return regex;
}

NSRegularExpression *localizedStringRecognizer(NSString *localizedString) {
    
    /// Turn the localizedString into a matching pattern
    ///     By replacing format specifiers (e.g. `%d`) inside the localizedString with insertion point `.*?.
    ///     This matching mattern should match any ui strings that are composed of the localized string.
    NSRegularExpression *specifierRegex = formatSpecifierRegex();
    NSString *localizedStringPattern = [NSRegularExpression escapedPatternForString:localizedString];
    NSString *insertionPoint = [NSRegularExpression escapedTemplateForString:@"(.*?)"]; /// Escaping this doesn't seem to do anything.
    NSMatchingOptions matchingOptions = NSMatchingWithoutAnchoringBounds; /// Make $ and ^ work as normal chars.
    localizedStringPattern = [specifierRegex stringByReplacingMatchesInString:localizedStringPattern options:matchingOptions range:NSMakeRange(0, localizedString.length) withTemplate:insertionPoint];
    
    /// Make it so the pattern must match the entire string
    ///     and capture everything except the literal chars from the localizedString inside the insertionPoint groups.
    localizedStringPattern = [NSString stringWithFormat:@"^%@%@%@$", insertionPoint, localizedStringPattern, insertionPoint];
    
    /// TEST
    NSLog(@"%@", localizedStringPattern);
    
    
    /// Create regex
    ///     From new matching pattern
    NSRegularExpressionOptions regexOptions = NSRegularExpressionDotMatchesLineSeparators   /** Strings in insertion points might have linebreaks - still match those */
                                                | NSRegularExpressionCaseInsensitive        /** The localizedString might have been case-transformed - still match it */
                                                | NSRegularExpressionUseUnixLineSeparators; /** Turn off line separators from foreign platforms, since we're working with macOS localized strings. Not sure if necessary */
    NSError *error;
    NSRegularExpression *resultRegex = [NSRegularExpression regularExpressionWithPattern:localizedStringPattern options:regexOptions error:&error];
    if (error != nil) {
        NSLog(@"Failed to create recognizer regex for localized string %@. Error: %@", localizedString, error);
        assert(false);
    }
    
    /// Validate
    ///     Check that the regex needs at least some literal content to match. Not sure what I'm doing.
    assert([resultRegex firstMatchInString:@"" options:0 range:NSMakeRange(0, @"".length)] == nil);
    assert([resultRegex firstMatchInString:@" " options:0 range:NSMakeRange(0, @" ".length)] == nil);
    
    /// Return
    return resultRegex;
}

NSString *uiStringByRemovingLocalizedString(NSString *uiString, NSString *localizedString) {
    
    /// Get regex
    NSRegularExpression *localizedStringRegex = localizedStringRecognizer(localizedString);
    
    /// Apply regex
    
    NSTextCheckingResult *regexMatch;
    
    NSMatchingOptions matchingOptions = 0;
    NSArray<NSTextCheckingResult *> *regexMatches = [localizedStringRegex matchesInString:uiString options:matchingOptions range:NSMakeRange(0, uiString.length)];

    if (regexMatches.count == 1) {
        
        /// Validate
        ///     Make sure the match spans the entire string
        assert(NSEqualRanges([regexMatches[0] range], NSMakeRange(0, uiString.length)));
        /// Unwrap
        regexMatch = regexMatches[0];
        
    } else if (regexMatches.count == 0) {
        /// No matches - localizedString doesn't appear in uiString
        return uiString;
    } else {
        /// Validate
        ///     Make sure there's exactly one or zero matches.
        ///     The pattern is designed to always match the whole string so somethings really wrong if this happens.
        NSLog(@"Error: There was more than one regex for localizedString %@ in uiString %@ (regex: %@)", localizedString, uiString, localizedStringRegex);
        assert(false);
        return uiString;
    }
    
    /// The recorded string matched!
    
    /// Remove literally matched parts of the recorded localizedString from the uiString.
    /// Explanation:
    ///     When creating the `localizedStringRecognizer(localizedString)` regex,  we take the `localizedString` and put regex insertion points `.*` before, after and into the format specifiers (`%d, %@`) of the `localizedString`
    ///     Then, when we apply the `localizedStringRecognizer` regex to the `uiString` and it matches the `uiString`, then the insertion points `.*` match everything inside the `uiString` that comes before, or after the `localizedString`, as well as the parts of the `uiString` that were inserted into the the `localizedString` via format specifiers (`%d, %@`). So in effect, the insertion points capture every part of the `uiString` that isn't the content of the `localizedString`.
    ///     We surround the insertion points `.*` with parentheses `(.*)` which creates regex matching groups.
    ///     What we do here, is iterate through all the match groups and concatenating their contents - this has the effect of taking `uiString` and removing all text from it that came from `localizedString`.
    NSMutableString *result = [NSMutableString string];
    for (int i = 1; i < regexMatch.numberOfRanges; i++) { /// Start iterating at 1 since the 0 group is the whole matched string, not the groups inside of it.
        NSRange matchingGroupRange = [regexMatch rangeAtIndex:i];
        NSString *insertionPointMatch = [uiString substringWithRange:matchingGroupRange];
        [result appendString:insertionPointMatch];
    }
    return result;
}

NSString *removeMarkdownFormatting(NSString* input) {
    
    /// Convert Markdown to NSAttributedString
    NSAttributedStringMarkdownParsingOptions *options = [[NSAttributedStringMarkdownParsingOptions alloc] init];
    options.allowsExtendedAttributes = YES; /// Not sure whether to use this.
    options.interpretedSyntax = NSAttributedStringMarkdownInterpretedSyntaxFull;
    options.failurePolicy = NSAttributedStringMarkdownParsingFailureReturnError;
    options.languageCode = nil;

    NSError *error;
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithMarkdownString:input options:options baseURL:nil error:&error];
    
    if (error) {
        NSLog(@"Error parsing markdown: %@", error.localizedDescription);
        return input;
    }
    
    /// Extract plain text
    NSString *plainString = [attributedString string];
    
    return plainString;
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
        result = nil;
    }
    
    return result;
}

NSString *typeNameFromEncoding(const char *typeEncoding) { /// Credit ChatGPT & Claude
    
    NSMutableString *typeName = [NSMutableString string];
    NSUInteger index = 0;
    
    /// Handle type qualifiers
    while (typeEncoding[index] && strchr("rnNoORV^", typeEncoding[index])) {
        switch (typeEncoding[index]) {
            case 'r': [typeName appendString:@"const "]; break;
            case 'n': [typeName appendString:@"in "]; break;
            case 'N': [typeName appendString:@"inout "]; break;
            case 'o': [typeName appendString:@"out "]; break;
            case 'O': [typeName appendString:@"bycopy "]; break;
            case 'R': [typeName appendString:@"byref "]; break;
            case 'V': [typeName appendString:@"oneway "]; break;
            case '^': [typeName appendString:@"pointer "]; break;
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
        cls = class_getSuperclass(cls);  /// Move to the superclass
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
    
    /// Special case: NSTextStorage
    if ([object isKindOfClass:[NSTextStorage class]]) {
        NSTextStorage *textStorage = (id)object;
        assert([[textStorage textStorageObserver] isKindOfClass:[NSTextContentStorage class]]);
        NSTextContentStorage *textContentStorage = (id)[textStorage textStorageObserver];
        NSTextLayoutManager *textLayoutManager = [[textContentStorage textLayoutManagers] firstObject];
        NSTextContainer *textContainer = [textLayoutManager textContainer];
        NSTextView *textView = [textContainer textView];
        assert(textView != nil);
        return [self getRepresentingAccessibilityElementForObject:textView];
    }
    
    /// Special case: NSToolbar.
    if ([object isKindOfClass:[NSToolbarItem class]]) {
        NSToolbarItemViewer *itemViewer = [(NSToolbarItem *)object rawItemViewer];
        assert(itemViewer != NULL);
        if (![itemViewer isAccessibilityElement]) {
            return [(id)itemViewer accessibilityParent]; /// Some items viewers, e.g. flexibleSpaceItem are not ax elements themselves, so we use the parent (which is the toolbar itself from what I observed.)
        }
        return itemViewer;
    }
    
    /// Special case: NSTableView
    if ([object isKindOfClass:[NSTableColumn class]]) {
        return [(NSTableColumn *)object headerCell];
    }
    
    /// Special case: NSSegmentedControl items
    ///     This code is currently unused, because we simply attach the annotations for the segmented control items directly to their parent - the segmented control's cell.
    ///     The NSSegmentedCell has an accessibilityChild "mock element" for each of its segments. It would be better to attach our annotations for the segments directly to those.
    if ([object isKindOfClass:objc_getClass("NSSegmentItemLabelCell")]) {
        assert(false);
        id segmentItemLabelView = [(id)object controlView];
        object = segmentItemLabelView; /// We don't return here so this is handled by the if (NSSegmentItemLabelView) statement below.
    }
    if ([object isKindOfClass:objc_getClass("NSSegmentItemLabelView")]) {
        assert(false);
        NSSegmentedCell *cell = [(id)[[(id)object superview] superview] cell];
        assert([cell respondsToSelector:@selector(isAccessibilityElement)] && [cell isAccessibilityElement]);
        return cell;
    }
    
    /// Special case: NSTabView
    if ([object isKindOfClass:[NSTabViewItem class]]) {
        /// Get tabView
        ///     Each single tabViewButton is selectable in the Accessibility Inspector. It would be ideal to set our annotation to that.
        ///     But I can't find the corresponding elements in the view hierarchy or the accessibility hierarchy.
        ///     So we just assign the annotation to the tabView.
        NSTabView *tabView = [(NSTabViewItem *)object tabView];
        return tabView;
    }
    
    /// Special case: NSTouchBarItem
    ///     (Does it really make sense to handle touchbar stuff? It seems pretty
    ///     obsolete and and totally irrelevant for MMF and I don't know if localizationScreenshots will even work)
    if ([object isKindOfClass:[NSTouchBarItem class]]) {
        NSView *view = [(NSTouchBarItem *)object view];
        return [self getRepresentingAccessibilityElementForObject:view];
    }
    
    /// Default: Search childen
    ///     This will find the NSCell of an NSControl.
    NSArray *children = [object accessibilityChildren];
    for (NSObject<NSAccessibility> *child in children) {
        NSObject<NSAccessibility> *childRepresenter = [self getRepresentingAccessibilityElementForObject:child];
        if (childRepresenter != nil) {
            return childRepresenter; /// When there are multiple ax children we just take the first one which might be problematic? But works so far. 
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
    
    /// Special case: comboButton
    if ([result isKindOfClass:objc_getClass("NSComboButtonSegmentedControl")]) {
        result = [(NSControl *)result superview];
    }
    
    /// Fallback to the object itself
    if (result == nil) {
        result = object;
    }
    
    /// Return
    return result;
}



@end
