import Flutter
import UIKit
import GoogleSignIn
import GoogleMaps
import AVFoundation
import HealthKit
import UserNotifications

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
    // Audio session is configured from Dart via the audio_session package
    // in main.dart → _configureAudioSession(). No native setup needed here.

    // Google Maps API key — injected by CI from MAPS_API_KEY secret
    GMSServices.provideAPIKey("MAPS_API_KEY_PLACEHOLDER")
    GeneratedPluginRegistrant.register(with: self)
    // Register Apple Watch connectivity plugin
    if let registrar = registrar(forPlugin: "WatchConnectivityPlugin") {
      WatchConnectivityPlugin.register(with: registrar)
    }
    // New-run notifications for workouts synced to Apple Health while the app
    // is closed. Must be (re)registered on every launch, including the
    // background launches HealthKit itself triggers.
    if let registrar = registrar(forPlugin: "HealthBackgroundObserver") {
      HealthBackgroundObserver.shared.attach(messenger: registrar.messenger())
    }
    HealthBackgroundObserver.shared.start()
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

/// Wakes the app (HealthKit background delivery) when a new workout lands in
/// Apple Health — e.g. a run recorded with the Apple Watch Workout app — and
/// shows a local "new run synced" notification, like Strava.
///
/// Deliberately does NOT import anything: it only notifies and leaves a flag
/// ("flutter.health_bg_pending_ms" == SharedPreferences key
/// "health_bg_pending_ms") so the existing Dart HealthSyncService imports the
/// run when the app is opened, skipping its 30-minute debounce. If the app is
/// in the foreground, Dart is told directly over "com.majurun.app/health_bg".
///
/// Every failure path is silent and always calls the HealthKit completion
/// handler (missing it three times makes HealthKit stop delivering).
final class HealthBackgroundObserver {
  static let shared = HealthBackgroundObserver()

  private let store = HKHealthStore()
  private let queue = DispatchQueue(label: "com.majurun.app.health-bg")
  private let anchorKey = "majurun.health_bg.workout_anchor"
  private let pendingKey = "flutter.health_bg_pending_ms"
  private var channel: FlutterMethodChannel?
  private var started = false

  func attach(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.majurun.app/health_bg", binaryMessenger: messenger)
  }

  func start() {
    guard HKHealthStore.isHealthDataAvailable(), !started else { return }
    started = true
    let workoutType = HKObjectType.workoutType()

    let observer = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completion, error in
      guard let self = self, error == nil else { completion(); return }
      self.queue.async { self.checkForNewRuns(completion: completion) }
    }
    store.execute(observer)

    store.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
      if !success { NSLog("HealthBackgroundObserver: background delivery not enabled: \(error?.localizedDescription ?? "unknown")") }
    }
  }

  private func checkForNewRuns(completion: @escaping () -> Void) {
    let anchor = loadAnchor()
    let isBaseline = (anchor == nil)
    // Only look at the last day — keeps the very first (baseline) query cheap
    // even for users with years of workout history.
    let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-24 * 3600), end: nil, options: [])

    let query = HKAnchoredObjectQuery(type: HKObjectType.workoutType(), predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, newAnchor, error in
      guard let self = self else { completion(); return }
      self.queue.async {
        guard error == nil else { completion(); return }
        if let newAnchor = newAnchor { self.saveAnchor(newAnchor) }
        // First run after install/update: record the position only — never
        // notify about workouts that already existed.
        if isBaseline { completion(); return }

        let cutoff = Date().addingTimeInterval(-12 * 3600)
        let runs = (samples as? [HKWorkout] ?? []).filter { workout in
          let bundle = workout.sourceRevision.source.bundleIdentifier.lowercased()
          return workout.workoutActivityType == .running
            && !bundle.hasPrefix("com.majurun")   // MajuRun's own runs are already in the app
            && workout.endDate > cutoff
        }
        guard let latest = runs.max(by: { $0.endDate < $1.endDate }) else { completion(); return }

        UserDefaults.standard.set(Int(Date().timeIntervalSince1970 * 1000), forKey: self.pendingKey)
        self.postNotification(for: latest) {
          DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active {
              self.channel?.invokeMethod("newRun", arguments: nil)
            }
            completion()
          }
        }
      }
    }
    store.execute(query)
  }

  private func postNotification(for workout: HKWorkout, done: @escaping () -> Void) {
    let km = workout.totalDistance?.doubleValue(for: HKUnit.meterUnit(with: .kilo)) ?? 0
    let source = workout.sourceRevision.source.name
    var body = km > 0
      ? String(format: "%.2f km in %@", km, Self.formatDuration(workout.duration))
      : "Your run (\(Self.formatDuration(workout.duration)))"
    if !source.isEmpty { body += " from \(source)" }
    body += ". Tap to view."

    let content = UNMutableNotificationContent()
    content.title = "Run synced 🏃"
    content.body = body
    content.sound = .default
    content.userInfo = ["type": "health_run_available"]

    // One id per workout — a repeated wake for the same run replaces, never duplicates.
    let request = UNNotificationRequest(identifier: "health_run_\(workout.uuid.uuidString)", content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { _ in done() }
  }

  /// H:MM:SS when an hour or longer, otherwise M:SS (never total-minutes).
  private static func formatDuration(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded()))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
  }

  private func loadAnchor() -> HKQueryAnchor? {
    guard let data = UserDefaults.standard.data(forKey: anchorKey) else { return nil }
    return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
  }

  private func saveAnchor(_ anchor: HKQueryAnchor) {
    if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
      UserDefaults.standard.set(data, forKey: anchorKey)
    }
  }
}
