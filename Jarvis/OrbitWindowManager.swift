import AppKit
import QuartzCore
import SwiftUI

// MARK: - Window Manager

final class JarvisWindowManager: NSObject, NSWindowDelegate {
    static let shared = JarvisWindowManager()

    weak var store: DemandStore?
    var isOrbitAIEnabled = true

    private var statusItem: NSStatusItem?
    private var quickWindow: NSWindow?
    private var mainWindow: NSWindow?

    private override init() {
        super.init()
    }

    func configureMenuBar(store: DemandStore) {
        self.store = store

        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: 26)
        item.button?.title = ""

        item.button?.imagePosition = .imageOnly
        item.button?.imageScaling = .scaleProportionallyDown

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Nova demanda", action: #selector(openQuickCaptureFromMenu), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Abrir lista", action: #selector(openMainWindowFromMenu), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Enviar lista pelo WhatsApp", action: #selector(shareListFromMenu), keyEquivalent: "w"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Verificar Atualizações…", action: #selector(checkForUpdatesFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Sair", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        item.menu = menu
        statusItem = item
        applyCurrentThemeToMenuBarIcon()
    }

    func captureMainWindow(_ window: NSWindow?) {
        guard let window else { return }
        mainWindow = window
        window.delegate = self
        MainWindowConfigurator.configureMainWindow(window, applyFrame: false)
        OrbitThemeDiagnostics.record(stage: "main_window_captured", appliedTheme: MatrixTheme.current.rawValue, message: "Janela principal capturada e reconfigurada com o tema atual.")
    }

    func applyCurrentThemeToMainWindow() {
        NSApp.appearance = MatrixTheme.nsAppearance
        MainWindowConfigurator.configureMainWindow(mainWindow, applyFrame: false)
        applyCurrentThemeToQuickWindow()
        applyCurrentThemeToMenuBarIcon()
        OrbitThemeDiagnostics.record(stage: "main_window_apply_theme", appliedTheme: MatrixTheme.current.rawValue)
    }

    private func applyCurrentThemeToMenuBarIcon() {
        guard let button = statusItem?.button else { return }

        if button.image == nil, let menuIcon = NSImage(named: "OrbitMenuIcon")?.copy() as? NSImage {
            menuIcon.size = NSSize(width: 20, height: 20)
            menuIcon.isTemplate = true
            button.image = menuIcon
        }

        button.contentTintColor = .white
    }

    private func applyCurrentThemeToQuickWindow() {
        guard let quickWindow else { return }
        quickWindow.appearance = MatrixTheme.nsAppearance
        quickWindow.contentViewController?.view.wantsLayer = true
        quickWindow.contentViewController?.view.layer?.backgroundColor = NSColor.clear.cgColor
        quickWindow.contentView?.wantsLayer = true
        quickWindow.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func currentMainWindowDiagnostics() -> [String: String]? {
        guard let mainWindow else { return nil }
        return [
            "windowAppearance": mainWindow.appearance?.name.rawValue ?? "",
            "effectiveAppearance": mainWindow.effectiveAppearance.name.rawValue,
            "isOpaque": mainWindow.isOpaque ? "true" : "false",
            "backgroundColor": mainWindow.backgroundColor.description,
            "styleMask": "\(mainWindow.styleMask.rawValue)"
        ]
    }

    var mainWindowContentHeight: CGFloat? {
        mainWindow?.contentLayoutRect.height ?? mainWindow?.frame.height
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == mainWindow {
            sender.orderOut(nil)
            return false
        }
        return true
    }

    func windowDidMove(_ notification: Notification) {
        guard notification.object as? NSWindow == mainWindow else { return }
        MainWindowConfigurator.saveCurrentFrame(mainWindow)
    }

    func windowDidResize(_ notification: Notification) {
        guard notification.object as? NSWindow == mainWindow else { return }
        MainWindowConfigurator.saveCurrentFrame(mainWindow)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard notification.object as? NSWindow == mainWindow else { return }
        MainWindowConfigurator.saveCurrentFrame(mainWindow)
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == mainWindow else { return }
        MainWindowConfigurator.updateContentCornerRadius(for: window)
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == mainWindow else { return }
        MainWindowConfigurator.updateContentCornerRadius(for: window)
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == mainWindow else { return }
        MainWindowConfigurator.updateContentCornerRadius(for: window)
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window == mainWindow else { return }
        MainWindowConfigurator.updateContentCornerRadius(for: window)
    }

    @objc func openQuickCaptureFromMenu() {
        showQuickCapture()
    }

    @objc func openMainWindowFromMenu() {
        showMainWindow()
    }

    @objc func shareListFromMenu() {
        shareFullListToWhatsApp()
    }

    @objc func checkForUpdatesFromMenu() {
        OrbitUpdaterController.shared.checkForUpdates()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let mainWindow {
            mainWindow.makeKeyAndOrderFront(nil)
        }

        NotificationCenter.default.post(name: .jarvisOpenMainWindow, object: nil)
    }

    func showQuickCapture() {
        guard store != nil else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if let quickWindow {
            NSApp.activate(ignoringOtherApps: true)
            quickWindow.makeKeyAndOrderFront(nil)
            return
        }

        let view = QuickCaptureView(
            isOrbitAIEnabled: isOrbitAIEnabled,
            onSubmitText: { [weak self] text in
                self?.handleQuickCapture(text)
            },
            onInsertSuggestion: { [weak self] title in
                self?.insertDemandFromSuggestion(title)
            },
            onCancel: { [weak self] in
                self?.closeQuickCaptureAnimated()
            }
        )

        let hostingController = NSHostingController(rootView: view)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        hostingController.view.layer?.cornerRadius = 26
        hostingController.view.layer?.masksToBounds = true

        let window = QuickCapturePanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 210),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.title = "ORBIT"
        window.styleMask = [.borderless]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView?.layer?.cornerRadius = 26
        window.contentView?.layer?.masksToBounds = true

        window.makeKey()
        window.level = .floating
        window.hasShadow = true
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        quickWindow = window
        NSApp.activate(ignoringOtherApps: true)
        positionQuickWindowForFadeIn(window)
        window.makeKeyAndOrderFront(nil)
        animateQuickWindowFadeIn(window)
    }

    private func centeredQuickWindowFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: 720, height: 210)
        }

        let visibleFrame = screen.visibleFrame
        let windowSize = NSSize(width: 720, height: 210)
        let x = visibleFrame.midX - windowSize.width / 2
        let y = visibleFrame.midY - windowSize.height / 2
        return NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
    }

    private func positionQuickWindowForFadeIn(_ window: NSWindow) {
        window.setFrame(centeredQuickWindowFrame(), display: true)
    }

    private func animateQuickWindowFadeIn(_ window: NSWindow) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        } completionHandler: {
            window.makeKey()
        }
    }

    private func handleQuickCapture(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanText.lowercased() == "lista" {
            closeQuickCaptureAnimated()
            showMainWindow()
            return
        }

        guard cleanText.isEmpty == false else { return }

        insertDemandFromSuggestion(cleanText)
        closeQuickCaptureAnimated()
    }

    private func insertDemandFromSuggestion(_ title: String) {
        store?.addDemand(title: title)
        NotificationManager.shared.notifyDemandInserted()
        NotificationCenter.default.post(name: .jarvisDemandInserted, object: nil)
    }

    func closeQuickCapture() {
        quickWindow?.close()
        quickWindow = nil
    }

    func closeQuickCaptureAnimated() {
        guard let window = quickWindow else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.closeQuickCapture()
        }
    }

    func shareFullListToWhatsApp() {
        guard let store else { return }

        let text = store.titleOnlyListText()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let appURL = URL(string: "whatsapp://send?text=\(encoded)"), NSWorkspace.shared.open(appURL) {
            return
        }

        if let webURL = URL(string: "https://wa.me/?text=\(encoded)") {
            NSWorkspace.shared.open(webURL)
        }
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == quickWindow {
            quickWindow = nil
        }
    }
}

