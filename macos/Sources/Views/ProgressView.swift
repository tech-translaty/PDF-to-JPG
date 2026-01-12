import SwiftUI

/// Progress view showing conversion status
struct ProgressContentView: View {
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 32) {
            // Animated icon
            ProgressIcon()
                .padding(.top, 40)
            
            // Overall progress
            VStack(spacing: 12) {
                Text("Converting PDFs to JPG")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary(colorScheme))
                
                // Progress bar
                ProgressBar(progress: jobManager.job.progress)
                    .frame(height: 8)
                    .padding(.horizontal, 60)
                
                // Progress text
                Text("\(jobManager.job.completedPages) of \(jobManager.job.totalPages) pages")
                    .font(.headline)
                    .foregroundColor(Theme.textSecondary(colorScheme))
            }
            
            // Current PDF info
            if let currentPDF = jobManager.currentPDF {
                CurrentFileInfo(
                    filename: currentPDF.originalFilename,
                    currentPage: jobManager.currentPageNumber,
                    totalPages: currentPDF.pageCount
                )
            }
            
            // PDF progress list
            PDFProgressList()
                .padding(.horizontal, 40)
            
            // Cancel button
            Button {
                jobManager.cancelConversion()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Cancel")
                }
                .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.bottom, 24)
        }
    }
}

/// Animated progress icon
struct ProgressIcon: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.brandBlue.opacity(0.1),
                            Theme.brandBlue.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
            
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Theme.brandBlue,
                            Theme.brandBlue.opacity(0.5),
                            Theme.brandBlue
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
            
            Image(systemName: "doc.text.image")
                .font(.system(size: 36))
                .foregroundStyle(Theme.brandBlue)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

/// Custom progress bar
struct ProgressBar: View {
    let progress: Double
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.border(colorScheme))
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.brandBlue)
                    .frame(width: geometry.size.width * CGFloat(progress))
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
    }
}

/// Current file being processed
struct CurrentFileInfo: View {
    let filename: String
    let currentPage: Int
    let totalPages: Int
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Processing:")
                .font(.caption)
                .foregroundColor(Theme.textSecondary(colorScheme))
            
            Text(filename)
                .font(.headline)
                .foregroundColor(Theme.textPrimary(colorScheme))
                .lineLimit(1)
            
            Text("Page \(currentPage) of \(totalPages)")
                .font(.caption)
                .foregroundColor(Theme.brandBlue)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.cardBackground(colorScheme))
                .shadow(color: Theme.shadowColor(colorScheme), radius: 8, x: 0, y: 4)
        )
    }
}

/// List of PDFs with individual progress
struct PDFProgressList: View {
    @EnvironmentObject var jobManager: JobManager
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 8) {
                ForEach(jobManager.job.pdfItems) { item in
                    PDFProgressPill(item: item)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// Individual PDF progress pill
struct PDFProgressPill: View {
    let item: PDFItem
    
    var statusColor: Color {
        switch item.status {
        case .pending: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        case .skipped: return .yellow
        }
    }
    
    var statusIcon: String {
        switch item.status {
        case .pending: return "clock"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        case .skipped: return "exclamationmark.triangle.fill"
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.sanitizedName)
                    .font(.caption)
                    .foregroundColor(Theme.textPrimary(colorScheme))
                    .lineLimit(1)
                
                Text("\(item.completedPages)/\(item.pageCount)")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary(colorScheme))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12) // Slightly less rounded for list items
                .fill(Theme.cardBackground(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Theme.shadowColor(colorScheme), radius: 4, x: 0, y: 2)
        )
    }
}

#Preview {
    ProgressContentView()
        .environmentObject({
            let manager = JobManager()
            manager.job.pdfItems = [
                PDFItem(url: URL(fileURLWithPath: "/test.pdf"))
            ]
            return manager
        }())
        .frame(width: 700, height: 500)
        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
}
