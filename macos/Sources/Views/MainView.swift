import SwiftUI

/// Main container view managing the app workflow
struct MainView: View {
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.colorScheme) var colorScheme
    
    enum ViewState {
        case setup
        case progress
        case summary
    }
    
    var currentState: ViewState {
        if jobManager.showingSummary {
            return .summary
        } else if jobManager.job.isRunning {
            return .progress
        } else {
            return .setup
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Theme.background(colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom title bar
                TitleBar()
                
                // Main content
                switch currentState {
                case .setup:
                    SetupView()
                        .transition(.opacity)
                case .progress:
                    ProgressContentView()
                        .transition(.opacity)
                case .summary:
                    SummaryView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentState)
    }
}

/// Custom title bar
struct TitleBar: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .font(.title2)
                .foregroundStyle(Theme.brandBlue)
            
            Text("PDF to JPG")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary(colorScheme))
            
            Text("by Camilo Hernandez")
                .font(.headline)
                .foregroundColor(Theme.textSecondary(colorScheme))
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(Theme.cardBackground(colorScheme))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Theme.border(colorScheme)),
            alignment: .bottom
        )
    }
}

#Preview {
    MainView()
        .environmentObject(JobManager())
        .frame(width: 700, height: 500)
}
