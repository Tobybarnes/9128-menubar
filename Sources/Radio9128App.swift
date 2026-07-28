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
    typealias PlayerPresenter = (NSPopover, NSStatusBarButton) -> Bool

    private static let firstLaunchPlayerKey = "com.tobybarnes.radio9128.hasShownBeta4Player"

    let model = AppModel()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let playerPresenter: PlayerPresenter
    private let preferences: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    override init() {
        preferences = .standard
        playerPresenter = { popover, button in
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return popover.isShown
        }
        super.init()
    }

    init(preferences: UserDefaults = .standard, playerPresenter: @escaping PlayerPresenter) {
        self.preferences = preferences
        self.playerPresenter = playerPresenter
        super.init()
    }

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
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.contentTintColor = nil
            button.alphaValue = 1
            button.isHidden = false
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
        presentPlayerOnFirstLaunch()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func presentPlayerOnFirstLaunch(attempt: Int = 0) {
        guard !preferences.bool(forKey: Self.firstLaunchPlayerKey) else { return }
        guard attempt < 20 else { return }

        let delay = attempt == 0 ? 0 : 0.25
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let button = self.statusItem?.button else { return }
            if self.showPopover(relativeTo: button) {
                self.preferences.set(true, forKey: Self.firstLaunchPlayerKey)
            } else {
                self.presentPlayerOnFirstLaunch(attempt: attempt + 1)
            }
        }
    }

    @discardableResult
    private func showPopover(relativeTo button: NSStatusBarButton) -> Bool {
        playerPresenter(popover, button)
    }
}

enum BrandAssets {
    static let accent = Color(red: 82 / 255, green: 195 / 255, blue: 187 / 255)

    static let menuBarIcon: NSImage = {
        guard let url = Bundle.main.url(forResource: "ASIPMenuBarTemplate", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            let fallback = NSImage(systemSymbolName: "radio", accessibilityDescription: "9128")!
            fallback.isTemplate = true
            return fallback
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }()
}
