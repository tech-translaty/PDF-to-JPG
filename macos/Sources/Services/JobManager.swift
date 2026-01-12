import Foundation
import PDFKit
import Combine

/// Manages the conversion job lifecycle: queuing PDFs, running conversions, tracking progress
@MainActor
class JobManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var job = Job()
    @Published var currentPDFIndex: Int = 0
    @Published var currentPageNumber: Int = 0
    @Published var errorMessage: String?
    @Published var showingSummary: Bool = false
    
    // MARK: - Computed Properties
    
    var canStart: Bool {
        job.destinationURL != nil &&
        !job.folderName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !job.pdfItems.isEmpty &&
        !job.isRunning
    }
    
    var currentPDF: PDFItem? {
        guard currentPDFIndex < job.pdfItems.count else { return nil }
        return job.pdfItems[currentPDFIndex]
    }
    
    init() {
        // Load last used destination
        if let savedPath = UserDefaults.standard.string(forKey: "LastDestinationPath") {
            let url = URL(fileURLWithPath: savedPath)
            // Check if directory still exists (optional, but good UX)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                job.destinationURL = url
            }
        }
    }

    // MARK: - Job Setup
    
    func setDestination(_ url: URL) {
        job.destinationURL = url
        // Save to UserDefaults
        UserDefaults.standard.set(url.path, forKey: "LastDestinationPath")
    }
    
    func setFolderName(_ name: String) {
        job.folderName = name
    }
    
    func addPDFs(urls: [URL]) {
        for url in urls {
            // Check for duplicates by URL
            guard !job.pdfItems.contains(where: { $0.url == url }) else { continue }
            
            let item = PDFItem(url: url)
            if item.pageCount > 0 {
                job.pdfItems.append(item)
            }
        }
    }
    
    func removePDF(at index: Int) {
        guard index < job.pdfItems.count else { return }
        job.pdfItems.remove(at: index)
    }
    
    func clearPDFs() {
        job.pdfItems.removeAll()
    }
    
    // MARK: - Conversion Control
    
    func startConversion() {
        guard canStart else { return }
        
        job.isRunning = true
        job.isCancelled = false
        currentPDFIndex = 0
        currentPageNumber = 0
        errorMessage = nil
        showingSummary = false
        
        // Reset all items to pending
        for i in 0..<job.pdfItems.count {
            job.pdfItems[i].status = .pending
            job.pdfItems[i].completedPages = 0
            job.pdfItems[i].failedPages = []
        }
        
        // Small delay to ensure UI updates to ProgressView before work starts
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            await runConversion()
        }
    }
    
    func cancelConversion() {
        job.isCancelled = true
    }
    
    func reset() {
        // Keep the destination, reset other fields
        let currentDestination = job.destinationURL
        job = Job()
        job.destinationURL = currentDestination
        
        currentPDFIndex = 0
        currentPageNumber = 0
        errorMessage = nil
        showingSummary = false
    }
    
    // MARK: - Private Conversion Logic
    
    private func runConversion() async {
        // Create job folder
        guard let jobFolderURL = job.jobFolderURL else {
            errorMessage = "Invalid job folder path"
            job.isRunning = false
            return
        }
        
        do {
            try FileSystemService.createDirectory(at: jobFolderURL)
        } catch {
            errorMessage = "Failed to create job folder: \(error.localizedDescription)"
            job.isRunning = false
            return
        }
        
        // Track existing subfolder names for collision handling
        var existingNames = FileSystemService.existingFolderNames(in: jobFolderURL)
        
        // Process each PDF
        for i in 0..<job.pdfItems.count {
            guard !job.isCancelled else {
                job.pdfItems[i].status = .cancelled
                continue
            }
            
            currentPDFIndex = i
            job.pdfItems[i].status = .inProgress
            
            // Check for password protection
            if job.pdfItems[i].isPasswordProtected {
                job.pdfItems[i].status = .skipped("Password protected")
                continue
            }
            
            // Resolve subfolder name collision
            let baseName = job.pdfItems[i].sanitizedName
            let subfolderName = FileSystemService.resolveCollision(baseName, existingNames: existingNames)
            existingNames.insert(subfolderName)
            
            let subfolderURL = jobFolderURL.appendingPathComponent(subfolderName)
            
            do {
                try FileSystemService.createDirectory(at: subfolderURL)
            } catch {
                job.pdfItems[i].status = .failed("Could not create subfolder")
                continue
            }
            
            // Load PDF document
            guard let document = PDFDocument(url: job.pdfItems[i].url) else {
                job.pdfItems[i].status = .failed("Could not load PDF")
                continue
            }
            
            let pageCount = document.pageCount
            
            // Convert each page
            for pageIndex in 0..<pageCount {
                guard !job.isCancelled else {
                    job.pdfItems[i].status = .cancelled
                    break
                }
                
                currentPageNumber = pageIndex + 1
                
                // Offload heavy rendering to background thread to keep UI responsive
                let success = await Task.detached(priority: .userInitiated) {
                    return autoreleasepool {
                        guard let page = document.page(at: pageIndex) else { return false }
                        
                        let filename = FileSystemService.pageFilename(
                            pageNumber: pageIndex + 1,
                            totalPages: pageCount,
                            pdfName: subfolderName
                        )
                        let outputURL = subfolderURL.appendingPathComponent(filename)
                        
                        do {
                            try ConversionService.convertPage(page, to: outputURL)
                            return true
                        } catch {
                            return false
                        }
                    }
                }.value
                
                if success {
                    job.pdfItems[i].completedPages += 1
                } else {
                    job.pdfItems[i].failedPages.append(pageIndex + 1)
                }
            }
            
            // Set final status for this PDF
            if job.pdfItems[i].status != .cancelled {
                if job.pdfItems[i].failedPages.isEmpty {
                    job.pdfItems[i].status = .completed
                } else if job.pdfItems[i].completedPages == 0 {
                    job.pdfItems[i].status = .failed("All pages failed")
                } else {
                    job.pdfItems[i].status = .completed // Partial success still counts as completed
                }
            }
        }
        
        job.isRunning = false
        showingSummary = true
    }
    
    // MARK: - Summary Helpers
    
    var summaryStats: (completed: Int, failed: Int, cancelled: Int, skipped: Int) {
        var completed = 0
        var failed = 0
        var cancelled = 0
        var skipped = 0
        
        for item in job.pdfItems {
            switch item.status {
            case .completed: completed += 1
            case .failed: failed += 1
            case .cancelled: cancelled += 1
            case .skipped: skipped += 1
            default: break
            }
        }
        
        return (completed, failed, cancelled, skipped)
    }
    
    func revealJobFolder() {
        guard let url = job.jobFolderURL else { return }
        FileSystemService.revealInFinder(url)
    }
}
