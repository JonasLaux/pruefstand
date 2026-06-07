enum LaunchMode: Equatable {
    case menuBar
    case preview

    static func parse(_ arguments: [String]) -> LaunchMode {
        arguments.contains("--preview") ? .preview : .menuBar
    }
}

struct LaunchOptions: Equatable {
    let mode: LaunchMode
    let actionMode: PRActionMode

    static func parse(_ arguments: [String]) -> LaunchOptions {
        let mode = LaunchMode.parse(arguments)
        let actionMode: PRActionMode = (mode == .preview || arguments.contains("--debug-actions")) ? .dryRun : .live
        return LaunchOptions(mode: mode, actionMode: actionMode)
    }
}
