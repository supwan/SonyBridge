//
//  SonyBridgeApp.swift
//  SwiftUI app entry point: one main window plus the menu-bar item.
//

import AppKit
import SwiftUI

@main
struct SonyBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(maxWidth: 1200)
                .background(MainWindowConfigurator())
        }
        .commands {
            // SonyBridge has a single main window; File > New would only open duplicates.
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarController.install()
    }

    // Clicking the Dock icon with the window closed brings the same window back instead of making a new one.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag { return false }
        return !MainWindow.show()
    }
}

// Keeps the main window alive across close/reopen (the menu bar and the Dock bring it back with its state).
enum MainWindow {
    fileprivate static var window: NSWindow?

    @discardableResult
    static func show() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        guard let window = window else { return false }
        window.makeKeyAndOrderFront(nil)
        return true
    }
}

// Applies the AppKit-only window settings SwiftUI has no modifier for on macOS 12: a remembered frame,
// a tall portrait default, and a transparent, title-less title bar. Appearance follows the selected theme.
private struct MainWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window, MainWindow.window !== window else { return }
            MainWindow.window = window
            window.isReleasedWhenClosed = false
            window.contentMinSize = NSSize(width: 360, height: 500)
            window.contentMaxSize = NSSize(width: 1200, height: CGFloat.greatestFiniteMagnitude)
            if !window.setFrameUsingName("SonyBridgeMain") {
                let visibleHeight = (window.screen?.visibleFrame.height ?? 880) - 60
                window.setContentSize(NSSize(width: 400, height: min(820, max(500, visibleHeight))))
                window.center()
            }
            window.setFrameAutosaveName("SonyBridgeMain")
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
