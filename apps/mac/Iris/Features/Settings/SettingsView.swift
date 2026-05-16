import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            ProvidersSettingsView()
                .tabItem { Label("Provider", systemImage: "cpu") }

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
                Text("Double-tap the Option key, or press ⌥-Space, to open Iris.")
                    .foregroundStyle(.secondary)
            }
            Section("Voice") {
                Toggle("Listen for \u{201C}Hey Iris\u{201D} wake phrase", isOn: Binding(
                    get: { appState.settings.wakeWordEnabled },
                    set: { v in
                        appState.settings.wakeWordEnabled = v
                        appState.applyWakeWordSetting()
                    }
                ))
                Text("When on, Iris keeps the microphone open in the background to hear the wake phrase. When off, the mic is only opened when you click the mic button inside the panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Start listening when I open Iris via shortcut", isOn: Binding(
                    get: { appState.settings.voiceOnShortcut },
                    set: { appState.settings.voiceOnShortcut = $0 }
                ))
                Text("If off, opening Iris via the shortcut leaves you in text mode until you click the mic button.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text("Get a key at platform.deepseek.com → API keys.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            Text("v0.1.0-poc").foregroundStyle(.secondary)
            Text("A SwiftUI Siri replacement — proof of concept.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
