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
    @State private var currentTip: String = ""
    @FocusState private var triggerFocused: Bool

    private let textColor = Color(red: 0.18, green: 0.20, blue: 0.18)
    private let mutedColor = Color(red: 0.40, green: 0.43, blue: 0.40)
    private let accentColor = Color(red: 0.54, green: 0.60, blue: 0.55)
    private let backgroundColor = Color(red: 0.96, green: 0.94, blue: 0.92)

    private let tips = [
        "Сделай три глубоких вдоха. Физиология успокаивается быстрее, чем думаешь.",
        "Встань и пройдись по комнате. Движение разрывает замкнутый круг.",
        "Умой лицо холодной водой. Это простая перезагрузка.",
        "Позвони другу или напиши кому-то. Связь с другим человеком обнуляет тягу.",
        "Запиши, что чувствуешь, одной фразой. Формулировка снимает напряжение.",
        "Посмотри в окно 30 секунд. Переключи внимание на что-то внешнее.",
        "Сделай 10 приседаний. Физическая нагрузка перехватывает управление у мозга.",
        "Выпей стакан воды медленно. Вкус и ощущение возвращают в тело.",
        "Открой дверь и выйди на воздух. Даже минута на улице меняет контекст.",
        "Надень наушники и включи любой подкаст на 2 минуты. Переключение канала."
    ]

    private let userDefaultsKey = "MindfulPauseTimerState"
    private let notificationId = "MindfulPauseTimerNotification"

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 32) {
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
            .animation(.easeInOut(duration: 0.4), value: state)
        }
        .onAppear { restoreState() }
    }

    private var idleView: some View {
        VStack(spacing: 32) {
            Text("Подожди.\nДай мозгу время переключиться.")
                .font(.system(size: 20, weight: .light, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(mutedColor)
                .padding(.bottom, 16)

            Button(action: startTimer) {
                Text("Запустить таймер")
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
            Text("Просто подожди.\nНе нужно бороться.")
                .font(.system(size: 18, weight: .light, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(mutedColor)

            Text(formatTime(remainingSeconds))
                .font(.system(size: 72, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textColor)

            Button("Отменить", action: cancelTimer)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(textColor)
                .padding(.top, 16)
        }
    }

    private var triggeredView: some View {
        VStack(spacing: 16) {
            Text("Таймер сработал.")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(textColor)

            Text("Можешь идти делать то, что хотел.")
                .font(.system(size: 18, weight: .light, design: .rounded))
                .foregroundStyle(mutedColor)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button("Я сделал(а)", action: goResisted)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(accentColor)
                    .clipShape(Capsule())

                Button("Я передумал(а)", action: goReflection)
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
            Text("Окей.")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(textColor)

            Text("Ты увидел тягу. Ты подождал. Это уже движение.")
                .font(.system(size: 18, weight: .light, design: .rounded))
                .foregroundStyle(mutedColor)
                .multilineTextAlignment(.center)

            Button("Завершить", action: reset)
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
            Text("Что помогло прямо сейчас?\nЧто стало триггером?")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)

            TextField("Опиши ситуацию", text: $trigger)
                .font(.system(size: 16, weight: .light, design: .rounded))
                .foregroundStyle(textColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(red: 0.99, green: 0.97, blue: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($triggerFocused)
                .submitLabel(.done)
                .onSubmit {
                    if !trigger.isEmpty { goTip() }
                }
                .padding(.top, 8)

            Button("Получить подсказку", action: goTip)
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
            Text("Запомни это — оно сработало.")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(textColor)

            Text(currentTip)
                .font(.system(size: 18, weight: .light, design: .rounded))
                .foregroundStyle(mutedColor)
                .multilineTextAlignment(.center)

            Button("Завершить", action: reset)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(accentColor)
                .clipShape(Capsule())
                .padding(.top, 24)
        }
    }

    private func startTimer() {
        let durationMinutes = Int.random(in: 6...15)
        let durationSeconds = durationMinutes * 60
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
        timerTask?.cancel()
        timerTask = nil
        endTime = nil
        state = .idle
        cancelScheduledNotification()
        saveState()
    }

    private func reset() {
        timerTask?.cancel()
        timerTask = nil
        endTime = nil
        trigger = ""
        state = .idle
        cancelScheduledNotification()
        saveState()
    }

    private func goResisted() {
        trigger = ""
        state = .resisted
        saveState()
    }

    private func goReflection() {
        state = .reflection
        saveState()
    }

    private func goTip() {
        triggerFocused = false
        currentTip = tips.randomElement() ?? ""
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
        content.title = "Таймер сработал"
        content.body = "Можешь идти делать то, что хотел."
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
