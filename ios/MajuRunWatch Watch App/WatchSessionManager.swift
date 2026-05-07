import Foundation
import WatchConnectivity
import HealthKit
import CoreLocation

/// Manages phone↔watch sync AND standalone run recording on the watch.
///
/// Companion mode: phone sends `syncRunData` every 10 s → view updates live.
/// Standalone mode: user taps "Start Run" → GPS + HKWorkoutSession record locally
///                  → on stop, payload sent via transferUserInfo (queued, delivered
///                    when iPhone reconnects).
class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate, CLLocationManagerDelegate {

    static let shared = WatchSessionManager()

    // ─── Published run state (used by both modes) ──────────────────────────
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var distanceKm: Double = 0
    @Published var durationSeconds: Int = 0
    @Published var paceString: String = "--:--"
    @Published var heartRate: Int = 0
    @Published var calories: Int = 0
    @Published var isPhoneReachable: Bool = false

    /// True when the watch is recording its own run (no phone needed).
    @Published var isStandaloneMode: Bool = false

    // ─── HealthKit ────────────────────────────────────────────────────────
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // ─── GPS ──────────────────────────────────────────────────────────────
    private let locationManager = CLLocationManager()
    private var standaloneRoutePoints: [CLLocation] = []
    private var standaloneDistanceMeters: Double = 0
    private var lastLocation: CLLocation?

