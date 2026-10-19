import Foundation

public enum PermissionHelp {
    @MainActor public static func open(
        prepare: () -> Void,
        hasAccess: () -> Bool,
        requestAccess: () -> Void,
        openSettings: () -> Bool
    ) -> Bool {
        prepare()
        if !hasAccess() { requestAccess() }
        return openSettings()
    }
}
