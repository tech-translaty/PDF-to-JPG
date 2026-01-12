import Foundation
import PDFKit
import SwiftUI

/// Central theme for the application supporting Light and Dark modes
struct Theme {
    // Brand Colors
    static let brandBlue = Color(red: 0.33, green: 0.62, blue: 0.86)
    static let brandBlueLight = Color(red: 0.33, green: 0.62, blue: 0.86).opacity(0.1)
    
    // Backgrounds
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.12) : Color(red: 248/255, green: 250/255, blue: 252/255)
    }
    
    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.16, green: 0.18, blue: 0.20) : Color.white
    }
    
    static func inputBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.14) : Color(red: 0.97, green: 0.98, blue: 0.99)
    }
    
    // Text
    static func textPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.06, green: 0.09, blue: 0.16) // Dark Slate
    }
    
    static func textSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.70, green: 0.70, blue: 0.75) : Color(red: 0.40, green: 0.45, blue: 0.53) // Medium Slate
    }
    
    // Borders
    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.1) : Color(red: 0.89, green: 0.91, blue: 0.94)
    }
    
    // Shadows
    static func shadowColor(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : .black.opacity(0.05)
    }
}

/// Represents a PDF file queued for conversion
struct PDFItem: Identifiable {
    let id = UUID()
    let url: URL
    let originalFilename: String
    let sanitizedName: String
    let pageCount: Int
    var status: ConversionStatus = .pending
    var completedPages: Int = 0
    var failedPages: [Int] = []
    
    init(url: URL) {
        self.url = url
        self.originalFilename = url.deletingPathExtension().lastPathComponent
        self.sanitizedName = FileSystemService.sanitize(originalFilename)
        
        if let document = PDFDocument(url: url) {
            self.pageCount = document.pageCount
        } else {
            self.pageCount = 0
        }
    }
    
    var isPasswordProtected: Bool {
        guard let document = PDFDocument(url: url) else { return false }
        return document.isLocked
    }
}

/// Status of a conversion task
enum ConversionStatus: Equatable {
    case pending
    case inProgress
    case completed
    case failed(String)
    case cancelled
    case skipped(String)
    
    var displayText: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "Converting..."
        case .completed: return "Completed"
        case .failed(let reason): return "Failed: \(reason)"
        case .cancelled: return "Cancelled"
        case .skipped(let reason): return "Skipped: \(reason)"
        }
    }
    
    var isFinished: Bool {
        switch self {
        case .completed, .failed, .cancelled, .skipped: return true
        default: return false
        }
    }
}

/// Represents the entire conversion job
struct Job {
    var destinationURL: URL?
    var folderName: String = ""
    var pdfItems: [PDFItem] = []
    var isRunning: Bool = false
    var isCancelled: Bool = false
    
    var sanitizedFolderName: String {
        FileSystemService.sanitize(folderName)
    }
    
    var jobFolderURL: URL? {
        guard let destination = destinationURL else { return nil }
        return destination.appendingPathComponent(sanitizedFolderName)
    }
    
    var totalPages: Int {
        pdfItems.reduce(0) { $0 + $1.pageCount }
    }
    
    var completedPages: Int {
        pdfItems.reduce(0) { $0 + $1.completedPages }
    }
    
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(completedPages) / Double(totalPages)
    }
    
    var isComplete: Bool {
        pdfItems.allSatisfy { $0.status.isFinished }
    }
}

/// Errors that can occur during conversion
enum ConversionError: LocalizedError {
    case documentLoadFailed
    case pageRenderFailed(Int)
    case destinationCreationFailed
    case exportFailed
    case folderCreationFailed(String)
    case passwordProtected
    
    var errorDescription: String? {
        switch self {
        case .documentLoadFailed: return "Failed to load PDF document"
        case .pageRenderFailed(let page): return "Failed to render page \(page)"
        case .destinationCreationFailed: return "Failed to create output destination"
        case .exportFailed: return "Failed to export JPG"
        case .folderCreationFailed(let path): return "Failed to create folder: \(path)"
        case .passwordProtected: return "PDF is password protected"
        }
    }
}
