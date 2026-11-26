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
        // A single-instance window: SwiftUI reopens this one window (from the Dock, the Window menu or
        // `openWindow`) instead of creating more, and offers no File > New.
        Window("SonyBridge", id: MainWindow.id) {
            ContentView()
        }
        .defaultSize(width: 460, height: 760)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // The status item needs a running app, so it's installed once launching finishes.
    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarController.install()
    }
}

// Lets the AppKit menu-bar item open the SwiftUI window.
enum MainWindow {
    static let id = "main"

    // Captured from the window's environment when it first appears. It's app-wide, so it keeps working
    // after the window is closed.
    static var openAction: OpenWindowAction?

    static func show() {
        // The menu-bar panel doesn't make the app frontmost, so bring it forward with the window.
        NSApp.activate(ignoringOtherApps: true)
        openAction?(id: id)
    }
}
