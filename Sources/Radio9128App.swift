import AppKit
import Combine
import SwiftUI

@main
struct Radio9128App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                lastFM: appDelegate.model.lastFM,
                launchAtLogin: appDelegate.model.launchAtLogin
            )
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let positionKey = "NSStatusItem Preferred Position com.tobybarnes.radio9128.status"
        if UserDefaults.standard.object(forKey: positionKey) == nil {
            UserDefaults.standard.set(180.0, forKey: positionKey)
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "com.tobybarnes.radio9128.status"
        item.isVisible = true
        if let button = item.button {
            let image = BrandAssets.menuBarIcon.copy() as? NSImage ?? BrandAssets.menuBarIcon
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false
            button.image = image
            button.imagePosition = .imageOnly
            button.toolTip = "9128 live radio"
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }
        statusItem = item

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 350, height: 560)
        popover.contentViewController = NSHostingController(
            rootView: PlayerPopover(
                radio: model.radio,
                player: model.player,
                lastFM: model.lastFM
            )
        )

        model.radio.$status
            .compactMap { $0?.currentTrack.metadata.displayName }
            .receive(on: RunLoop.main)
            .sink { [weak self] name in
                self?.statusItem?.button?.toolTip = name
            }
            .store(in: &cancellables)

        Task { await model.lastFM.validateSession() }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}

enum BrandAssets {
    static let accent = Color(red: 82 / 255, green: 195 / 255, blue: 187 / 255)

    static let menuBarIcon: NSImage = {
        guard let url = Bundle.main.url(forResource: "ASIPIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "radio", accessibilityDescription: "9128")!
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }()
}
