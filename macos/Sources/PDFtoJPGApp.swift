import SwiftUI

@main
struct PDFtoJPGApp: App {
    @StateObject private var jobManager = JobManager()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(jobManager)
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
