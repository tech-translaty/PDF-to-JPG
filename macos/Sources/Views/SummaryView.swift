import SwiftUI

/// Summary view showing conversion results
struct SummaryView: View {
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.colorScheme) var colorScheme
    
    var stats: (completed: Int, failed: Int, cancelled: Int, skipped: Int) {
        jobManager.summaryStats
    }
    
    var overallSuccess: Bool {
        stats.failed == 0 && stats.cancelled == 0
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success/Warning icon
            SummaryIcon(success: overallSuccess)
            
            // Title
            Text(overallSuccess ? "Conversion Complete!" : "Conversion Finished")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary(colorScheme))
            
            // Stats cards
            HStack(spacing: 16) {
                StatCard(
                    title: "Completed",
                    value: "\(stats.completed)",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                if stats.failed > 0 {
                    StatCard(
                        title: "Failed",
                        value: "\(stats.failed)",
                        color: .red,
                        icon: "xmark.circle.fill"
                    )
                }
                
                if stats.cancelled > 0 {
                    StatCard(
                        title: "Cancelled",
                        value: "\(stats.cancelled)",
                        color: .orange,
                        icon: "stop.circle.fill"
                    )
                }
                
                if stats.skipped > 0 {
                    StatCard(
                        title: "Skipped",
                        value: "\(stats.skipped)",
                        color: .yellow,
                        icon: "exclamationmark.triangle.fill"
                    )
                }
            }
            .padding(.horizontal, 40)
            
            // Total pages converted
            Text("\(jobManager.job.completedPages) pages converted")
                .font(.headline)
                .foregroundColor(Theme.textSecondary(colorScheme))
            
            // Detailed results
            DetailedResultsList()
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                Button {
                    jobManager.revealJobFolder()
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("Open in Finder")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Theme.brandBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Button {
                    jobManager.reset()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("New Job")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.textSecondary(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
    }
}

/// Summary icon with animation
struct SummaryIcon: View {
    let success: Bool
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    success
                        ? LinearGradient(colors: [.green.opacity(0.3), .mint.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [.orange.opacity(0.3), .yellow.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 100, height: 100)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
            
            Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    success
                        ? Theme.brandBlue
                        : Color.orange
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

/// Statistics card
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary(colorScheme))
            
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.cardBackground(colorScheme))
                .shadow(color: Theme.shadowColor(colorScheme), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

/// Detailed list of conversion results
struct DetailedResultsList: View {
    @EnvironmentObject var jobManager: JobManager
    @State private var isExpanded = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Details")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary(colorScheme))
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(Theme.textSecondary(colorScheme))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.cardBackground(colorScheme))
                        .shadow(color: Theme.shadowColor(colorScheme), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(jobManager.job.pdfItems) { item in
                            ResultRow(item: item)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
    }
}

/// Individual result row
struct ResultRow: View {
    let item: PDFItem
    @Environment(\.colorScheme) var colorScheme
    
    var statusColor: Color {
        switch item.status {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        case .skipped: return .yellow
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(item.originalFilename)
                .font(.caption)
                .foregroundColor(Theme.textPrimary(colorScheme))
                .lineLimit(1)
            
            Spacer()
            
            Text("\(item.completedPages)/\(item.pageCount) pages")
                .font(.caption)
                .foregroundColor(Theme.textSecondary(colorScheme))
            
            if !item.failedPages.isEmpty {
                Text("(\(item.failedPages.count) failed)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.cardBackground(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Theme.border(colorScheme), lineWidth: 1)
                )
        )
    }
}

#Preview {
    SummaryView()
        .environmentObject({
            let manager = JobManager()
            manager.showingSummary = true
            return manager
        }())
        .frame(width: 700, height: 500)
        .frame(width: 700, height: 500)
        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
}
