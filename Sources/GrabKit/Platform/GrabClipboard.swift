import Foundation

#if os(iOS) && canImport(UIKit)
import UIKit
#elseif os(macOS) && canImport(AppKit)
import AppKit
#endif

public enum GrabClipboard {
    private static var lastCopiedString: String?

    @discardableResult
    public static func copy(_ string: String) -> Bool {
        lastCopiedString = string
        #if os(iOS) && canImport(UIKit)
        UIPasteboard.general.string = string
        return true
        #elseif os(macOS) && canImport(AppKit)
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(string, forType: .string)
        #else
        return false
        #endif
    }

    public static func lastCopied() -> String? {
        lastCopiedString
    }
}
