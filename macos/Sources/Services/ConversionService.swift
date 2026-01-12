import Foundation
import PDFKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

/// Service responsible for converting PDF pages to JPG images
struct ConversionService {
    
    /// Default DPI for rendering (200 DPI - balanced for screen & print)
    static let defaultDPI: CGFloat = 200
    
    /// Default JPG compression quality (75% - matches Windows output size)
    static let defaultQuality: CGFloat = 0.75
    
    /// Renders a PDF page to a CGImage
    /// - Parameters:
    ///   - page: PDFPage to render
    ///   - dpi: Output DPI (default 300)
    /// - Returns: Rendered CGImage or nil if rendering fails
    static func renderPage(_ page: PDFPage, dpi: CGFloat = defaultDPI) -> CGImage? {
        let mediaBox = page.bounds(for: .mediaBox)
        let scale = dpi / 72.0  // PDF native is 72 DPI
        
        // Account for page rotation
        let rotation = page.rotation
        let isRotated = rotation == 90 || rotation == 270
        
        let width: Int
        let height: Int
        
        if isRotated {
            width = Int(mediaBox.height * scale)
            height = Int(mediaBox.width * scale)
        } else {
            width = Int(mediaBox.width * scale)
            height = Int(mediaBox.height * scale)
        }
        
        guard width > 0, height > 0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }
        
        // Fill with white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Apply transformations
        context.scaleBy(x: scale, y: scale)
        
        // PDFKit handles rotation internally with draw()
        page.draw(with: .mediaBox, to: context)
        
        return context.makeImage()
    }
    
    /// Exports a CGImage to JPG at the specified URL
    /// - Parameters:
    ///   - image: Image to export
    ///   - url: Destination file URL
    ///   - quality: JPG compression quality (0.0 to 1.0)
    /// - Throws: ConversionError if export fails
    static func exportJPG(_ image: CGImage, to url: URL, quality: CGFloat = defaultQuality) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.destinationCreationFailed
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.exportFailed
        }
    }
    
    /// Converts a single PDF page and saves it as JPG
    /// - Parameters:
    ///   - page: PDFPage to convert
    ///   - outputURL: Destination file URL
    ///   - dpi: Output DPI
    ///   - quality: JPG quality
    /// - Throws: ConversionError if conversion fails
    static func convertPage(_ page: PDFPage, to outputURL: URL, dpi: CGFloat = defaultDPI, quality: CGFloat = defaultQuality) throws {
        guard let image = renderPage(page, dpi: dpi) else {
            throw ConversionError.pageRenderFailed(0)
        }
        
        try exportJPG(image, to: outputURL, quality: quality)
    }
}