struct ViewAnchorAccessor: NSViewRepresentable {
    let callback: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            callback(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            callback(nsView)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            callback(nsView.window)
        }
    }
}

struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            Self.configureSettingsWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.configureSettingsWindow(nsView.window)
        }
    }

    static func configureSettingsWindow(_ window: NSWindow?) {
        guard let window else { return }

        let usesTransparentChrome = MatrixTheme.current.usesPureGlass || MatrixTheme.isPride

        window.appearance = MatrixTheme.nsAppearance
        window.titlebarAppearsTransparent = usesTransparentChrome
        window.isOpaque = usesTransparentChrome == false
        window.backgroundColor = usesTransparentChrome ? .clear : MatrixTheme.nsBackground

        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = usesTransparentChrome ? .none : .automatic
        }

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = usesTransparentChrome ? NSColor.clear.cgColor : MatrixTheme.nsBackground.cgColor

        guard usesTransparentChrome,
              let frameView = window.contentView?.superview else {
            return
        }

        clearNativeChromeBackgrounds(in: frameView, excluding: window.contentView)
    }

    private static func clearNativeChromeBackgrounds(in view: NSView, excluding excludedView: NSView?) {
        guard view !== excludedView else { return }

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        if let visualEffectView = view as? NSVisualEffectView {
            visualEffectView.material = .underWindowBackground
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .inactive
        }

        for subview in view.subviews where subview !== excludedView {
            clearNativeChromeBackgrounds(in: subview, excluding: excludedView)
        }
    }
}

