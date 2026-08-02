import Cocoa
import WebKit

// The macOS "widget", two surfaces from one menu-bar app:
//  - a floating, join-all-Spaces mini window: just the cat card (?mini=1)
//  - the menu-bar cat: LEFT-click expands a popover with the FULL app
//    (letters, compose, journal); right-click gets the utility menu.
// Both are WKWebViews over the deployed web app sharing the default (
// persistent) data store — one sign-in covers both, and none of
// FirebaseAuth's data-protection-keychain pain applies because neither is
// a native Firebase client.
//
// A real WidgetKit widget still needs the paid Apple account: the
// extension must carry Apple-signed provisioning.

let miniURL = URL(string: "https://napcat-2e042.web.app/?mini=1")!
let fullURL = URL(string: "https://napcat-2e042.web.app/")!

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusItem: NSStatusItem!
  var window: NSWindow!
  var popover: NSPopover!
  var utilityMenu: NSMenu!

  func applicationDidFinishLaunching(_ note: Notification) {
    let miniWeb = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    miniWeb.load(URLRequest(url: miniURL))

    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.title = "NappyCat"
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false // close button just hides it
    window.level = .floating // sits above normal windows, like a widget
    window.collectionBehavior = [.canJoinAllSpaces]
    window.contentView = miniWeb
    window.setFrameAutosaveName("NappyCatWidget")
    window.makeKeyAndOrderFront(nil)

    // Full app in the popover. Built once and kept alive so it doesn't
    // reload (and re-run auth) on every expand.
    let fullWeb = WKWebView(
      frame: NSRect(x: 0, y: 0, width: 380, height: 640),
      configuration: WKWebViewConfiguration())
    fullWeb.load(URLRequest(url: fullURL))
    let vc = NSViewController()
    vc.view = fullWeb
    popover = NSPopover()
    popover.behavior = .transient // closes on outside click
    popover.contentSize = NSSize(width: 380, height: 640)
    popover.contentViewController = vc

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
    if popover.isShown {
      popover.performClose(nil)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      NSApp.activate(ignoringOtherApps: true)
    }
  }

  @objc func showCat() {
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc func openFull() {
    NSWorkspace.shared.open(fullURL)
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu-bar app: no dock icon
app.run()
