//
//  NibDecodingAnalyzer.h
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 08.07.24.
//

@import ObjectiveC.runtime;
#import "NibDecodingAnalysis.h"
#import "AppKit/NSAccessibility.h"
#import "AppKit/NSMenu.h"
#import "NSLocalizedStringRecord.h"
#import "AnnotationUtility.h"
#import "UINibDecoderIntrospection.h"
#import "Utility.h"
#import "TreeNode.h"
#import "KVPair.h"
#import "NSString+Additions.h"
#import "SystemRenameTracker.h"
#import "AppKitIntrospection.h"

#pragma mark - Overview

///
/// Overview:
///
/// This code intercepts loading of nib files and and annotates the loaded uiElements with the localizationKeys for the uiStrings that appear in the respective uiElement.
/// These annotations are published through the accessibility API, so you can see them with Accessibility Inspector or with XCUI tests.
///
///

#pragma mark - Track depth

/**
 
 We want to swizzle the nibLoading methods that AppKit uses to load the UI from our IB files, so that we can turn off the CodeAnnotation logic so it doesn't interfere with the NibAnnotation logic.
 
 At the top-level, inside NSApplicationMain, AppKit seems to call `+loadNibNamed:owner:`, even though that has been deprecated, then this method  calls
 `-loadNibNamed:owner:topLevelObjects:` or `+-loadNibFile:externalNameTable:withZone:` (Not sure if + or - since I haven't observed this invocation)
 For now I think it should be sufficient to only swizzle `-loadNibNamed:owner:topLevelObjects:` since that seems to be where all the work takes place and what we'll
 use to instantiate Nib files in our own code (since it's the only one that's not deprecated.)
 Update: `-loadNibNamed:owner:topLevelObjects:` does not seem to be sufficient. UIStringChangeDecector still detects lots of string changes before `applicationDidFinishLaunching:` that we don't recognize as part of Nib loading (yet)
 
 Reference:
 
     Modern API:
         ```
         -loadNibNamed:owner:topLevelObjects:
         ```
     
     Deprecated APIs:
         ```
         +loadNibFile:externalNameTable:withZone:
         +loadNibNamed:owner:
         -loadNibFile:externalNameTable:withZone:
         ```
 */

///
/// DecodingDepth defines
///

#define MFLoadNibDepthKey @"MFLoadNibDepth"

NSInteger MFLoadNibDepth(void) {
    return [NSThread.currentThread.threadDictionary[MFLoadNibDepthKey] integerValue];
}
static void MFLoadNibDepthIncrement(void) {
    NSInteger d = MFLoadNibDepth() + 1;
    NSThread.currentThread.threadDictionary[MFLoadNibDepthKey] = @(d);
}
static void MFLoadNibDepthDecrement(void) {
    NSInteger d = MFLoadNibDepth() - 1;
    assert(d >= 0);
    NSThread.currentThread.threadDictionary[MFLoadNibDepthKey] = @(d);
}

BOOL MFIsLoadingNib(void) {
    return MFLoadNibDepth() > 0;
}

#define MFNibDecoderDepthKey @"MFNibDecoderDepth"

NSInteger MFNibDecoderDepth(void) {
    return [NSThread.currentThread.threadDictionary[MFNibDecoderDepthKey] integerValue];
}
static void MFNibDecoderDepthIncrement(void) { /// We could probably just use our `countRecursions()` function instead of all these `depthIncrement()`, `depthDecrement()` functions.
    NSInteger d = MFNibDecoderDepth() + 1;
    NSThread.currentThread.threadDictionary[MFNibDecoderDepthKey] = @(d);
}
static void MFNibDecoderDepthDecrement(void) {
    NSInteger d = MFNibDecoderDepth() - 1;
    assert(d >= 0);
    NSThread.currentThread.threadDictionary[MFNibDecoderDepthKey] = @(d);
}

#pragma mark - DecoderRecord storage

/// Notes:
/// This being global is weird and not thread safe but I'm pretty sure all this NibDecoding stuff only happens on the main thread anyways.

/// Decoder record
static NSMutableArray<NSMutableDictionary *>*_nibDecoderRecordStorage = nil;     /// This is filled up as the NibDecoder recurses in the object-tree of an Nib file.
static NSMutableArray<NSMutableDictionary *>* nibDecoderRecord(void) {
    if (_nibDecoderRecordStorage == nil) _nibDecoderRecordStorage = [NSMutableArray array];
    return _nibDecoderRecordStorage;
}

/// Top level objects
static NSArray *_nibDecoderRecordTopLevelObjects = nil;                   /// These are returned by `NSNBundle loadNib...:` after the NibDecoder finishes.