struct LoginWindowConfigurator: NSViewRepresentable {
    private static let configuredWindowIDs = NSHashTable<NSWindow>.weakObjects()
    let targetSize: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            Self.configureLoginWindow(view.window, targetSize: targetSize, applyFrame: true)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.configureLoginWindow(nsView.window, targetSize: targetSize, applyFrame: false)
        }
    }

    static func configureLoginWindow(_ window: NSWindow?, targetSize: NSSize = NSSize(width: 480, height: 360), applyFrame: Bool) {
        guard let window else { return }
        let shouldApplyFrame = applyFrame || configuredWindowIDs.contains(window) == false
        let sizeChanged = abs(window.frame.width - targetSize.width) > 0.5 || abs(window.frame.height - targetSize.height) > 0.5

        if shouldApplyFrame || sizeChanged {
            if let screen = window.screen ?? NSScreen.main {
                let frame = screen.visibleFrame
                let currentFrame = window.frame
                let origin = shouldApplyFrame
                    ? NSPoint(
                        x: frame.midX - targetSize.width / 2,
                        y: frame.midY - targetSize.height / 2
                    )
                    : NSPoint(
                        x: currentFrame.midX - targetSize.width / 2,
                        y: currentFrame.midY - targetSize.height / 2
                    )
                window.setFrame(NSRect(origin: origin, size: targetSize), display: true, animate: sizeChanged)
            } else {
                window.setContentSize(targetSize)
                window.center()
            }
            configuredWindowIDs.add(window)
        }

        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.makeKeyAndOrderFront(nil)

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView?.layer?.cornerRadius = 20
        window.contentView?.layer?.masksToBounds = true
    }
}

