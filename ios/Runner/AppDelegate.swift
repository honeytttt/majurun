import Flutter
import UIKit
import GoogleSignIn
import GoogleMaps
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Pre-configure audio category so that when flutter_tts or video_player
    // later activates the session, .mixWithOthers is already set.
    // Do NOT call setActive(true) here — activating the session at launch
    // interrupts Spotify/Udemy even when .mixWithOthers is set.
    // The session activates lazily the first time audio is actually needed.
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers, .duckOthers]
      )
    } catch {
      print("AVAudioSession category setup failed: \(error)")
    }

    // Google Maps API key — injected by CI from MAPS_API_KEY secret
    GMSServices.provideAPIKey("MAPS_API_KEY_PLACEHOLDER")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return GIDSignIn.sharedInstance.handle(url)
  }
}
