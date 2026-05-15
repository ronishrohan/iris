import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            ProvidersSettingsView()
                .tabItem { Label("Providers", systemImage: "cpu") }

            WakeWordSettingsView()
                .tabItem { Label("Wake Word", systemImage: "waveform.badge.mic") }

            ToolsSettingsView()
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }

            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(20)
    }
}

private struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Activation") {
                Text("Global hotkey: ⌥-Space (configurable in a later update)")
                    .foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { appState.settings.launchAtLogin },
                    set: { appState.settings.launchAtLogin = $0 }
                ))
            }
        }
        .formStyle(.grouped)
    }
}

private struct ProvidersSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("DeepSeek (BYOK)") {
                SecureField("API Key", text: Binding(
                    get: { appState.settings.deepseekApiKey },
                    set: { appState.settings.deepseekApiKey = $0 }
                ))
                Picker("Default model", selection: Binding(
                    get: { appState.settings.defaultModel },
                    set: { appState.settings.defaultModel = $0 }
                )) {
                    Text("deepseek-v4-flash (fast, cheap)").tag("deepseek-v4-flash")
                    Text("deepseek-v4-pro (smarter, slower)").tag("deepseek-v4-pro")
                }
                Toggle("Use thinking mode for hard questions", isOn: Binding(
                    get: { appState.settings.useThinkingMode },
                    set: { appState.settings.useThinkingMode = $0 }
                ))
            }
            Section("Iris Subscription (optional)") {
                Text("Sign in to use Iris's proxy with no key required (coming soon).")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct WakeWordSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Wake Word") {
                Toggle("Enable wake-word listening", isOn: Binding(
                    get: { appState.settings.wakeWordEnabled },
                    set: { appState.settings.wakeWordEnabled = $0 }
                ))
                Slider(
                    value: Binding(
                        get: { appState.settings.wakeWordSensitivity },
                        set: { appState.settings.wakeWordSensitivity = $0 }
                    ),
                    in: 0...1
                ) { Text("Sensitivity") }
                Text("Phrase: \"hey iris\" (custom phrases coming soon)")
                    .foregroundStyle(.secondary)
            }
            Section("Speech-to-Text") {
                Picker("Engine", selection: Binding(
                    get: { appState.settings.sttEngine },
                    set: { appState.settings.sttEngine = $0 }
                )) {
                    Text("Apple Speech (fast, native)").tag("apple")
                    Text("WhisperKit (higher accuracy)").tag("whisper")
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ToolsSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Built-in tools") {
                ForEach(ToolRegistry.builtIns, id: \.name) { tool in
                    Toggle(tool.displayName, isOn: Binding(
                        get: { appState.settings.isToolEnabled(tool.name) },
                        set: { appState.settings.setTool(tool.name, enabled: $0) }
                    ))
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.purple, .pink)
            Text("Iris").font(.title2).bold()
            Text("v0.1.0").foregroundStyle(.secondary)
            Text("A SwiftUI Siri replacement.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
