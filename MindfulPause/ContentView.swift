import SwiftUI

struct ContentView: View {
    enum TimerState {
        case idle
        case waiting
        case triggered
    }

    @State private var state: TimerState = .idle
    @State private var endTime: Date?
    @State private var remainingSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?

    private let textColor = Color(red: 0.18, green: 0.20, blue: 0.18)
    private let mutedColor = Color(red: 0.40, green: 0.43, blue: 0.40)
    private let accentColor = Color(red: 0.54, green: 0.60, blue: 0.55)
    private let backgroundColor = Color(red: 0.96, green: 0.94, blue: 0.92)

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 32) {
                switch state {
                case .idle:      idleView
                case .waiting:   waitingView
                case .triggered: triggeredView
                }
            }
            .padding()
            .animation(.easeInOut(duration: 0.4), value: state)
        }
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
        let durationSeconds = 5
        endTime = Date().addingTimeInterval(TimeInterval(durationSeconds))
        remainingSeconds = durationSeconds
        state = .waiting

        timerTask = Task {
            while !Task.isCancelled {
                guard let endTime else { break }
                let remaining = Int(endTime.timeIntervalSinceNow)
                if remaining <= 0 {
                    await MainActor.run { self.state = .triggered }
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
    }

    private func reset() {
        timerTask?.cancel()
        timerTask = nil
        endTime = nil
        state = .idle
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
