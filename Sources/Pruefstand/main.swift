import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate: NSApplicationDelegate
    let options = LaunchOptions.parse(CommandLine.arguments)

    switch options.mode {
    case .menuBar:
        delegate = AppDelegate(actionMode: options.actionMode)
        app.setActivationPolicy(.accessory)
    case .preview:
        delegate = PreviewAppDelegate(actionMode: options.actionMode)
        app.setActivationPolicy(.regular)
    }

    app.delegate = delegate
    app.run()
}
