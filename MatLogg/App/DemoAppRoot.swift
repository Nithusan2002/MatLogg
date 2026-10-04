import SwiftUI

@main
struct MatLoggApp: App {
    var body: some Scene { WindowGroup { DemoAppRoot() } }
}

struct DemoAppRoot: View {
    @StateObject private var mode: DemoMode
    init() {
        let directory = URL.applicationSupportDirectory.appendingPathComponent("MatLoggDemo", isDirectory: true)
        let defaults = UserDefaults(suiteName: "app.matlogg.demo")
        _mode = StateObject(wrappedValue: DemoMode(demoDefaults: defaults, directory: directory))
    }
    var body: some View {
        let timing = PerformanceSignposts.begin("UI.AppRootBody")
        defer { PerformanceSignposts.end(timing) }
        return Group {
            if mode.isReady {
                MatLoggContent(databaseService: mode.database, defaults: mode.defaults, isDemo: mode.isDemo)
            } else {
                ProgressView("Åpner MatLogg …")
                    .tint(AppColors.action)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background.ignoresSafeArea())
            }
        }
            .id(mode.revision) // Explicitly resets all feature state when the storage context changes.
            .environmentObject(mode)
            .disabled(mode.isLoading)
            .task {
                let timing = PerformanceSignposts.begin("Startup.RestoreContext")
                defer { PerformanceSignposts.end(timing) }
                await mode.restore()
            }
            .onChange(of: mode.isReady) { _, _ in
                PerformanceSignposts.event("Startup.ContextReadyChanged")
            }
            .alert("Demomodus", isPresented: Binding(get: { mode.errorMessage != nil }, set: { if !$0 { mode.errorMessage = nil } })) {
                Button("OK") { mode.errorMessage = nil }
            } message: { Text(mode.errorMessage ?? "") }
    }
}
