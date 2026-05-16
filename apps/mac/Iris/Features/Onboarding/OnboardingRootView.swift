import SwiftUI
import EventKit
import Contacts
import Speech
import AVFoundation

private let kPad: CGFloat = 24
private let kRadius: CGFloat = 32

// MARK: - Root
struct OnboardingRootView: View {
    let appState: AppState
    let onComplete: () -> Void

    enum Step { case splash, permissions, finish }
    @State private var step: Step = .splash

    private func size(for s: Step) -> NSSize {
        switch s {
        case .splash:      return NSSize(width: 440, height: 440)
        case .permissions: return NSSize(width: 480, height: 520)
        case .finish:      return NSSize(width: 440, height: 440)
        }
    }

    var body: some View {
        ZStack {
            // Nebula always present, full bleed
            Color.black
                .ignoresSafeArea()
            NebulaView(intensity: 1.0)
                .ignoresSafeArea()

            switch step {
            case .splash:
                SplashContent(onNext: { advance(to: .permissions) })
            case .permissions:
                PermissionsContent(onDone: { advance(to: .finish) })
            case .finish:
                FinishContent(onFinish: {
                    appState.settings.hasCompletedOnboarding = true
                    onComplete()
                })
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: kRadius, style: .continuous))
    }

    private func advance(to next: Step) {
        let target = size(for: next)
        guard let win = NSApp.keyWindow else { step = next; return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.38
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            win.animator().setContentSize(target)
        }, completionHandler: {
            win.center()
            step = next
        })
    }
}

// MARK: - Splash
private struct SplashContent: View {
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("IRIS")
                .font(.system(size: 82, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.bottom, 6)

            Text("The only assistant\nyou'll ever need")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(4)

            Spacer()

            HStack {
                Spacer()
                Button("Next", action: onNext)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Color(red: 0.87, green: 0.29, blue: 0.22))
            }
        }
        .padding(kPad)
        .frame(width: 440, height: 440, alignment: .topLeading)
    }
}

// MARK: - Permissions
private struct PermissionsContent: View {
    let onDone: () -> Void

    struct Permission: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        var status: Status = .pending
        enum Status { case pending, granted, denied }
    }

    @State private var permissions: [Permission] = [
        Permission(icon: "mic.fill",           title: "Microphone",         description: "Hear your voice and the wake phrase."),
        Permission(icon: "waveform",           title: "Speech Recognition", description: "Transcribe your speech on-device."),
        Permission(icon: "person.crop.circle", title: "Contacts",           description: "Send messages and emails to people you know."),
        Permission(icon: "calendar",           title: "Calendar",           description: "Create and read your calendar events."),
        Permission(icon: "checklist",          title: "Reminders",          description: "Add and list your reminders."),
    ]
    @State private var currentIndex = 0
    @State private var isRequesting = false

    var allHandled: Bool { permissions.allSatisfy { $0.status != .pending } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Permissions")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Iris needs access to do its thing.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer().frame(height: 20)

            VStack(spacing: 8) {
                ForEach(Array(permissions.enumerated()), id: \.element.id) { idx, perm in
                    PermissionRow(
                        permission: perm,
                        isActive: idx == currentIndex && !allHandled,
                        onGrant: { requestPermission(at: idx) },
                        onSkip:  { skipPermission(at: idx) }
                    )
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Continue", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Color(red: 0.87, green: 0.29, blue: 0.22))
                    .disabled(!allHandled)
                    .animation(.easeInOut(duration: 0.2), value: allHandled)
            }
        }
        .padding(kPad)
        .frame(width: 480, height: 520, alignment: .topLeading)
    }

    private func requestPermission(at idx: Int) {
        guard !isRequesting else { return }
        isRequesting = true
        Task { @MainActor in
            let granted: Bool
            switch permissions[idx].title {
            case "Microphone":         granted = await requestMicrophone()
            case "Speech Recognition": granted = await requestSpeech()
            case "Contacts":           granted = await requestContacts()
            case "Calendar":           granted = await requestCalendar()
            case "Reminders":          granted = await requestReminders()
            default:                   granted = false
            }
            permissions[idx].status = granted ? .granted : .denied
            isRequesting = false
            if let next = permissions.enumerated().first(where: { $0.offset > idx && $0.element.status == .pending }) {
                currentIndex = next.offset
            } else {
                currentIndex = permissions.count
            }
        }
    }

    private func skipPermission(at idx: Int) {
        permissions[idx].status = .denied
        if let next = permissions.enumerated().first(where: { $0.offset > idx && $0.element.status == .pending }) {
            currentIndex = next.offset
        } else {
            currentIndex = permissions.count
        }
    }

    private func requestMicrophone() async -> Bool {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { ok in DispatchQueue.main.async { cont.resume(returning: ok) } }
        }
    }
    private func requestSpeech() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { s in DispatchQueue.main.async { cont.resume(returning: s == .authorized) } }
        }
    }
    private func requestContacts() async -> Bool {
        let store = CNContactStore()
        return await withCheckedContinuation { cont in
            store.requestAccess(for: .contacts) { ok, _ in DispatchQueue.main.async { cont.resume(returning: ok) } }
        }
    }
    private func requestCalendar() async -> Bool {
        let store = EKEventStore()
        return await withCheckedContinuation { cont in
            store.requestFullAccessToEvents { ok, _ in DispatchQueue.main.async { cont.resume(returning: ok) } }
        }
    }
    private func requestReminders() async -> Bool {
        let store = EKEventStore()
        return await withCheckedContinuation { cont in
            store.requestFullAccessToReminders { ok, _ in DispatchQueue.main.async { cont.resume(returning: ok) } }
        }
    }
}

