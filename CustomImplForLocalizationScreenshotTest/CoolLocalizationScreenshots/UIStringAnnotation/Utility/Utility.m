//
//  Utility.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 08.07.24.
//

#import "Utility.h"
@import ObjectiveC.runtime;


@implementation Utility

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
        NSLog(@"(%@)%@", typeNameFromEncoding(returnType), NSStringFromSelector(selector));
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

+ (NSObject <NSAccessibility>* _Nullable)getRepresentingAccessibilityElementForObject:(NSObject <NSAccessibility>*)object {
    
    /// This function tries to to find the object that represents `object` in the accessibility hierarchy. This can be `object` itself or a related object.
    /// Explanation:
    /// Many Objects use an NSCell internally to draw content and also to handle accessibility stuff.
    /// In the accessibility hierarchy, only the NSCell will show up, the encapsulating view is 'represented' by it but doesn't appear in the accessibility hierarchy itself.
    /// The represented object itself will have its `isAccessibilityElement` property set to NO, and it will have one child - the NSCell,
    /// which has its `isAccessibilityElement` set to true - which makes it show up in the accessibility hierarchy.
    /// This function is made for this NSCell scenario, but might also work in other situations.

    
    if ([object isAccessibilityElement]) {
        return object;
    }
    
    NSArray *children = [object accessibilityChildren];
    
    if (children.count == 1) {
        return [self getRepresentingAccessibilityElementForObject:children[0]];
    }
    
    return nil;
    
}

@end
