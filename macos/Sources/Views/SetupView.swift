import SwiftUI
import UniformTypeIdentifiers

/// Setup view for configuring job: destination, folder name, PDF selection
struct SetupView: View {
    @EnvironmentObject var jobManager: JobManager
    @State private var folderName: String = ""
    @State private var isTargeted: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Destination Section
                SettingsCard(title: "Output Location", icon: "folder.badge.plus") {
                    DestinationPicker()
                }
                
                // Job Name Section
                SettingsCard(title: "Job Folder Name", icon: "character.cursor.ibeam") {
                    JobNameInput(folderName: $folderName)
                }
                
                // PDF Selection Section
                SettingsCard(title: "Select PDFs", icon: "doc.on.doc") {
                    PDFDropZone(isTargeted: $isTargeted)
                }
                
                // PDF Queue
                if !jobManager.job.pdfItems.isEmpty {
                    SettingsCard(title: "Queued PDFs (\(jobManager.job.pdfItems.count))", icon: "list.bullet.rectangle") {
                        PDFQueueList()
                    }
                }
                
                // Start Button
                StartButton()
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .onChange(of: folderName) { newValue in
            jobManager.setFolderName(newValue)
        }
    }
}

/// Reusable card container for settings sections
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(Theme.textPrimary(colorScheme))
            
            content
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground(colorScheme))
        .cornerRadius(16)
        .shadow(color: Theme.shadowColor(colorScheme), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border(colorScheme), lineWidth: 1)
        )
    }
}

/// Destination folder picker
struct DestinationPicker: View {
    @EnvironmentObject var jobManager: JobManager
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            if let destination = jobManager.job.destinationURL {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(Theme.brandBlue)
                    Text(destination.path)
                        .foregroundColor(Theme.textSecondary(colorScheme))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No destination selected")
                    .foregroundColor(Theme.textSecondary(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Button("Choose...") {
                chooseDestination()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brandBlue)
        }
    }
    
    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where to create the job folder"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            jobManager.setDestination(url)
        }
    }
}

/// Job folder name input
struct JobNameInput: View {
    @Binding var folderName: String
    @EnvironmentObject var jobManager: JobManager
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Enter job folder name...", text: $folderName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.inputBackground(colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.border(colorScheme), lineWidth: 1)
                        )
                )
                .foregroundColor(Theme.textPrimary(colorScheme))
            
            if !folderName.isEmpty {
                let sanitized = jobManager.job.sanitizedFolderName
                if sanitized != folderName {
                    Text("Will be saved as: \(sanitized)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

/// Drag & drop zone for PDFs
struct PDFDropZone: View {
    @EnvironmentObject var jobManager: JobManager
    @Binding var isTargeted: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    isTargeted 
                    ? Theme.brandBlue
                    : Color(red: 0.60, green: 0.65, blue: 0.73)
                )
            
            Text("Drop PDF files here")
                .font(.headline)
                .foregroundColor(Theme.textPrimary(colorScheme))
            
            Text("or")
                .font(.caption)
                .foregroundColor(Theme.textSecondary(colorScheme))
            
            Button("Browse Files") {
                browseFiles()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brandBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isTargeted ? Theme.brandBlue : Theme.border(colorScheme),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Theme.brandBlueLight : Theme.inputBackground(colorScheme))
                )
        )
        .onDrop(of: [.pdf], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func browseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf]
        panel.message = "Select PDF files to convert"
        panel.prompt = "Add PDFs"
        
        if panel.runModal() == .OK {
            jobManager.addPDFs(urls: panel.urls)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, error in
                guard error == nil else { return }
                
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        jobManager.addPDFs(urls: [url])
                    }
                } else if let url = item as? URL {
                    DispatchQueue.main.async {
                        jobManager.addPDFs(urls: [url])
                    }
                }
            }
        }
    }
}

/// List of queued PDFs
struct PDFQueueList: View {
    @EnvironmentObject var jobManager: JobManager
    @State private var showAllFiles: Bool = false
    
    private let maxVisibleItems = 5
    
    var visibleItems: [(offset: Int, element: PDFItem)] {
        let enumerated = Array(jobManager.job.pdfItems.enumerated())
        if showAllFiles || enumerated.count <= maxVisibleItems {
            return enumerated
        }
        return Array(enumerated.prefix(maxVisibleItems))
    }
    
    var hiddenCount: Int {
        max(0, jobManager.job.pdfItems.count - maxVisibleItems)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(visibleItems, id: \.element.id) { index, item in
                PDFQueueRow(item: item, index: index)
            }
            
            // Show more files button
            if hiddenCount > 0 && !showAllFiles {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAllFiles = true
                    }
                } label: {
                    HStack {
                        Text("Show \(hiddenCount) more file\(hiddenCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.05))
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Collapse button when expanded
            if showAllFiles && hiddenCount > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAllFiles = false
                    }
                } label: {
                    HStack {
                        Text("Show less")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.up")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            
            if jobManager.job.pdfItems.count > 1 {
                HStack {
                    Text("\(jobManager.job.totalPages) total pages")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        jobManager.clearPDFs()
                        showAllFiles = false
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                .padding(.top, 8)
            }
        }
    }
}

/// Single PDF row in queue
struct PDFQueueRow: View {
    let item: PDFItem
    let index: Int
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isPasswordProtected ? "lock.doc.fill" : "doc.fill")
                .foregroundColor(item.isPasswordProtected ? .orange : Color(red: 0.91, green: 0.30, blue: 0.24))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.originalFilename)
                    .foregroundColor(Theme.textPrimary(colorScheme))
                    .lineLimit(1)
                
                Text("\(item.pageCount) pages")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary(colorScheme))
            }
            
            Spacer()
            
            if item.isPasswordProtected {
                Text("Password protected")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Button {
                jobManager.removePDF(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color(red: 0.60, green: 0.65, blue: 0.73))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.inputBackground(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.border(colorScheme), lineWidth: 1)
                )
        )
    }
}

/// Start conversion button
struct StartButton: View {
    @EnvironmentObject var jobManager: JobManager
    
    var body: some View {
        Button {
            jobManager.startConversion()
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Conversion")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.brandBlue)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Theme.brandBlue.opacity(0.3), radius: 8, x: 0, y: 4)
        .disabled(!jobManager.canStart)
        .opacity(jobManager.canStart ? 1 : 0.5)
    }
}

#Preview {
    SetupView()
        .environmentObject(JobManager())
        .frame(width: 700, height: 600)
        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
}
