import Foundation
import AppKit

/// Service responsible for file system operations: folder creation, name sanitization, collision handling
struct FileSystemService {
    
    /// Characters illegal in macOS/Windows filenames
    private static let illegalCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
    
    /// Sanitizes a filename by removing illegal characters and trimming
    /// - Parameter filename: Original filename
    /// - Returns: Sanitized filename safe for filesystem use
    static func sanitize(_ filename: String) -> String {
        var result = filename
        
        // Replace illegal characters with underscore
        result = result.unicodeScalars
            .map { illegalCharacters.contains($0) ? "_" : String($0) }
            .joined()
        
        // Remove control characters
        result = result.filter { !$0.isNewline && $0 != "\0" }
        
        // Trim leading/trailing whitespace and dots
        result = result.trimmingCharacters(in: .whitespaces)
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        
        // Limit length to 200 characters
        if result.count > 200 {
            result = String(result.prefix(200))
        }
        
        // Handle empty result
        if result.isEmpty {
            result = "Untitled"
        }
        
        // Apply Unicode NFC normalization
        result = result.precomposedStringWithCanonicalMapping
        
        return result
    }
    
    /// Resolves naming collisions by appending (2), (3), etc.
    /// - Parameters:
    ///   - baseName: The desired folder/file name
    ///   - existingNames: Set of names already in use
    /// - Returns: Unique name that doesn't collide
    static func resolveCollision(_ baseName: String, existingNames: Set<String>) -> String {
        if !existingNames.contains(baseName) {
            return baseName
        }
        
        var counter = 2
        while existingNames.contains("\(baseName) (\(counter))") {
            counter += 1
        }
        return "\(baseName) (\(counter))"
    }
    
    /// Creates a directory at the specified URL
    /// - Parameter url: Directory URL to create
    /// - Throws: ConversionError.folderCreationFailed if creation fails
    static func createDirectory(at url: URL) throws {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw ConversionError.folderCreationFailed(url.path)
        }
    }
    
    /// Generates the page filename with zero-padded page number
    /// - Parameters:
    ///   - pageNumber: 1-based page number
    ///   - totalPages: Total pages in document (for padding calculation)
    ///   - pdfName: Sanitized PDF name
    /// - Returns: Formatted filename like "001 - MyDocument.jpg"
    static func pageFilename(pageNumber: Int, totalPages: Int, pdfName: String) -> String {
        let paddingWidth = totalPages >= 1000 ? 4 : 3
        let paddedNumber = String(format: "%0\(paddingWidth)d", pageNumber)
        return "\(paddedNumber) - \(pdfName).jpg"
    }
    
    /// Gets existing subfolder names in a directory
    /// - Parameter url: Parent directory URL
    /// - Returns: Set of existing folder names
    static func existingFolderNames(in url: URL) -> Set<String> {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        
        return Set(contents.compactMap { url -> String? in
            guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isDirectory == true else {
                return nil
            }
            return url.lastPathComponent
        })
    }
    
    /// Opens the specified URL in Finder
    /// - Parameter url: URL to reveal
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
}
