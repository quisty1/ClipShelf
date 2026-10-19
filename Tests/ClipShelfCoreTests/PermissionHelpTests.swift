import Foundation
import ClipShelfCore

@MainActor struct PermissionHelpTests {
    func deniedOrStalePermissionStillNavigatesWhenPromptIsSuppressed() {
        var events: [String] = []
        let opened = PermissionHelp.open(prepare: { events.append("hide") }, hasAccess: { false },
            requestAccess: { events.append("request") }, openSettings: { events.append("open"); return true })
        expect(opened)
        expect(events == ["hide", "request", "open"])
    }
    func allowedPermissionOpensSettingsWithoutAskingAgain() {
        var events: [String] = []
        let opened = PermissionHelp.open(prepare: { events.append("hide") }, hasAccess: { true },
            requestAccess: { events.append("request") }, openSettings: { events.append("open"); return true })
        expect(opened)
        expect(events == ["hide", "open"])
    }
    func navigationFailureIsReported() {
        var attempted = false
        let opened = PermissionHelp.open(prepare: {}, hasAccess: { true }, requestAccess: {},
            openSettings: { attempted = true; return false })
        expect(attempted)
        expect(!opened)
    }
}
