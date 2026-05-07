import SwiftUI
import UserNotifications

private struct SavedState: Codable {
    let state: ContentView.TimerState
    let endTime: Date?
    let trigger: String
    let outcome: ContentView.Outcome?
}

enum Habit: String, Codable, CaseIterable, Identifiable {
    case smoking
    case snus
    case socialMedia
    case alcohol
    case food
    case other

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .smoking:     return "Smoking"
        case .snus:        return "Snus / vape"
        case .socialMedia: return "Social media"
        case .alcohol:     return "Alcohol"
        case .food:        return "Overeating"
        case .other:       return "Other"
        }
    }

    // English label sent to the LLM as context (always English regardless of UI locale).
    var llmContext: String {
        switch self {
        case .smoking:     return "smoking"
        case .snus:        return "snus or vape"
        case .socialMedia: return "doomscrolling on social media"
        case .alcohol:     return "drinking alcohol"
        case .food:        return "compulsive eating"
        case .other:       return "a personal harmful habit"
        }
    }
}

struct ContentView: View {
    enum TimerState: String, Codable {
        case idle
        case waiting
        case triggered
        case reflection
        case tip
    }

    enum Outcome: String, Codable {
        case resisted
        case relapsed
    }

    @State private var state: TimerState = .idle
    @State private var endTime: Date?
    @State private var remainingSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var trigger: String = ""
    @State private var currentTip: LocalizedStringResource?
    @State private var outcome: Outcome?
    @FocusState private var triggerFocused: Bool

    @State private var habit: Habit?
    @State private var customHabit: String = ""
    @State private var showOnboarding: Bool = false

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
    private let habitKey = "MindfulPauseHabit"
    private let customHabitKey = "MindfulPauseCustomHabit"
    private let notificationId = "MindfulPauseTimerNotification"

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            if showOnboarding || habit == nil {
                onboardingView
                    .padding()
                    .transition(.opacity)
            } else {
                Group {
                    switch state {
                    case .idle:      idleView
                    case .waiting:   waitingView
                    case .triggered: triggeredView
                    case .reflection: reflectionView
                    case .tip:       tipView
                    }
                }
                .padding()
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: state)

                if state == .idle {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: openOnboarding) {
                                Text("Change habit")
                                    .font(.system(size: 13, weight: .light, design: .rounded))
                                    .foregroundStyle(mutedColor)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showOnboarding)
        .animation(.easeInOut(duration: 0.4), value: habit)
        .onAppear {
            loadHabit()
            restoreState()
        }
    }

    private var onboardingView: some View {
        VStack(spacing: 20) {
            Text("What are you trying to delay?")
                .font(.system(size: 24, weight: .light, design: .rounded))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            ForEach(Habit.allCases) { h in
                Button(action: { selectHabit(h) }) {
                    Text(h.displayName)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(habit == h ? accentColor.opacity(0.7) : accentColor)
                        .clipShape(Capsule())
                }
            }

            if habit == .other {
                TextField("Type your habit", text: $customHabit)
                    .font(.system(size: 16, weight: .light, design: .rounded))
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.95, green: 0.91, blue: 0.84))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .submitLabel(.done)
                    .onSubmit { confirmOnboarding() }
            }

            Button(action: confirmOnboarding) {
                Text("Continue")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(canConfirmOnboarding ? accentColor : mutedColor)
                    .clipShape(Capsule())
            }
            .disabled(!canConfirmOnboarding)
            .padding(.top, 8)
        }
    }

    private var canConfirmOnboarding: Bool {
        guard let habit else { return false }
        if habit == .other { return !customHabit.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
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
                Button("I waited it out", action: markResisted)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(accentColor)
                    .clipShape(Capsule())

                Button("I gave in", action: markRelapsed)
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

    private var reflectionQuestion: LocalizedStringResource {
        outcome == .relapsed ? "What was the trigger?" : "What helped right now?"
    }

    private var tipTitle: LocalizedStringResource {
        outcome == .relapsed ? "No judgment. Just notice." : "Remember this — it worked."
    }

    private var reflectionView: some View {
        VStack(spacing: 16) {
            Text(reflectionQuestion)
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
            Text(tipTitle)
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)

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

    private func selectHabit(_ h: Habit) {
        haptic(.light)
        habit = h
    }

    private func confirmOnboarding() {
        guard canConfirmOnboarding, let habit else { return }
        haptic(.medium)
        UserDefaults.standard.set(habit.rawValue, forKey: habitKey)
        if habit == .other {
            UserDefaults.standard.set(customHabit.trimmingCharacters(in: .whitespaces), forKey: customHabitKey)
        } else {
            UserDefaults.standard.removeObject(forKey: customHabitKey)
        }
        showOnboarding = false
    }

    private func openOnboarding() {
        haptic(.light)
        showOnboarding = true
    }

    private func loadHabit() {
        if let raw = UserDefaults.standard.string(forKey: habitKey),
           let saved = Habit(rawValue: raw) {
            habit = saved
            customHabit = UserDefaults.standard.string(forKey: customHabitKey) ?? ""
        }
    }

    private func startTimer() {
        haptic(.medium)
        let durationSeconds = Int.random(in: 360...900)
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
        outcome = nil
        state = .idle
        cancelScheduledNotification()
        saveState()
    }

    private func markResisted() {
        haptic(.medium)
        outcome = .resisted
        state = .reflection
        saveState()
    }

    private func markRelapsed() {
        haptic(.medium)
        outcome = .relapsed
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
        let data = SavedState(state: state, endTime: endTime, trigger: trigger, outcome: outcome)
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
        outcome = saved.outcome

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
