import Cocoa
import WebKit

// The macOS "widget", two surfaces from one menu-bar app:
//  - a floating, join-all-Spaces mini window: the cat card + composer
//  - the menu-bar cat: LEFT-click drops the same card in a panel anchored
//    directly under the icon (an NSPanel, not NSPopover — popovers drift
//    and detach); right-click gets the utility menu.
// Both are WKWebViews over the deployed web app (?mini=1) sharing the
// default persistent data store — one sign-in covers both, and none of
// FirebaseAuth's data-protection-keychain pain applies because neither is
// a native Firebase client.
//
// A real WidgetKit widget still needs the paid Apple account: the
// extension must carry Apple-signed provisioning.

let miniURL = URL(string: "https://napcat-2e042.web.app/?mini=1")!
let fullURL = URL(string: "https://napcat-2e042.web.app/")!

/// Borderless panels refuse key status by default, which would kill typing
/// in the composer.
final class KeyablePanel: NSPanel {
  override var canBecomeKey: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusItem: NSStatusItem!
  var window: NSWindow!
  var panel: KeyablePanel!
  var utilityMenu: NSMenu!
  var monitors: [Any] = []
  var lastHide = Date.distantPast

  func applicationDidFinishLaunching(_ note: Notification) {
    // Purge stale page caches and any service worker left by older builds —
    // but never localStorage/IndexedDB, which hold the sign-in. Pages load
    // only after the purge so a deploy always shows on next launch.
    let store = WKWebsiteDataStore.default()
    let staleTypes: Set<String> = [
      WKWebsiteDataTypeDiskCache,
      WKWebsiteDataTypeMemoryCache,
      WKWebsiteDataTypeServiceWorkerRegistrations,
    ]
    let fresh = URLRequest(
      url: miniURL, cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: 30)

    let miniWeb = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 540),
      // No fullSizeContentView: the traffic lights get their own strip
      // instead of squatting on the app's header.
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered, defer: false)
    window.title = "NappyCat"
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false // close button just hides it
    window.level = .floating // sits above normal windows, like a widget
    window.collectionBehavior = [.canJoinAllSpaces]
    window.contentView = miniWeb
    window.setFrameAutosaveName("NappyCatWidget")
    window.makeKeyAndOrderFront(nil)

    // The drop-down: same mini card, anchored under the menu-bar icon.
    let popWeb = WKWebView(
      frame: NSRect(x: 0, y: 0, width: 360, height: 560),
      configuration: WKWebViewConfiguration())
    popWeb.autoresizingMask = [.width, .height]
    let wrap = NSView(frame: popWeb.frame)
    wrap.wantsLayer = true
    wrap.layer?.cornerRadius = 18
    wrap.layer?.masksToBounds = true
    wrap.addSubview(popWeb)
    panel = KeyablePanel(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 560),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .statusBar
    panel.isReleasedWhenClosed = false
    panel.hidesOnDeactivate = false
    panel.contentView = wrap

    store.removeData(ofTypes: staleTypes, modifiedSince: .distantPast) {
      miniWeb.load(fresh)
      popWeb.load(fresh)
    }

    utilityMenu = NSMenu()
    let show = NSMenuItem(
      title: "Show Cat Window", action: #selector(showCat), keyEquivalent: "")
    show.target = self
    utilityMenu.addItem(show)
    let browser = NSMenuItem(
      title: "Open in Browser", action: #selector(openFull), keyEquivalent: "")
    browser.target = self
    utilityMenu.addItem(browser)
    utilityMenu.addItem(.separator())
    utilityMenu.addItem(NSMenuItem(
      title: "Quit NappyCat", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"))

    statusItem = NSStatusBar.system.statusItem(
      withLength: NSStatusItem.variableLength)
    if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
       let img = NSImage(contentsOfFile: path) {
      img.size = NSSize(width: 18, height: 18)
      statusItem.button?.image = img
    } else {
      statusItem.button?.title = "🐱"
    }
    statusItem.button?.action = #selector(statusTapped)
    statusItem.button?.target = self
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
  }

  @objc func statusTapped() {
    guard let button = statusItem.button else { return }
    if NSApp.currentEvent?.type == .rightMouseUp {
      utilityMenu.popUp(
        positioning: nil,
        at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
      return
    }
    if panel.isVisible {
      hidePanel()
    } else if Date().timeIntervalSince(lastHide) > 0.3 {
      // The dismiss monitors may have just closed it from this same click's
      // mouseDown; without the debounce the mouseUp reopens it instantly.
      showPanel()
    }
  }

  func showPanel() {
    guard let button = statusItem.button, let bw = button.window else { return }
    // X comes from the icon; Y from the screen's visibleFrame, whose top
    // already sits just below the menu bar (button coords lie about it).
    let anchor = bw.convertToScreen(button.convert(button.bounds, to: nil))
    let screen = bw.screen ?? NSScreen.main
    let visible = screen?.visibleFrame ?? anchor
    let origin = NSPoint(
      x: min(anchor.maxX, visible.maxX) - panel.frame.width,
      y: visible.maxY - panel.frame.height - 4)
    panel.setFrameOrigin(origin)
    panel.makeKeyAndOrderFront(nil)
    // Any click outside the panel dismisses it, like a real menu — global
    // catches other apps, local catches our own windows (status icon too).
    monitors.append(NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] _ in
      self?.hidePanel()
    } as Any)
    monitors.append(NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown]
    ) { [weak self] event in
      if event.window !== self?.panel { self?.hidePanel() }
      return event
    } as Any)
  }

  func hidePanel() {
    panel.orderOut(nil)
    lastHide = Date()
    for m in monitors { NSEvent.removeMonitor(m) }
    monitors.removeAll()
  }

  @objc func showCat() {
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc func openFull() {
    NSWorkspace.shared.open(fullURL)
  }
}

// Single instance: a second launch (DMG copy + installed copy, say) would
// put a second cat in the menu bar and split the two surfaces across
// processes. Yield to the one already running.
let mine = Bundle.main.bundleIdentifier ?? "com.mypeblo.nappycat.widget"
let already = NSRunningApplication.runningApplications(withBundleIdentifier: mine)
  .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
if !already.isEmpty {
  already.first?.activate()
  exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu-bar app: no dock icon
app.run()