struct MainWindowConfigurator: NSViewRepresentable {
    private static let configuredWindowIDs = NSHashTable<NSWindow>.weakObjects()
    private static let targetSize = NSSize(width: 1120, height: 720)
    private static let frameStorageKey = "orbit.mainWindow.frame"
    private static let glassRootIdentifier = NSUserInterfaceItemIdentifier("orbit.mainWindow.liquidGlassRoot")

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        Self.configureMainWindow(window, applyFrame: Self.configuredWindowIDs.contains(window) == false)
    }

    static func configureMainWindow(_ window: NSWindow?, applyFrame: Bool) {
        guard let window else { return }

        exitFullScreenIfNeeded(window)
        applyMainWindowStyleMask(to: window)
        window.title = "ORBIT"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = MatrixTheme.nsAppearance
        window.isOpaque = MatrixTheme.current.usesPureGlass == false
        window.backgroundColor = MatrixTheme.current.usesPureGlass ? .clear : MatrixTheme.nsBackground
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.toolbar = nil
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.collectionBehavior.insert(.fullScreenNone)
        window.minSize = targetSize
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        updateMainWindowChrome(for: window)
        updateContentCornerRadius(for: window)

        if applyFrame, window.styleMask.contains(.fullScreen) == false {
            let frame = restoredFrame(for: window) ?? centeredFrame(for: window, size: targetSize)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                context.allowsImplicitAnimation = false
                window.setFrame(frame, display: true, animate: false)
            }
            Self.configuredWindowIDs.add(window)
        }
    }

    static func updateContentCornerRadius(for window: NSWindow) {
        removeLiquidGlassRootIfNeeded(for: window)

        let cornerRadius: CGFloat = {
            guard MatrixTheme.current.usesPureGlass == false else { return 0 }
            return window.styleMask.contains(.fullScreen) ? 0 : 20
        }()

        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = cornerRadius
        window.contentView?.layer?.masksToBounds = MatrixTheme.current.usesPureGlass == false
        window.contentView?.layer?.backgroundColor = MatrixTheme.current.usesPureGlass ? NSColor.clear.cgColor : MatrixTheme.nsBackground.cgColor
    }

    private static func removeLiquidGlassRootIfNeeded(for window: NSWindow) {
        guard let glassView = window.contentView as? NSGlassEffectView,
              glassView.identifier == glassRootIdentifier,
              let wrappedContentView = glassView.contentView else {
            return
        }

        glassView.contentView = nil
        window.contentView = wrappedContentView
    }

    private static func updateMainWindowChrome(for window: NSWindow) {
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = MatrixTheme.current.usesPureGlass ? .none : .automatic
        }

        guard MatrixTheme.current.usesPureGlass else { return }

        window.contentView?.superview?.wantsLayer = true
        window.contentView?.superview?.layer?.backgroundColor = NSColor.clear.cgColor

        if let frameView = window.contentView?.superview {
            clearNativeChromeBackgrounds(in: frameView, excluding: window.contentView)
        }
    }

    private static func clearNativeChromeBackgrounds(in view: NSView, excluding excludedView: NSView?) {
        guard view !== excludedView else { return }

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        if let visualEffectView = view as? NSVisualEffectView {
            visualEffectView.material = .underWindowBackground
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .inactive
        }

        for subview in view.subviews where subview !== excludedView {
            clearNativeChromeBackgrounds(in: subview, excluding: excludedView)
        }
    }

    private static func applyMainWindowStyleMask(to window: NSWindow) {
        var styleMask = window.styleMask
        let required: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        styleMask.formUnion(required)
        if styleMask.contains(.fullScreen) == false {
            styleMask.remove(.fullScreen)
        }
        window.styleMask = styleMask
    }

    private static func exitFullScreenIfNeeded(_ window: NSWindow) {
        guard window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
    }

    static func saveCurrentFrame(_ window: NSWindow?) {
        guard let window else { return }
        guard window.isMiniaturized == false else { return }
        guard window.styleMask.contains(.fullScreen) == false else { return }

        UserDefaults.standard.set(NSStringFromRect(window.frame), forKey: frameStorageKey)
    }

    private static func restoredFrame(for window: NSWindow) -> NSRect? {
        guard let storedFrame = UserDefaults.standard.string(forKey: frameStorageKey) else { return nil }
        let frame = NSRectFromString(storedFrame)
        guard frame.width >= targetSize.width, frame.height >= targetSize.height else { return nil }
        guard frame.isNull == false, frame.isEmpty == false else { return nil }
        guard intersectsAnyVisibleScreen(frame) else { return nil }

        return frame
    }

    private static func intersectsAnyVisibleScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }
    }

    private static func centeredFrame(for window: NSWindow, size: NSSize) -> NSRect {
        let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: size.width, height: size.height)
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
