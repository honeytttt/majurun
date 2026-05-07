import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        if session.isRunning || session.isPaused {
            RunView()
        } else {
            IdleView()
        }
    }
}

// ─── Idle (no active run) ─────────────────────────────────────────────────────

struct IdleView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run")
                .font(.system(size: 36))
                .foregroundColor(.green)

            Text("MajuRun")
                .font(.headline)
                .foregroundColor(.white)

            Text(session.isPhoneReachable ? "Phone connected" : "No phone")
                .font(.caption2)
                .foregroundColor(session.isPhoneReachable ? .green : .gray)
                .multilineTextAlignment(.center)

            // Start a standalone run directly from the watch
            Button(action: { session.startStandaloneRun() }) {
                Text("Start Run")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 2)
        }
        .padding()
    }
}

// ─── Active run ───────────────────────────────────────────────────────────────

struct RunView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Status badge
                HStack {
                    Circle()
                        .fill(session.isPaused ? Color.yellow : Color.green)
                        .frame(width: 8, height: 8)
                    Text(session.isPaused ? "PAUSED" : "RUNNING")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(session.isPaused ? .yellow : .green)

                    if session.isStandaloneMode {
                        Text("• WATCH")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)

                // Distance — primary metric
                VStack(spacing: 0) {
                    Text(String(format: "%.2f", session.distanceKm))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("KM")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 10)

                // Stats grid: Duration / Pace
                HStack(spacing: 0) {
                    StatCell(
                        value: WatchSessionManager.formatDuration(session.durationSeconds),
                        label: "TIME"
                    )
                    Divider()
                        .frame(height: 32)
                        .background(Color.gray.opacity(0.3))
                    StatCell(
                        value: session.paceString,
                        label: "/KM"
                    )
                }
                .padding(.bottom, 8)

                // HR / Calories
                HStack(spacing: 0) {
                    StatCell(
                        value: session.heartRate > 0 ? "\(session.heartRate)" : "--",
                        label: "BPM",
                        color: session.heartRate > 0 ? .red : .gray
                    )
                    Divider()
                        .frame(height: 32)
                        .background(Color.gray.opacity(0.3))
                    StatCell(
                        value: "\(session.calories)",
                        label: "KCAL"
                    )
                }
                .padding(.bottom, 12)

                // Controls — behaviour differs for standalone vs companion mode
                HStack(spacing: 12) {
                    // Pause / Resume
                    Button(action: {
                        if session.isPaused {
                            if session.isStandaloneMode {
                                session.resumeStandaloneRun()
                            } else {
                                session.sendResume()
                            }
                        } else {
                            if session.isStandaloneMode {
                                session.pauseStandaloneRun()
                            } else {
                                session.sendPause()
                            }
                        }
                    }) {
                        Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.blue.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Stop
                    Button(action: {
                        if session.isStandaloneMode {
                            session.stopAndFinalizeRun()
                        } else {
                            session.sendStop()
                        }
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.red.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// ─── Stat Cell ────────────────────────────────────────────────────────────────

struct StatCell: View {
    let value: String
    let label: String
    var color: Color = .white

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}
