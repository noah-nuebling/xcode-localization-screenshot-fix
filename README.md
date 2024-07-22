
# Readme.md

We can't get Xcode to export the Localization Screenshots for us. 

I tried a lottt of things for troubleshooting but didn't manage to solve the issue. (See xcode-localization-screenshot-tests repo)

For the last 2 days or so I tried installing macOS 11 Big Sur, so I can use Xcode 11 to closely follow along the WWDC 2019 Demo of this feature. But I just couldn't manage to install the older version. Before that I also tried using my old MacBook, but it seems to be unusable now, with the screen turning off every few seconds.

The only ideas I have left are:

- Making a 'Code Level Support' request with Apple - to see if they can help
- Implementing the screenshot feature myself
- Giving up on automated screenshots

This project is to test the idea of implementing the screenshot feature ourselves.

---

## Notes

We successfully handcrafted a .xcloc file with embedded screenshots. See de-manual-edit.xcloc.
If n strings appeared in the same screenshot we had to include n copies of the screenshot. 
Since if several strings referenced the same screenshot file, the red highlighter rectangle that highlights the text in the screenshot broke in Xcode 16.0 Beta 2.
This didn't happen in Loca Studio, but Loca Studio doesn't support the 'state' (e.g. needs_review) which we really want to use.

---

## Update

I worked on this for two weeks, and then I found there's a much simpler and better approach! (Using zero-width strings) (See f3640d56da1251ed36b84d61dc991e5f5fd82af0)
So we're abandoning this repo.

**Don't modify this repo anymore.**

Plans to salvage the work in here:

- I plan to copy-paste the utility functions and datastructures from the `PortToMMF` folder over to MMF.
- The content of NibDecodingAnalysis, UIStringChangeDetector, and NSLocalizedStringRecord, SystemRenameTracker, AnnotationUtility, as well as the External folder could serve as reference for understanding the internal structure of app kit stuff 
    - E.g. NibDecodingAnalysis prints the entire structure of the object-tree inside an Nib file, 
    - E.g. UIStringChangeDetector has a quite comprehensive list of all uiString setters across AppKit. 
    - E.g. AnnotationUtility features a pretty comprehensive list of user-facing (and therefore localizable) strings on objects. Even obscure ones such as NSAccessibilityMarkerTypeDescriptionAttribute or paletteLabel. 
- `Notes > AppKitSetters` documents techniques for finding uistring-setter-methods using lldb
- `Notes > Examples` Contains a handcrafted .xcloc file which contains screenshots that can be displayed inline in the .xcloc editing GUI in Xcode - along with red squares around the localizedStrings inside the screenshots!

