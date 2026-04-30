import Foundation
import OSLog

enum GrabDebugLog {
    private static let logger = Logger(subsystem: "GrabKit", category: "Inspector")

    static func inspectModeChanged(_ enabled: Bool) {
        logger.debug("Inspect mode changed: \(enabled, privacy: .public)")
    }

    static func selectionChanged(selectedID: String?, candidateIDs: [String]) {
        let selected = selectedID ?? "nil"
        let candidates = candidateIDs.joined(separator: ", ")
        logger.debug(
            "Selection changed: selected=\(selected, privacy: .public) candidates=[\(candidates, privacy: .public)]"
        )
    }

    static func selectionCleared() {
        logger.debug("Selection cleared")
    }
}
