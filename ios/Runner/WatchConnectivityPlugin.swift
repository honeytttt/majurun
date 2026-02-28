import Flutter
import WatchConnectivity

/// Plugin to handle communication with Apple Watch
class WatchConnectivityPlugin: NSObject, FlutterPlugin, WCSessionDelegate {

    private var channel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = WatchConnectivityPlugin()

        let methodChannel = FlutterMethodChannel(
            name: "com.majurun.app/watch",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        instance.channel = methodChannel

        let eventChannel = FlutterEventChannel(
            name: "com.majurun.app/watch_events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)

        // Activate WCSession
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = instance
            session.activate()
        }
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkWatchStatus":
            checkWatchStatus(result: result)
        case "startRun":
            startRun(result: result)
        case "stopRun":
            stopRun(result: result)
        case "syncRunData":
            if let args = call.arguments as? [String: Any] {
                syncRunData(args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
            }
        case "syncWorkout":
            if let args = call.arguments as? [String: Any] {
                syncWorkout(args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
            }
        case "getHeartRate":
            getHeartRate(result: result)
        case "requestPermissions":
            requestPermissions(result: result)
        case "openWatchApp":
            openWatchApp(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func checkWatchStatus(result: @escaping FlutterResult) {
        guard WCSession.isSupported() else {
            result([
                "connected": false,
                "appInstalled": false,
                "platform": "watchos"
            ])
            return
        }

        let session = WCSession.default
        result([
            "connected": session.isReachable,
            "appInstalled": session.isWatchAppInstalled,
            "platform": "watchos"
        ])
    }

    private func startRun(result: @escaping FlutterResult) {
        guard WCSession.default.isReachable else {
            result(false)
            return
        }

        WCSession.default.sendMessage(["action": "startRun"], replyHandler: { response in
            result(response["success"] as? Bool ?? false)
        }, errorHandler: { error in
            print("Start run error: \(error)")
            result(false)
        })
    }

    private func stopRun(result: @escaping FlutterResult) {
        guard WCSession.default.isReachable else {
            result(false)
            return
        }

        WCSession.default.sendMessage(["action": "stopRun"], replyHandler: { response in
            result(response["success"] as? Bool ?? false)
        }, errorHandler: { error in
            print("Stop run error: \(error)")
            result(false)
        })
    }

    private func syncRunData(_ data: [String: Any], result: @escaping FlutterResult) {
        guard WCSession.default.isReachable else {
            result(nil)
            return
        }

        var message = data
        message["action"] = "syncRunData"

        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("Sync run data error: \(error)")
        })
        result(nil)
    }

    private func syncWorkout(_ data: [String: Any], result: @escaping FlutterResult) {
        guard WCSession.default.isReachable else {
            result(false)
            return
        }

        var message = data
        message["action"] = "syncWorkout"

        do {
            try WCSession.default.updateApplicationContext(message)
            result(true)
        } catch {
            print("Sync workout error: \(error)")
            result(false)
        }
    }

    private func getHeartRate(result: @escaping FlutterResult) {
        guard WCSession.default.isReachable else {
            result(nil)
            return
        }

        WCSession.default.sendMessage(["action": "getHeartRate"], replyHandler: { response in
            result(response["heartRate"] as? Int)
        }, errorHandler: { error in
            print("Get heart rate error: \(error)")
            result(nil)
        })
    }

    private func requestPermissions(result: @escaping FlutterResult) {
        // Permissions are handled in the watch app
        result(true)
    }

    private func openWatchApp(result: @escaping FlutterResult) {
        // Open companion app on watch
        if #available(iOS 10.0, *) {
            WCSession.default.sendMessage(["action": "openApp"], replyHandler: nil, errorHandler: nil)
        }
        result(nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.eventSink?([
                "type": "connection_changed",
                "connected": session.isReachable
            ])
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleWatchMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleWatchMessage(message)
        replyHandler(["received": true])
    }

    private func handleWatchMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        DispatchQueue.main.async {
            switch action {
            case "runStarted":
                self.eventSink?(["type": "run_started"])
            case "runPaused":
                self.eventSink?(["type": "run_paused"])
            case "runResumed":
                self.eventSink?(["type": "run_resumed"])
            case "runStopped":
                var event: [String: Any] = ["type": "run_stopped"]
                if let distance = message["distance"] {
                    event["distance"] = distance
                }
                if let duration = message["duration"] {
                    event["duration"] = duration
                }
                self.eventSink?(event)
            case "heartRateUpdate":
                self.eventSink?([
                    "type": "heart_rate_update",
                    "heartRate": message["heartRate"] ?? 0
                ])
            default:
                break
            }
        }
    }
}

// MARK: - FlutterStreamHandler

extension WatchConnectivityPlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