/// Delete storage
static void deleteNibDecoderRecord(void) {
    _nibDecoderRecordStorage = nil;
    _nibDecoderRecordTopLevelObjects = nil;
}

#pragma mark - Forward declares

@interface Annotator : NSObject
+ (void)annotateUIElementsWithDecoderRecord:(NSArray *)decoderRecord topLevelObjects:(NSArray *)topLevelObjects;
@end

#pragma mark - NSBundle swizzling


@implementation NSBundle (MFNibAnnotation)

+ (void)load {
    
    swizzleMethod([self class], @selector(loadNibNamed:owner:topLevelObjects:), MakeInterceptorFactory(BOOL, (NSNibName nibName, id owner, NSArray * _Nullable __autoreleasing *topLevelObjects), {
        preDive();
        BOOL result = OGImpl(nibName, owner, topLevelObjects);
        assert(_nibDecoderRecordTopLevelObjects == nil);
        if (topLevelObjects != nil && *topLevelObjects != nil) {
            _nibDecoderRecordTopLevelObjects = *topLevelObjects;
        }
        postDive(nibName, nil);
        return result;
    }));
    
    swizzleMethod([self class], @selector(loadNibFile:externalNameTable:withZone:), MakeInterceptorFactory(BOOL, (NSString *fileName, NSDictionary *context, NSZone *zone), {
        preDive();
        BOOL result = OGImpl(fileName, context, zone);
        postDive(nil, fileName);
        return result;
    }));
    
    swizzleMethod(object_getClass([self class]), @selector(loadNibNamed:owner:), MakeInterceptorFactory(BOOL, (NSString *nibName, id owner), {
        preDive();
        BOOL result = OGImpl(nibName, owner);
        postDive(nibName, nil);
        return result;
    }));
    swizzleMethod(object_getClass([self class]), @selector(loadNibFile:externalNameTable:withZone:), MakeInterceptorFactory(BOOL, (NSString *fileName, NSDictionary *context, NSZone *zone), {
        preDive();
        BOOL result = OGImpl(fileName, context, zone);
        postDive(nil, fileName);
        return result;
    }));
    
}

static void preDive(void) {
    
    /// Determine isTopLevel
    BOOL isTopLevel = MFLoadNibDepth() == 0;

    if (isTopLevel) {
        /// Create fresh record (delete its content)
        deleteNibDecoderRecord();
    }
    
    /// Increase depth
    MFLoadNibDepthIncrement();
}

static void postDive(NSString *nibName, NSString *fileName) {
    
    /// Decrease depth
    MFLoadNibDepthDecrement();
    
    /// Handle topLevel
    BOOL isTopLevel = MFLoadNibDepth() == 0;
    if (isTopLevel) {
        
        /// Check if we own the bundle
        ///     The reason for this code is that when you open the menu bar the system loads a bundle named "SearchMenu2", which we want to ignore and which crashes our Annotator code
        NSString *bundleName = nibName != nil ? nibName : fileName;
        BOOL isOurBundle = [NSBundle.mainBundle pathForResource:bundleName ofType:@"nib"] != nil; /// Should we use the `forLocalization:` arg?
        
        /// Process record
        ///     Only if it's our bundle -> it's inefficient that we create the record in the first place if it's not our bundle. But efficiency doesn't matter here since we just run this code for localization screenshots.
        if (isOurBundle) {
            [Annotator annotateUIElementsWithDecoderRecord:nibDecoderRecord() topLevelObjects:_nibDecoderRecordTopLevelObjects];
        }
        
        /// Delete NSLocalizedStringRecord
        ///     We only use the NSLocalizedStringRecord for our CodeAnnotation anyways, but the Nib decoding will clutter it up.
        ///     It's inefficient that we're creating the NSLocalizedString record during NibDecoding.
        [NSLocalizedStringRecord.queue._rawStorage removeAllObjects];
        [NSLocalizedStringRecord.systemQueue._rawStorage removeAllObjects];
        
        /// Validate
        assert(MFNibDecoderDepth() == 0 && MFLoadNibDepth() == 0);
    }

}

@end

#pragma mark - NSCoder swizzling

