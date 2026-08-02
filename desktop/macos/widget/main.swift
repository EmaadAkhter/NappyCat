import Cocoa
import WebKit

// The macOS "widget": a floating, join-all-Spaces window showing the web
// app's ?mini=1 cat card in a WKWebView, plus a 🐱 menu-bar item to control
// it. WKWebView is just a browser — no Firebase SDK, so none of the
// data-protection-keychain pain that killed the native build; sign-in lives
// in the web view's persistent storage instead.
//
// A real WidgetKit widget is off the table without a paid Apple account:
// the extension needs Apple-signed provisioning, and it would have no way
// to fetch letters anyway (Firestore requires auth the native side can't do).

let miniURL = URL(string: "https://napcat-2e042.web.app/?mini=1")!
let fullURL = URL(string: "https://napcat-2e042.web.app/")!

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusItem: NSStatusItem!
  var window: NSWindow!
  var webView: WKWebView!

  func applicationDidFinishLaunching(_ note: Notification) {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .default() // persistent: the session survives
    webView = WKWebView(frame: .zero, configuration: config)
    webView.load(URLRequest(url: miniURL))

    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered, defer: false)
    window.title = "NappyCat"
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false // close button just hides it
    window.level = .floating // sits above normal windows, like a widget
    window.collectionBehavior = [.canJoinAllSpaces]
    window.contentView = webView
    window.setFrameAutosaveName("NappyCatWidget")
    window.makeKeyAndOrderFront(nil)

    statusItem = NSStatusBar.system.statusItem(
      withLength: NSStatusItem.variableLength)
    statusItem.button?.title = "🐱"
    let menu = NSMenu()
    let show = NSMenuItem(
      title: "Show Cat", action: #selector(showCat), keyEquivalent: "")
    show.target = self
    menu.addItem(show)
    let full = NSMenuItem(
      title: "Open NappyCat", action: #selector(openFull), keyEquivalent: "")
    full.target = self
    menu.addItem(full)
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(
      title: "Quit", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"))
    statusItem.menu = menu
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