// MARK: - Permission row
private struct PermissionRow: View {
    let permission: PermissionsContent.Permission
    let isActive: Bool
    let onGrant: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 36, height: 36)
                Image(systemName: permission.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconFg)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.5))
                Text(permission.description)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineLimit(1)
            }

            Spacer()

            if isActive {
                HStack(spacing: 6) {
                    Button("Skip", action: onSkip)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Button("Allow", action: onGrant)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(Color(red: 0.87, green: 0.29, blue: 0.22))
                }
            } else {
                statusIcon
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(isActive ? .white.opacity(0.07) : .white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .animation(.easeInOut(duration: 0.2), value: permission.status)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch permission.status {
        case .pending:
            Circle().fill(.white.opacity(0.1)).frame(width: 7, height: 7)
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(red: 0.27, green: 0.75, blue: 0.44))
        case .denied:
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.2))
        }
    }

    private var iconBg: Color {
        switch permission.status {
        case .granted: return Color(red: 0.27, green: 0.75, blue: 0.44).opacity(0.15)
        case .denied:  return .white.opacity(0.05)
        case .pending: return isActive ? Color(red: 0.87, green: 0.29, blue: 0.22).opacity(0.15) : .white.opacity(0.05)
        }
    }
    private var iconFg: Color {
        switch permission.status {
        case .granted: return Color(red: 0.27, green: 0.75, blue: 0.44)
        case .denied:  return .white.opacity(0.2)
        case .pending: return isActive ? Color(red: 0.87, green: 0.29, blue: 0.22) : .white.opacity(0.25)
        }
    }
}

// MARK: - Finish
private struct FinishContent: View {
    let onFinish: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.9), Color(red: 0.87, green: 0.29, blue: 0.22))
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.05), value: appeared)

                VStack(spacing: 5) {
                    Text("You're all set.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 8)
                        .animation(.easeOut(duration: 0.3).delay(0.15), value: appeared)

                    Text("Press ⌥-Space anytime to summon Iris.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 6)
                        .animation(.easeOut(duration: 0.3).delay(0.2), value: appeared)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Let's go", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Color(red: 0.87, green: 0.29, blue: 0.22))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.3).delay(0.25), value: appeared)
            }
        }
        .padding(kPad)
        .frame(width: 440, height: 440)
        .onAppear { appeared = true }
    }
}
