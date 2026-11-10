import AppKit
import SwiftUI

/// Phone Use for the Mac: a menu bar item and one window with the Linux app's three tabs (Phone, Agents,
/// Bridge). The app starts the core (`phoneuse serve`) when it launches and stops it when it quits; closing the
/// window keeps it running for agents, and the app leaves the Dock until the window opens again.
@main
struct PhoneUseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var core = Core.shared

    var body: some Scene {
        Window("Phone Use", id: "main") {
            MainView()
                .environmentObject(core)
        }
        .defaultSize(width: 560, height: 660)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuView()
                .environmentObject(core)
        } label: {
            Image(systemName: menuSymbol)
        }
        .menuBarExtraStyle(.window)
    }

    /// The menu bar icon: an iPhone, filled while it mirrors, with a slash while Phone Use is stopped.
    private var menuSymbol: String {
        guard core.running else { return "iphone.slash" }
        return core.state?.picture?.live == true ? "iphone.gen3.radiowaves.left.and.right" : "iphone"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.shared.setUp()
        Task { @MainActor in
            let core = Core.shared
            await core.refresh()
            if !core.running { core.start() }  // a terminal's `phoneuse serve` may already run
            core.startPolling()
            #if DEBUG
            if let dir = ProcessInfo.processInfo.environment["PHONEUSE_SNAPSHOT"] { await snapshot(to: dir) }
            #endif
        }
        // In the Dock while a window is open, a menu bar app otherwise.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            DispatchQueue.main.async {
                let open = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
                if !open { NSApp.setActivationPolicy(.accessory) }
            }
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { n in
            if let w = n.object as? NSWindow, w.styleMask.contains(.titled) { AppDelegate.showInDock() }
        }
    }

    /// Into the Dock, with the app's icon. An app that starts as a menu bar app (LSUIElement) and turns into a Dock app
    /// shows a generic icon there unless it sets its own.
    static func showInDock() {
        guard NSApp.activationPolicy() != .regular else { return }
        NSApp.setActivationPolicy(.regular)
        if let icon = NSImage(named: "AppIcon") ?? NSImage(named: NSImage.applicationIconName) {
            NSApp.applicationIconImage = icon
        }
    }

    #if DEBUG
    /// Development: writes each tab of the window to DIR/<tab>.png, then quits. Draws the window's own views, so
    /// it needs no Screen Recording permission.
    @MainActor private func snapshot(to dir: String) async {
        try? await Task.sleep(for: .seconds(3))
        guard let w = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }), let v = w.contentView else { return }
        for tab in ["phone", "agents", "bridge"] {
            Core.shared.tab = tab
            try? await Task.sleep(for: .seconds(1.5))
            v.layoutSubtreeIfNeeded()
            guard let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { continue }
            v.cacheDisplay(in: v.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(tab).png"))
        }
        exit(0)
    }
    #endif

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { Core.shared.stop() }
    }
}
