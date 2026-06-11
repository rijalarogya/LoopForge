import SwiftUI

@main
struct LoopForgeApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .frame(minWidth: 860, minHeight: 720)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Clear Project") {
                    viewModel.clear()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
    }
}
