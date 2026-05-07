import SwiftUI
import UserNotifications

private struct SavedState: Codable {
    let state: ContentView.TimerState
    let endTime: Date?
    let trigger: String
}

struct ContentView: View {
    enum TimerState: String, Codable {
        case idle
        case waiting
        case triggered
        case resisted
        case reflection
        case tip
    }

    @State private var state: TimerState = .idle
    @State private var endTime: Date?
    @State private var remainingSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var trigger: String = ""
    @State private var currentTip: LocalizedStringResource?
    @FocusState private var triggerFocused: Bool

    private let textColor = Color(red: 0.18, green: 0.15, blue: 0.10)
    private let mutedColor = Color(red: 0.42, green: 0.37, blue: 0.28)
    private let accentColor = Color(red: 0.46, green: 0.52, blue: 0.42)
    private let backgroundColor = Color(red: 0.88, green: 0.82, blue: 0.73)

    private let tips: [LocalizedStringResource] = [
        "Take three deep breaths. Physiology calms down faster than you think.",
        "Stand up and walk around the room. Movement breaks the loop.",
        "Splash cold water on your face. Simple reset.",
        "Call or text a friend. Connection resets the urge.",
        "Write what you're feeling in one phrase. Naming reduces tension.",
        "Look out the window for 30 seconds. Shift attention outward.",
        "Do 10 squats. Physical effort takes control back from the brain.",
        "Drink a glass of water slowly. Taste and sensation bring you back to your body.",
        "Open the door and step outside. Even a minute of fresh air shifts the context.",
        "Put on headphones and play any podcast for 2 minutes. Channel switch."
    ]

    private let userDefaultsKey = "MindfulPauseTimerState"
    private let notificationId = "MindfulPauseTimerNotification"

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            Group {
                switch state {
                case .idle:      idleView
                case .waiting:   waitingView
                case .triggered: triggeredView
                case .resisted:  resistedView
                case .reflection: reflectionView
                case .tip:       tipView
                }
            }
            .padding()
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.4), value: state)
        }
        .onAppear { restoreState() }
    }

    private var idleView: some View {
        VStack(spacing: 32) {
            Text("Wait.\nGive your brain time to switch.")
                .font(.system(size: 20, weight: .light, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(mutedColor)
                .padding(.bottom, 16)

            Button(action: startTimer) {
                Text("Start timer")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 22)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
        }
    }

    private var waitingView: some View {
        VStack(spacing: 24) {
            Text("Just wait.\nNo need to fight.")
                .font(.system(size: 18, weight: .light, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(mutedColor)

            Text(formatTime(remainingSeconds))
                .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textColor)

            Button("Cancel", action: cancelTimer)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(textColor)
                .padding(.top, 16)
        }
    }

    private var triggeredView: some View {
        VStack(spacing: 16) {
            Text("Timer is up")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(textColor)

            Text("You can go do what you wanted.")
                .font(.system(size: 18, weight: .light, design: .rounded))
                .foregroundStyle(mutedColor)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button("I did it", action: goResisted)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(accentColor)
                    .clipShape(Capsule())

                Button("I changed my mind", action: goReflection)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
            .padding(.top, 24)
        }
    }

    private var resistedView: some View {
        VStack(spacing: 16) {
            Text("Okay.")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(textColor)

            Text("You noticed the urge. You waited. That's already movement.")
                .font(.system(size: 18, weight: .light, design: .rounded))
                .foregroundStyle(mutedColor)
                .multilineTextAlignment(.center)

            Button("Done", action: reset)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(accentColor)
                .clipShape(Capsule())
                .padding(.top, 24)
        }
    }

    private var reflectionView: some View {
        VStack(spacing: 16) {
            Text("What helped right now?\nWhat was the trigger?")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)

            TextField("Describe the situation", text: $trigger)
                .font(.system(size: 16, weight: .light, design: .rounded))
                .foregroundStyle(textColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(red: 0.95, green: 0.91, blue: 0.84))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($triggerFocused)
                .submitLabel(.done)
                .onSubmit {
                    if !trigger.isEmpty { goTip() }
                }
                .padding(.top, 8)

            Button("Get a tip", action: goTip)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(trigger.isEmpty ? mutedColor : accentColor)
                .clipShape(Capsule())
                .disabled(trigger.isEmpty)
                .padding(.top, 8)
        }
    }

    private var tipView: some View {
        VStack(spacing: 16) {
            Text("Remember this — it worked.")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(textColor)

            if let currentTip {
                Text(currentTip)
                    .font(.system(size: 18, weight: .light, design: .rounded))
                    .foregroundStyle(mutedColor)
                    .multilineTextAlignment(.center)
            }

            Button("Done", action: reset)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(accentColor)
                .clipShape(Capsule())
                .padding(.top, 24)
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func startTimer() {
        haptic(.medium)
        let durationSeconds = 5
        let fireDate = Date().addingTimeInterval(TimeInterval(durationSeconds))
        endTime = fireDate
        remainingSeconds = durationSeconds
        state = .waiting
        saveState()
        requestAndScheduleNotification(at: fireDate)

        timerTask = Task {
            while !Task.isCancelled {
                guard let endTime else { break }
                let remaining = Int(endTime.timeIntervalSinceNow)
                if remaining <= 0 {
                    await MainActor.run { self.state = .triggered; self.saveState() }
                    break
                }
                await MainActor.run { self.remainingSeconds = remaining }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func cancelTimer() {
        haptic(.light)
        timerTask?.cancel()
        timerTask = nil
        endTime = nil
        state = .idle
        cancelScheduledNotification()
        saveState()
    }

    private func reset() {
        haptic(.light)
        timerTask?.cancel()
        timerTask = nil
        endTime = nil
        trigger = ""
        state = .idle
        cancelScheduledNotification()
        saveState()
    }

    private func goResisted() {
        haptic(.medium)
        trigger = ""
        state = .resisted
        saveState()
    }

    private func goReflection() {
        haptic(.medium)
        state = .reflection
        saveState()
    }

    private func goTip() {
        haptic(.medium)
        triggerFocused = false
        currentTip = tips.randomElement()
        state = .tip
        saveState()
    }

    private func saveState() {
        let data = SavedState(state: state, endTime: endTime, trigger: trigger)
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let saved = try? JSONDecoder().decode(SavedState.self, from: data) else { return }
        state = saved.state
        endTime = saved.endTime
        trigger = saved.trigger

        if state == .waiting, let endTime, endTime <= Date() {
            self.endTime = nil
            state = .triggered
            return
        }

        if state == .waiting {
            remainingSeconds = max(0, Int(endTime?.timeIntervalSinceNow ?? 0))
            startTimerFromSaved()
        }
    }

    private func startTimerFromSaved() {
        timerTask = Task {
            while !Task.isCancelled {
                guard let endTime else { break }
                let remaining = Int(endTime.timeIntervalSinceNow)
                if remaining <= 0 {
                    await MainActor.run { self.state = .triggered; self.saveState() }
                    break
                }
                await MainActor.run { self.remainingSeconds = remaining }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func requestAndScheduleNotification(at fireDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            scheduleNotification(at: fireDate)
        }
    }

    private func scheduleNotification(at fireDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])

        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Timer is up")
        content.body = String(localized: "You can go do what you wanted.")
        content.sound = .default

        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: notificationTrigger)
        center.add(request)
    }

    private func cancelScheduledNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    ContentView()
}
