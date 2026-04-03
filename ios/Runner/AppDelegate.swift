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
    // Allow Spotify / Udemy / other audio apps to keep playing while this app
    // uses TTS or video. Without .mixWithOthers, any AVAudioSession activation
    // (triggered by flutter_tts or video_player) silences background audio.
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers, .allowBluetooth, .allowAirPlay]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      // Non-fatal — app still works; background music may be interrupted
      print("AVAudioSession setup failed: \(error)")
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
