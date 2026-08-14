import SwiftUI

@main
struct AeolusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Aeolus", systemImage: "wind") {
            Button("Quit Aeolus") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppServices.shared.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Без этого perl-процесс адаптера пережил бы выход из приложения (спека §5.5).
        // Таймаут 2 с — выход не должен зависеть от занятости актора движка.
        Task { @MainActor in
            let engine = AppServices.shared.engine
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await engine?.stop() }
                group.addTask { try? await Task.sleep(for: .seconds(2)) }
                await group.next()
                group.cancelAll()
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
