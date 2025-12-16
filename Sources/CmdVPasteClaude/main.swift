import AppKit
import ApplicationServices
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let tempDirectory: URL
    private var eventMonitor: Any?
    private var lastChangeCount: Int = 0
    private var permissionCheckTimer: Timer?

    override init() {
        // Create temp directory for images
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmdv-paste-claude", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        checkAndRequestAccessibility()
        cleanOldTempFiles()

        // Initialize change count to current state
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func checkAndRequestAccessibility() {
        if AXIsProcessTrusted() {
            startEventMonitor()
            updateMenuForPermissionGranted()
        } else {
            // Prompt for accessibility (shows system dialog)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)

            updateMenuForPermissionNeeded()

            // Poll for permission changes (user might grant it in Settings)
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                if AXIsProcessTrusted() {
                    self?.permissionCheckTimer?.invalidate()
                    self?.permissionCheckTimer = nil
                    self?.startEventMonitor()
                    self?.updateMenuForPermissionGranted()
                }
            }
        }
    }

    private func loadMenuBarIcon() -> NSImage? {
        let bundle = Bundle.main
        if let iconURL = bundle.url(forResource: "menubar_icon", withExtension: "png"),
           let image = NSImage(contentsOf: iconURL) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        // Fallback to system symbol
        return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CmdV Paste Claude")
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = loadMenuBarIcon()
            button.toolTip = "CmdV Paste Claude - Converts clipboard images to files"
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "Checking permissions...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        statusMenuItem.tag = 100  // Tag to identify status item
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Convert Now", action: #selector(manualConvert), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        self.statusItem.menu = menu
    }

    private func updateMenuForPermissionNeeded() {
        guard let menu = statusItem.menu else { return }

        // Update icon to warning state
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Permission needed")
        }

        // Remove old items and rebuild
        menu.removeAllItems()

        let warningItem = NSMenuItem(title: "⚠️ Accessibility Permission Required", action: nil, keyEquivalent: "")
        warningItem.isEnabled = false
        menu.addItem(warningItem)

        let openSettingsItem = NSMenuItem(title: "Open Accessibility Settings...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(openSettingsItem)

        menu.addItem(NSMenuItem.separator())

        let convertItem = NSMenuItem(title: "Convert Now (manual)", action: #selector(manualConvert), keyEquivalent: "")
        menu.addItem(convertItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(createLaunchAtLoginMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
    }

    private func updateMenuForPermissionGranted() {
        guard let menu = statusItem.menu else { return }

        // Update icon to normal state
        if let button = statusItem.button {
            button.image = loadMenuBarIcon()
        }

        // Remove old items and rebuild
        menu.removeAllItems()

        let statusMenuItem = NSMenuItem(title: "✓ Listening for copy events", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Convert Now", action: #selector(manualConvert), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(createLaunchAtLoginMenuItem())
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Launch at Login

    private var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            // Update the menu item checkmark
            sender.state = launchAtLogin ? .on : .off
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }

    private func createLaunchAtLoginMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        item.state = launchAtLogin ? .on : .off
        return item
    }

    // macOS virtual key codes (from Events.h / HIToolbox, but these are stable)
    private enum KeyCode: UInt16 {
        case c = 8
        case three = 20
        case four = 21
        case five = 23
    }

    private func startEventMonitor() {
        // Monitor for key events globally using modern NSEvent API
        // This detects Cmd+C, Cmd+Shift+3/4/5 (screenshots), etc.
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }

            let flags = event.modifierFlags
            let keyCode = event.keyCode

            // Cmd+C (copy)
            if flags.contains(.command) && keyCode == KeyCode.c.rawValue {
                self.scheduleClipboardCheck()
            }

            // Cmd+Shift+3/4/5 (screenshots)
            if flags.contains(.command) && flags.contains(.shift) {
                if keyCode == KeyCode.three.rawValue ||
                   keyCode == KeyCode.four.rawValue ||
                   keyCode == KeyCode.five.rawValue {
                    // Screenshots take a moment to complete
                    self.scheduleClipboardCheck(delay: 0.5)
                }
            }

            // Cmd+Ctrl+Shift+3/4 (screenshot directly to clipboard)
            if flags.contains(.command) && flags.contains(.shift) && flags.contains(.control) {
                if keyCode == KeyCode.three.rawValue || keyCode == KeyCode.four.rawValue {
                    self.scheduleClipboardCheck(delay: 0.5)
                }
            }
        }

        if eventMonitor == nil {
            print("Warning: Could not start event monitor.")
        }
    }

    private var pendingCheck: DispatchWorkItem?

    private func scheduleClipboardCheck(delay: TimeInterval = 0.1) {
        // Cancel any pending check
        pendingCheck?.cancel()

        // Schedule a new check
        let workItem = DispatchWorkItem { [weak self] in
            self?.checkClipboard()
        }
        pendingCheck = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        // Only process if clipboard changed
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Check if clipboard already contains a file URL (don't re-convert)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty {
            return
        }

        // Check if clipboard has image data (not a file)
        if hasImageData(pasteboard) {
            convertClipboardImage()
        }
    }

    private func hasImageData(_ pasteboard: NSPasteboard) -> Bool {
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        for type in imageTypes {
            if pasteboard.data(forType: type) != nil {
                return true
            }
        }
        if NSImage(pasteboard: pasteboard) != nil {
            return true
        }
        return false
    }

    @objc private func manualConvert() {
        lastChangeCount = 0  // Force check
        checkClipboard()
    }

    private func convertClipboardImage() {
        let pasteboard = NSPasteboard.general

        guard let imageData = getImageDataFromClipboard(pasteboard) else {
            return
        }

        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "clipboard-\(timestamp).png"
        let fileURL = tempDirectory.appendingPathComponent(filename)

        do {
            try imageData.write(to: fileURL)
        } catch {
            print("Error: Failed to save image: \(error.localizedDescription)")
            return
        }

        pasteboard.clearContents()
        pasteboard.writeObjects([fileURL as NSURL])

        lastChangeCount = pasteboard.changeCount

        print("Converted clipboard image to: \(fileURL.path)")
        flashMenuBarIcon()
    }

    private func getImageDataFromClipboard(_ pasteboard: NSPasteboard) -> Data? {
        if let image = NSImage(pasteboard: pasteboard) {
            guard let tiffData = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                return nil
            }
            return pngData
        }

        if let pngData = pasteboard.data(forType: .png) {
            return pngData
        }

        if let tiffData = pasteboard.data(forType: .tiff),
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            return pngData
        }

        return nil
    }

    private func flashMenuBarIcon() {
        guard let button = statusItem.button else { return }
        let originalImage = button.image
        button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            button.image = originalImage
        }
    }

    private func cleanOldTempFiles() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }

        let oneHourAgo = Date().addingTimeInterval(-3600)

        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < oneHourAgo {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    @objc private func quit() {
        permissionCheckTimer?.invalidate()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        NSApp.terminate(nil)
    }
}

// Create and run the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