/// Discussion:
///     What we want to do is decode the internal structure of a nib file. Then we can search the internal structure to find the localizationKeys and the objects that they are attached to, and use this to annotation the UIElements loaded from the Nib file with their respective localization keys.
///
/// How do we decode the nib file structure:
///     It is known that, as the UI is being load from a Nib file, `initWithCoder:` is being called to create the objects.
///     Then inside of `initWithCoder:` the object uses keys to load data from the coder, which the object then initializes its properties and instance variables with.
///     The object usuallly uses `[coder decodeObjectForKey:]` to get values from the coder. (There's also other getters such as `decodeFloatForKey:` but we've been doing fine just ignoring all those.)
///     `decodeObjectForKey:` seems to be called for all the objects in the object-tree of the nib file in depth-first order. If we swizzle that and add a recursion-counter,
///     we can create a list of all the visited nodes - containing the decoded object and its key, as well as the node's depth in the tree.
///     Then we use that list to recreate the structure of the object-tree in  the nib file (using our `TreeNode` datastructure) and then we can traverse our  tree and find all of the localization keys - and the objects that the keys belong to.
///
///     Notes:
///     - We also tried to directly analyze the NSCoder instance, but it has a weird 'scoping' mechanism - whenever `[coder decodeObjectForKey:]` is called to decode a child-node of the current node,
///         it seems that the whole coder gets put into a new state where it now only responds to the keys used inside the child. I couldn't figure out how to manually change the 'scope' of the coder to traverse its entire hierarchy.
///         So just swizzling the entire decoding process was the best option I could think of.
///     - AppKit seemed to always use UINibDecoder to decode the nib file, but then I made some changes to the nib file, (in the commit after 0cb9ed70265ae44fea703d303dd55b30af627fe1) and all of a sudden,
///         it started using NSKeyedUnarchiver instead. These are both NSCoder subclasses, though, so if we just swizzle all NSCoder subclasses, we should be fine.
///

@implementation NSCoder (MFNibAnnotation)

+ (void)load {
    
    /// TODO: Only swizzle, when some special 'Take Localization Screenshots' flag is set - for performance.
    
    swizzleMethodOnClassAndSubclasses([NSCoder class], @{ @"framework": @"" }, @selector(decodeObjectForKey:), MakeInterceptorFactory(id, (NSString *key), {
    
        /// Note:
        ///     We're not specifying a framework since UINibDecoder is in UIFoundation.framework while NSKeyedUnarchiver is in Foundation.framework. Maybe we should allow specifying a list of frameworks. But this is fast enough for now.
        
        /// Skip
        if (!MFIsLoadingNib()) {
            return OGImpl(key);
        }
        
        /// Increase depth
        MFNibDecoderDepthIncrement();
        
        /// Call original implementation
        /// Notes:
        /// - This will recursively call this method over and over for all the child objects.
        id result = OGImpl(key);
        
        /// Decrease depth
        MFNibDecoderDepthDecrement();
        
        /// Record
        [nibDecoderRecord() addObject:@{
            @"key": key,
            @"value": result != nil ? result : NSNull.null,
            @"depth": @(MFNibDecoderDepth()),
        }.mutableCopy];
        
        /// Return
        return result;
    }));
}

@end


#pragma mark - Process DecoderRecord

///
/// The code here is pretty convoluted-looking with all the special cases.
/// But to write this we basically just looked at where the NSLocalizedStrings appear in the tree (whereever there's an `NSKey` node)
/// and then we looked at how to get from the localizedString node to the node of the uiElement where the localizedString is used.
/// The we used this knowledge to attach an `annotation` for each localizedString to the uiElement where the localizedString appears.
/// These annotations are NSAccessibilityElements and can be inspected with the `Accessibility Inspector` app.
///
/// Rambling on NibDecoder caching:
///     I think the pattern for finding the object that a localized string belongs to can be a little bit chaotic because the decoder only creates a single
///     node for each localized string. If the localized string is used again in a different context, the decoder will (I think) use a cache instead of
///     decoding the element again, and in our tree the localized string won't appear again.
///     For example, when a popup button in IB has selected one of its items, the popup button will display the localizedString of the selected item
///     as its own uiString. When this is the case, the localizedString will be decoded and attached as a child node of the popup button, but the
///     uiString won't appear a second time as a child of the NSMenu inside the popupButton.
///
///     Aside from this, the pattern of where localizedStrings - and the uiElements they belong to - appear in the tree, is relatively consistent.
///     Just print the tree.description to explore its structure.
///

@implementation Annotator: NSObject

