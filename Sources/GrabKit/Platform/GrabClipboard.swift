import Foundation

#if os(iOS) && canImport(UIKit)
import UIKit
#elseif os(macOS) && canImport(AppKit)
import AppKit
#endif

public enum GrabClipboard {
    @discardableResult
    public static func copy(_ string: String) -> Bool {
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
}