    // ─── Standalone timer ─────────────────────────────────────────────────
    private var standaloneTimer: Timer?
    private var standaloneStartDate: Date?
    private var standalonePausedDuration: TimeInterval = 0
    private var standalonePauseStart: Date?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5          // only update every 5 m
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // ─── HealthKit + Location authorization ───────────────────────────────

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        ]
        healthStore.requestAuthorization(toShare: share, read: read) { _, _ in }
    }

    // ─── Standalone run: start ────────────────────────────────────────────

    func startStandaloneRun() {
        guard !isStandaloneMode else { return }

        isStandaloneMode = true
        standaloneStartDate = Date()
        standalonePausedDuration = 0
        standalonePauseStart = nil
        standaloneRoutePoints = []
        standaloneDistanceMeters = 0
        lastLocation = nil

        distanceKm = 0
        durationSeconds = 0
        paceString = "--:--"
        heartRate = 0
        calories = 0
        isRunning = true
        isPaused = false

        locationManager.startUpdatingLocation()
        startHKSession()

        standaloneTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickTimer()
        }
    }

    private func startHKSession() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )
            workoutSession = session
            workoutBuilder = builder
            session.startActivity(with: standaloneStartDate ?? Date())
            builder.beginCollection(withStart: standaloneStartDate ?? Date()) { _, _ in }
        } catch {
            // Simulator or no HealthKit — GPS-only mode, still works fine.
        }
    }

    // ─── Standalone run: timer tick ───────────────────────────────────────

    private func tickTimer() {
        guard isStandaloneMode, isRunning, !isPaused,
              let start = standaloneStartDate else { return }

        let elapsed = Date().timeIntervalSince(start) - standalonePausedDuration
        durationSeconds = Int(elapsed)

        // Pace
        if standaloneDistanceMeters > 0 {
            let paceSecsPerKm = Double(durationSeconds) / (standaloneDistanceMeters / 1000)
            paceString = Self.formatPace(paceSecsPerKm)
        }

        // HR from HealthKit live builder
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
           let stats = workoutBuilder?.statistics(for: hrType),
           let qty = stats.mostRecentQuantity() {
            heartRate = Int(qty.doubleValue(for: HKUnit(from: "count/min")))
        }

        // Calories from HealthKit live builder
        if let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let stats = workoutBuilder?.statistics(for: calType),
           let qty = stats.sumQuantity() {
            calories = Int(qty.doubleValue(for: .kilocalorie()))
        }
    }

    // ─── Standalone run: pause / resume ───────────────────────────────────

    func pauseStandaloneRun() {
        guard isStandaloneMode, !isPaused else { return }
        isPaused = true
        standalonePauseStart = Date()
        locationManager.stopUpdatingLocation()
        workoutSession?.pause()
    }

    func resumeStandaloneRun() {
        guard isStandaloneMode, isPaused else { return }
        if let ps = standalonePauseStart {
            standalonePausedDuration += Date().timeIntervalSince(ps)
        }
        standalonePauseStart = nil
        isPaused = false
        locationManager.startUpdatingLocation()
        workoutSession?.resume()
    }

    // ─── Standalone run: stop + send to phone ────────────────────────────

    func stopAndFinalizeRun() {
        guard isStandaloneMode else { return }

        standaloneTimer?.invalidate()
        standaloneTimer = nil
        locationManager.stopUpdatingLocation()

        isRunning = false
        isPaused = false
        isStandaloneMode = false

        let finalDuration = durationSeconds
        let finalDistance = standaloneDistanceMeters
        let finalHR = heartRate
        let finalCalories = calories
        let startTs = standaloneStartDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        let endTs = Date().timeIntervalSince1970
        let route: [[Double]] = standaloneRoutePoints.map {
            [$0.coordinate.latitude, $0.coordinate.longitude]
        }

        // Finalise HealthKit workout (saves to Health app)
        let endDate = Date()
        if let session = workoutSession, let builder = workoutBuilder {
            session.end()
            builder.endCollection(withEnd: endDate) { _, _ in
                builder.finishWorkout { _, _ in }
            }
            workoutSession = nil
            workoutBuilder = nil
        }

        // Reset display
        distanceKm = 0
        durationSeconds = 0
        paceString = "--:--"
        heartRate = 0
        calories = 0

        // transferUserInfo is queued — delivered even when iPhone is not
        // currently reachable (phone reconnects → iOS fires didReceiveUserInfo).
        let payload: [String: Any] = [
            "action": "completedWatchRun",
            "startTime": startTs,
            "endTime": endTs,
            "durationSeconds": finalDuration,
            "distanceMeters": finalDistance,
            "avgHeartRate": finalHR,
            "calories": finalCalories,
            "route": route
        ]
        WCSession.default.transferUserInfo(payload)
    }

    // ─── CLLocationManagerDelegate ────────────────────────────────────────

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isStandaloneMode, !isPaused else { return }
        for loc in locations {
            guard loc.horizontalAccuracy > 0, loc.horizontalAccuracy < 30 else { continue }
            if let last = lastLocation {
                standaloneDistanceMeters += loc.distance(from: last)
                distanceKm = standaloneDistanceMeters / 1000
            }
            lastLocation = loc
            standaloneRoutePoints.append(loc)
        }
    }

    // ─── Receive messages from phone ──────────────────────────────────────

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        handleMessage(message)
        replyHandler(["received": true])
    }

    private func handleMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        DispatchQueue.main.async {
            switch action {
            case "syncRunData":
                // Ignore phone sync when watch is recording its own run
                guard !self.isStandaloneMode else { return }
                let distM = message["distance"] as? Double ?? 0
                self.distanceKm      = distM / 1000
                self.durationSeconds = message["duration"] as? Int ?? 0
                self.heartRate       = message["heartRate"] as? Int ?? 0
                self.calories        = message["calories"] as? Int ?? 0
                self.isRunning       = message["isRunning"] as? Bool ?? false
                self.isPaused        = message["isPaused"] as? Bool ?? false
                let paceRaw = message["pace"] as? Double ?? 0
                self.paceString = paceRaw > 0 ? Self.formatPace(paceRaw) : "--:--"

            case "startRun":
                if !self.isStandaloneMode {
                    self.isRunning = true; self.isPaused = false
                }

            case "stopRun":
                if !self.isStandaloneMode {
                    self.isRunning = false; self.isPaused = false
                    self.distanceKm = 0; self.durationSeconds = 0
                    self.paceString = "--:--"; self.heartRate = 0; self.calories = 0
                }

            default: break
            }
        }
    }

    // ─── Send control commands to phone ───────────────────────────────────

    func sendPause()  { send(["action": "runPaused"])   }
    func sendResume() { send(["action": "runResumed"])  }
    func sendStop()   { send(["action": "runStopped"])  }

    private func send(_ message: [String: Any]) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(message, replyHandler: nil) { err in
            print("WatchSessionManager send error: \(err)")
        }
    }

    // ─── WCSessionDelegate boilerplate ────────────────────────────────────

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { self.isPhoneReachable = session.isReachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isPhoneReachable = session.isReachable }
    }

    // ─── Formatters ───────────────────────────────────────────────────────

    static func formatPace(_ secsPerKm: Double) -> String {
        let total = Int(secsPerKm)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