+ (void)annotateUIElementsWithDecoderRecord:(NSArray *)decoderRecord topLevelObjects:(NSArray *)topLevelObjects {
    
    ///
    /// Define helper blocks
    ///
    
    /// Define reusable loc-string-extractor
    
    typedef void (^LocalizationKeyExtractorCallback)(NSString *localizationKey, NSString *developmentString, NSString *uiString, NSString *uiStringNibKey);
    void (^unpackLocalizationKeyData)(NSDictionary *, LocalizationKeyExtractorCallback) = ^(NSDictionary *localizationKeyData, LocalizationKeyExtractorCallback callback) {
        
        if (!callback) assert(false);
        
        NSString *locKey = localizationKeyData[@"NSKey"];
        NSString *devStr = localizationKeyData[@"NSDev"] ?: NSNull.null;
        NSString *transStr = localizationKeyData[@"NSDevSuccessor"][@"value"] ?: NSNull.null;
        NSString *transStrKey = localizationKeyData[@"NSDevSuccessor"][@"key"] ?: NSNull.null;
        
        callback(locKey, devStr, transStr, transStrKey);
    };
    
    /// Define annotationQueueCleaner
    
    void (^cleanOutAnnotationQueueAndValidate)(NSArray *) = ^(NSArray *lastLocalizationKeys) {
        
        /// Explanation:
        ///  NSLocalizedStringRecord.queue is made to track localizationKey usage in code (as opposed to localizationKey usage in IB files, which is handled right here),
        ///  However, as the decoder decodes the NIB file, it will call `NSBundle -localizedStringForKey:value:table:` to get translated strings.
        ///  Due to our swizzling, this will also fill up NSLocalizedStringRecord.queue.
        ///  So what we do here is we empty out the NSLocalizedStringRecord.queue so that it is empty and then we can start using .queue to track NSLocalizedString() usage
        ///  We also take this opportunity to validate our logic.
        ///
        ///  Update:
        ///  - We're now just deleting the NSLocalizedStringRecord after the nib decoding is done.
        ///  - The validation doesn't work anymore since we're now loading the decoder record into a tree and traversing it in a different order.
        
        assert(false);
        return;
        
        for (NSDictionary *localizationKeyData in lastLocalizationKeys) {
            unpackLocalizationKeyData(localizationKeyData, ^(NSString *localizationKey, NSString *developmentString, NSString *uiString, NSString *uiStringNibKey) {
                NSDictionary *fromQueue = [NSLocalizedStringRecord.queue dequeue];
                assert(fromQueue != nil);
                assert([localizationKey isEqual:fromQueue[@"key"]]);
                assert([developmentString isEqual:fromQueue[@"value"]]);
                assert(YES || [@"abcdefg" isEqual: fromQueue[@"table"]]); /// Not sure if / how we could validate the table. Should be equal to the filename of the archive that we're decoding?
            });
        }
    };

    
    ///
    /// Main logic
    ///
    
    /// Validate
    assert(true || topLevelObjects != nil && topLevelObjects.count > 0);
    assert(decoderRecord != nil && decoderRecord.count > 0);
    
    /// Transform decoder record into a tree
    TreeNode<KVPair *> *treeRoot = [self treeFromDecoderRecord:decoderRecord];
    NSArray *treeNodes = [treeRoot.depthFirstEnumerator allObjects];
    
    /// Validate
    assert(treeNodes.count == decoderRecord.count);
    
    /// Print
    NSLog(@"-------------------");
    printf("%s", [[NSString stringWithFormat:@"LocStrings: SWOOOZLE, %@\n%@", topLevelObjects, treeRoot] cStringUsingEncoding:NSUTF8StringEncoding]); /// Need to use printf since NSLog truncates the output.
    
    /// Declare state for validation
    ///     Of the following loop
    BOOL validation_lastLocalizedStringWasNotUsed = NO;
    TreeNode<KVPair *> *validation_lastNode = nil;
    
    for (TreeNode<KVPair *> *node in treeNodes) {
        
        /// Validate
        assert([node.representedObject isKindOfClass:[KVPair class]]);
        if (validation_lastLocalizedStringWasNotUsed) {
            NSLog(@"NibAnnotation: Error: No annotation created for localized string:\n%@", validation_lastNode.parentNode.description);
            assert(false);
            validation_lastLocalizedStringWasNotUsed = NO; /// Prevent the error from being printed repeatedly for the same string
        }
        
        /// Only look at NSKey elements
        ///     NSKey elements hold localizationKeys
        if (![node.representedObject.key isEqual: @"NSKey"]) continue;
        
        /// Set validation state
        validation_lastLocalizedStringWasNotUsed = YES;
        validation_lastNode = node;
        
        /// Gather values
        NSString *localizationKey = node.representedObject.value;
        NSString *developmentString = node.siblings[1].representedObject.value;
        NSString *developmentStringNibKey = node.siblings[1].representedObject.key;
        NSString *uiString = node.parentNode.representedObject.value;
        NSString *uiStringNibKey = node.parentNode.representedObject.key;
        
        /// Validate
        assert([developmentStringNibKey isEqual:@"NSDev"]);
        for (id str in @[localizationKey, developmentString, developmentStringNibKey, uiString, uiStringNibKey]) {
            assert([str isKindOfClass:[NSString class]]);
        }
        
        /// Unused: Skip keys for entries that link elsewhere
        ///     Not sure we need this anymore now with the new tree structure.
        ///
        /// `if ([key isEqual: @"NSSuperview"] || [key isEqual: @"NSNextResponder"] || [key isEqual: @"NSNextKeyView"] || [key isEqual: @"NSSubviews"]) { ... }`
        ///
        
        if ([uiStringNibKey isEqual:@"NSMarker"]) {
            
            /// 
            /// Special case: NSMarker
            ///
            
            /// -> Find the view for the NSMarker through the NSConnections array
            /// Note:
            ///     The NSMarker key appears for tooltip-strings. (Maybe also elsewhere but I've only seen it on tooltips)
            
            /// Find NSConnections array
            NSArray *connections = nil;
            for (TreeNode<KVPair *> *topLevelNode in treeRoot.childNodes) {
                if ([topLevelNode.representedObject.key isEqual:@"NSConnections"]) {
                    connections = topLevelNode.representedObject.value;
                    break;
                }
            }
            assert(connections != nil);
                
            
            /// Find help-connections
            NSMutableArray <NSIBHelpConnector *>*helpConnections = [NSMutableArray array];
            for (NSIBHelpConnector *connection in connections) {
                if ([connection isKindOfClass:[NSIBHelpConnector class]]) {
                    [helpConnections addObject:connection];
                }
            }
            
            /// Find help connector for our localizedString
            NSIBHelpConnector *matchingConnector = nil;
            for (NSIBHelpConnector *connector in helpConnections) {
                NSString *connectionMarker = [connector marker];
                if (connectionMarker == uiString) { /// Note that were using == so we're checking pointer-level equality on an NSString
                    matchingConnector = connector;
                    break;
                }
            }
            assert(matchingConnector != nil);
            
            /// Extract info from matchingConnector
            NSObject<NSAccessibility>*connectionDestination = (id)[matchingConnector destination];
            NSObject<NSAccessibility>*axConnectionDestination = [AnnotationUtility getRepresentingAccessibilityElementForObject:connectionDestination];
        
            if (axConnectionDestination == nil) {
                
                /// Error
                NSLog(@"The tooltip %@: %@ is attached to the ui element %@, but the ui element doesn't seem to have a representation in the accessibility hierarchy. Due to this, we can't annotate the ui element with the localizedStringKey for its toolip. To solve this, remove the tooltip or represent the ui element in the accessibility hierarchy. To represent the element, set the `- isAccessibilityElement` property to true on the ui element itself or on one of its subviews.", localizationKey, uiString, connectionDestination);
                assert(false);
                
            } else {

                /// Add annotation
                NSAccessibilityElement *annotation = [AnnotationUtility createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
                [AnnotationUtility addAnnotations:@[annotation] toAccessibilityElement:axConnectionDestination];
                /// Flag
                validation_lastLocalizedStringWasNotUsed = NO;
            }
            
        } else if ([uiStringNibKey isEqual:@"AXAttributeValueArchiveKey"]) {
            
            ///
            /// Special case: Localizable Accessibility values
            ///
            
            /// -> Values that only show up in assistive apps like voice over, but are still settable in
            ///     IB and are localizable.
            ///     We might be going overboard with this.
            
            /// Find NSAccessibilityConnectors
            NSArray *accessibilityConnectors = nil;
            for (TreeNode<KVPair *> *topLevelNode in treeRoot.childNodes) {
                if ([topLevelNode.representedObject.key isEqual:@"NSAccessibilityConnectors"]) {
                    accessibilityConnectors = topLevelNode.representedObject.value;
                    break;
                }
            }
            assert(accessibilityConnectors != nil);
            
            /// Find matching connector
            NSNibAXAttributeConnector *matchingConnector = nil;
            for (id connector in accessibilityConnectors) {
                if ([connector isKindOfClass:[NSNibAXAttributeConnector class]]) {
                    NSString *attributeValue = [(NSNibAXAttributeConnector *)connector attributeValue];
                    if ([attributeValue isEqual:uiString]) {
                        matchingConnector = connector;
                        break;
                    }
                }
            }
            assert(matchingConnector != nil);
            
            /// Get destination
            id destination = [matchingConnector destination];
            id axDestination = [AnnotationUtility getRepresentingAccessibilityElementForObject:destination];
            
            /// Annotate the destination of the connector
            NSAccessibilityElement *annotation = [AnnotationUtility createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
            [AnnotationUtility addAnnotations:@[annotation] toAccessibilityElement:axDestination];
            
            /// Flag
            validation_lastLocalizedStringWasNotUsed = NO;
            
        } else if ([uiStringNibKey isEqual: @"NSWindowTitle"] || [uiStringNibKey isEqual: @"NSWindowSubtitle"]) {
            
            ///
            /// Special case: NSWindowTitle & NSWindowSubtitle
            ///
            
            /// -> The windows don't seem to be part of the decoderRecord tree. Instead there are `NSWindowTemplate` objects, but I couldn't use them.
            /// -> So instead, we find the windows in the topLevelObjects
            ///     and annotate it with the localizationKey for its title/subtitle.
            
            /// Find windowView
            
            NSView *windowView = nil;
            for (TreeNode<KVPair *> *siblingNode in node.parentNode.siblingEnumeratorForward) {
                if ([siblingNode.representedObject.key isEqual:@"NSWindowView"]) {
                    windowView = siblingNode.representedObject.value;
                    break;
                }
            }
            assert(windowView != nil);
            
            /// Find windows in topLevelObjects
            ///     Sidenote: The decoderRecord doesn't seem to contain a reference to an NSWindow instance. But there's a
            ///     `NSVisibleWindows` key in the decoderRecord, which contains `NSWindowTemplate` objects. We managed to
            ///     extract a ref to the to the windows' contentView and the window's title but then we didn't pursue that approach further.
            
            NSMutableArray *windows = [NSMutableArray array];
            for (NSObject *object in topLevelObjects) {
                if ([object isKindOfClass:[NSWindow class]]) {
                    [windows addObject:object];
                }
            }
            assert(windows.count >= 1);
            
            /// Find window for windowView
            NSWindow *matchingWindow = nil;
            for (NSWindow *window in windows) {
                if ([window.contentView isEqual:windowView]) {
                    matchingWindow = window;
                    break;
                }
            }
            
            /// Annotate the window
            NSAccessibilityElement *annotation = [AnnotationUtility createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
            [AnnotationUtility addAnnotations:@[annotation] toAccessibilityElement:matchingWindow];
            
            /// Flag
            validation_lastLocalizedStringWasNotUsed = NO;
            
        } else if ([uiStringNibKey isEqual:@"NSHeaderToolTip"]) {
            
            ///
            /// Special case: NSTableViewColumn headerTooltip
            ///
            
            /// Find NSTableColumns in parents.
            NSArray <NSTableColumn *>* tableColumns = nil;
            for (TreeNode<KVPair *> *parentNode in node.parentEnumerator) {
                if ([parentNode.representedObject.key isEqual:@"NSTableColumns"]) {
                    tableColumns = parentNode.representedObject.value;
                    break;
                }
            }
            
            /// Find matching NSTableColumn
            NSTableColumn *matchingColumn = nil;
            for (NSTableColumn *column in tableColumns) {
                if ([column.headerToolTip isEqual:uiString]) {
                    matchingColumn = column;
                    break;
                }
            }
            
            /// Get the axElement representing the column
            NSTableHeaderCell *matchingHeaderCell = (id)[AnnotationUtility getRepresentingAccessibilityElementForObject:matchingColumn];
            
            /// Attach annotation
            NSAccessibilityElement *annotation = [AnnotationUtility createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
            [AnnotationUtility addAnnotations:@[annotation] toAccessibilityElement:matchingHeaderCell withAdditionalUIStringHolder:matchingColumn];
            
            /// Flag
            validation_lastLocalizedStringWasNotUsed = NO;
            
        } else {
            
            ///
            /// Default behaviour
            ///
            
            /// -> Iterate closeby nodes and attach to first adequate node we find.
            
            /// Search
            for (TreeNode<KVPair *> *relatedNode in node.parentEnumerator) { /// Search parents
                
                if ([relatedNode.representedObject.key isEqual:@"NSObjectsKeys"]) {
                    
                    /// Special case: NSObjectsKeys
                    /// -> If we find `NSObjectsKeys`, then the `uiString` seems to be the title of the NSMenu for our applications' menuBar.
                    ///     I don't understand why this works, I hope it's robust.
                    
                    /// Find main menu
                    NSMenu *mainMenu = nil;
                    for (id topLevelObject in topLevelObjects) {
                        if ([topLevelObject isKindOfClass:[NSMenu class]]) {
                            mainMenu = topLevelObject;
                            break;
                        }
                    }
                    assert(mainMenu != nil);
                    
                    /// Attach to mainMenu
                    
                    /// Create annotation
                    NSAccessibilityElement *annotation =
                    [AnnotationUtility createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
                    [AnnotationUtility addAnnotations:@[annotation] toAccessibilityElement:mainMenu];
                    
                    /// Flag
                    validation_lastLocalizedStringWasNotUsed = NO;
                    /// Stop iterating related nodes
                    break;
                }
                
                /// Special case: NSTabViewItems
                
                if ([relatedNode.representedObject.key isEqual:@"NSTabViewItems"]) {
                    
                    NSTabViewItem *matchingItem = nil;
                    for (NSTabViewItem *item in relatedNode.representedObject.value) {
                        if ([item.label isEqual:uiString] || [item.toolTip isEqual:uiString]) {
                            matchingItem = item;
                            break;
                        }
                    }
                    assert(matchingItem != nil);
                    
                    id axElement = [AnnotationUtility getRepresentingAccessibilityElementForObject:matchingItem];
                    NSAccessibilityElement *annotation = [AnnotationUtility createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
                    [AnnotationUtility addAnnotations:@[annotation] toAccessibilityElement:axElement];
                    
                    /// Flag
                    validation_lastLocalizedStringWasNotUsed = NO;
                    /// Stop iterating relatedNodes
                    break;
                    
                }
                
                /// Special case: NSToolbar
                
                if ([relatedNode.representedObject.value isKindOfClass:[NSToolbar class]]) {
                    
                    NSToolbar *toolbar = relatedNode.representedObject.value;
                    
                    /// Find item to annotate
                    NSToolbarItemViewer *matchingAXItem = nil;
                    for (NSToolbarItem *item in toolbar.items) {
                        id axItem = [AnnotationUtility getRepresentingAccessibilityElementForObject:item];
                        BOOL containsUIString = [AnnotationUtility accessibilityElement:axItem containsUIString:uiString];
                        if (containsUIString) {
                             matchingAXItem = axItem;
                            break;
                        }
                    }
                    assert(matchingAXItem != nil);
                    
                    /// Add annotation
                    NSAccessibilityElement *annotationElement = [AnnotationUtility createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
                    [AnnotationUtility addAnnotations:@[annotationElement] toAccessibilityElement:matchingAXItem]; /// The `find item to annotate` code above already serves as validation, so we might skip the validation that's happening in here?
                    /// Flag
                    validation_lastLocalizedStringWasNotUsed = NO;
                    /// Stop iterating relatedNodes
                    break;
                }
                
                /// Special case: NSMenu & NSMenuItem
                ///     -> If we find an `NSMenu` or an array with key `NSMenuItems` then the `uiString`
                ///         seems to belong to one of the NSMenuItems inside the object we found.
                ///         (Or the `uiString` is the title of the `NSMenu` itself.)
                
                /// Check isMenu
                BOOL isNSMenu = [relatedNode.representedObject.value isKindOfClass:[NSMenu class]];
                BOOL isNSMenuItemsArray = [relatedNode.representedObject.key isEqual:@"NSMenuItems"];
                
                if (isNSMenu || isNSMenuItemsArray) {
                    
                    /// Get itemArray
                    NSArray<NSMenuItem *> *items = nil;
                    if (isNSMenu) {
                        items = [(NSMenu *)relatedNode.representedObject.value itemArray];
                    } else if (isNSMenuItemsArray) {
                        items = relatedNode.representedObject.value;
                    }
                    
                    /// Find item to annotate
                    NSMenuItem *matchingItem = nil;
                    for (NSMenuItem *item in items) {
                        if ([item.title isEqual:uiString]) {
                            matchingItem = item;
                            break;
                        }
                    }
                    
                    /// Fall back: System renames
                    if (matchingItem == nil) {
                        NSDictionary *rename = MFMenuItemsRenamedBySystem()[uiString];
                        if (rename != nil) {
                            matchingItem = rename[@"menuItem"];
                        }
                    }
                    
                    /// Get new ax child
                    NSAccessibilityElement *annotationElement = [AnnotationUtility createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
                    
                    if (matchingItem != nil) {
                        
                        
                        /// Regular case: Add to item
                        [AnnotationUtility addAnnotations:@[annotationElement] toAccessibilityElement:matchingItem];
                        
                    } else {
                        
                        /// Fallback: assume the localizedString is the menu's title
                        ///     Instead of being the title of an item inside the menu.
                        /// Notes:
                        /// - We can't clearly tell apart the localizationKeys for the NSMenuTitle from the localizationKeys for the NSMenuItems.
                        ///     So this case will always hit for the NSMenuTitle afaik.
                        /// - I think this might fail in a subtle way if the NSMenuTitle is the same as the title for one of its items.
                        ///     Then we might associate the NSMenuTitle localizationKey with the NSMenuItem instead.
                        [AnnotationUtility addAnnotations:@[annotationElement] toAccessibilityElement:relatedNode.representedObject.value];
                    }
                    
                    /// Flag
                    validation_lastLocalizedStringWasNotUsed = NO;
                    /// Stop iterating relatedNodes
                    break;
                }
                
                /// Defaultttt case: attach to the first **accessibilityElement** we find.
                
                /// Check isAccessibilityElement
                BOOL isAccessibilityElement = NO;
                if ([relatedNode.representedObject.value respondsToSelector:@selector(isAccessibilityElement)]) {
                    isAccessibilityElement = [relatedNode.representedObject.value isAccessibilityElement];
                }
                
                if (isAccessibilityElement) {

                    /// Check if `value` is an accessibility element
                    /// Notes:
                    /// - `isAccessibilityElement` is the modern replacement for `accessibilityIsIgnored`. The docs for that explain the concept.
                    /// - We used to instead check against `protocol(NSAccessibility), protocol(NSAccessibilityElement), and protocol(NSAccessibilityElementLoading)` but that caught NSTextView which doesn't actually participate in the accessibility-view-hierarchy, and attaching accessibilityChildren to it produces weird behaviour.
                    
                    /// Attach localization keys
                    /// Notes:
                    /// - We assume that the first accessibilityElement we find is the container holding the `localizationKey`
                    /// - NSKeyedUnarchiver, which is the most common NSCoder subclass (the NSCoder subclass we're dealing with here is NibDecoder) also implements this object-hierarchy stuff. Maybe its docs are helpful.
                    
                    /// Publish data for accessibility inspection
                    
                    /// Attach annotation
                    NSAccessibilityElement *annotation =
                    [AnnotationUtility createAnnotationElementWithLocalizationKey:localizationKey translatedString:uiString developmentString:developmentString translatedStringNibKey:uiStringNibKey mergedUIString:nil];
                    [AnnotationUtility addAnnotations:@[annotation] toAccessibilityElement:relatedNode.representedObject.value];
                    
                    /// Flag
                    validation_lastLocalizedStringWasNotUsed = NO;
                    /// Stop iterating relatedNodes
                    break;
                }
            }
        }
    }
}

+ (TreeNode *)treeFromDecoderRecord:(NSArray *)decoderRecord {
    
    /// Declare state
    
    TreeNode *root = nil;
    TreeNode *lastNode = nil;
    NSInteger lastDepth = -1;
    
    /// Build tree
    
    for (NSDictionary *kvPair in [decoderRecord reverseObjectEnumerator]) {
        
        /// Extract values
        NSString *key = kvPair[@"key"];
        NSString *value = kvPair[@"value"];
        NSInteger depth = [kvPair[@"depth"] integerValue];
        
        /// Create node
        TreeNode *node = [TreeNode treeNodeWithRepresentedObject:[KVPair pairWithKey:key value:value]];
        
        /// Init
        if (depth == 0) {
            root = node;
            lastNode = node;
            lastDepth = 0;
            continue;
        }
        
        /// Find parent
        TreeNode *parent;
        
        NSInteger parentDepth = depth - 1;
        NSInteger distanceFromLastNodeToParentNode = lastDepth - parentDepth;
        
        if (distanceFromLastNodeToParentNode == 0) {
            parent = lastNode;
        } else {
            parent = lastNode;
            for (int i = 0; i < distanceFromLastNodeToParentNode; i++) {
                parent = parent.parentNode;
            }
        }

        /// Validate
        assert(distanceFromLastNodeToParentNode >= 0);
        assert(parent != nil);
        
        /// Attach child
        ///     Note: We're inserting at index one, flipping the order of the children, so they end up chronological in the order they
        ///     were decoded. This is necessary since we're reversing the order of the decoderRecord using `reverseObjectEnumerator`
        ///     Too lazy to explain properly.
        [parent.mutableChildNodes insertObject:node atIndex:0];
        
        /// Validate
        assert(node.indexPath.length == depth);
        
        /// Update state
        lastNode = node;
        lastDepth = depth;
    }
    
    /// Return
    return root;
}

@end
