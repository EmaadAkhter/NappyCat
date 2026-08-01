import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Phase 4: BGAppRefreshTask identifier must be registered before the app
    // finishes launching, and must match BGTaskSchedulerPermittedIdentifiers
    // and BackgroundRefresh.taskId exactly — any mismatch is silent.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.mypeblo.tidal.refresh",
      frequency: NSNumber(value: 15 * 60)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
