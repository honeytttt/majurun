import Foundation
import WatchConnectivity

/// Receives run data from the phone and exposes it to SwiftUI views.
/// Also sends control commands (pause, stop) back to the phone.
class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchSessionManager()

    // ─── Published run state ───────────────────────────────────────────────
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    @Published var distanceKm: Double = 0
    @Published var durationSeconds: Int = 0
    @Published var paceString: String = "--:--"
    @Published var heartRate: Int = 0
    @Published var calories: Int = 0
    @Published var isPhoneReachable: Bool = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // ─── Receive data from phone ───────────────────────────────────────────

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
                let distanceMeters = message["distance"] as? Double ?? 0
                self.distanceKm   = distanceMeters / 1000
                self.durationSeconds = message["duration"] as? Int ?? 0
                self.heartRate    = message["heartRate"] as? Int ?? 0
                self.calories     = message["calories"] as? Int ?? 0
                self.isRunning    = message["isRunning"] as? Bool ?? false
                self.isPaused     = message["isPaused"] as? Bool ?? false

                // Format pace from seconds/km
                let paceRaw = message["pace"] as? Double ?? 0
                self.paceString = paceRaw > 0 ? Self.formatPace(paceRaw) : "--:--"

            case "startRun":
                self.isRunning = true
                self.isPaused  = false

            case "stopRun":
                self.isRunning = false
                self.isPaused  = false
                self.distanceKm      = 0
                self.durationSeconds = 0
                self.paceString      = "--:--"
                self.heartRate       = 0
                self.calories        = 0

            default:
                break
            }
        }
    }

    // ─── Send control commands to phone ───────────────────────────────────

    func sendPause() {
        send(["action": "runPaused"])
    }

    func sendResume() {
        send(["action": "runResumed"])
    }

    func sendStop() {
        send(["action": "runStopped"])
    }

    private func send(_ message: [String: Any]) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("WatchSessionManager send error: \(error)")
        })
    }

    // ─── WCSessionDelegate boilerplate ────────────────────────────────────

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────

    static func formatPace(_ secsPerKm: Double) -> String {
        let total = Int(secsPerKm)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    static func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
