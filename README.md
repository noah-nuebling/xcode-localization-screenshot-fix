
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
This didn't happen in Loca Studio, but Loca Studio doesn't support the 'state' (e.g. needs_review) which really sucks.