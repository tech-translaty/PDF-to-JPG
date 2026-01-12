# PDF to JPG by Camilo Hernandez

A native macOS desktop app that converts PDF pages to JPG images with organized folder structure.

## Features

- 🎯 **Batch Processing**: Convert multiple PDFs in one run
- 📁 **Organized Output**: Creates job folder with per-PDF subfolders  
- 📄 **Page Naming**: Zero-padded page numbers (001, 002, etc.)
- 🔒 **Password Detection**: Identifies and skips protected PDFs
- 📊 **Progress Tracking**: Real-time progress with cancel support
- 🎨 **Modern UI**: Beautiful dark theme with gradient accents

## System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Installation

### Option 1: Pre-built App
1. Download `PDF to JPG.app` from Releases
2. Drag to Applications folder
3. Double-click to launch

### Option 2: Build from Source
```bash
# Clone or download the project
cd "PDF to JPG by Camilo Hernandez"

# Build release version
swift build -c release

# Create app bundle
mkdir -p "PDF to JPG.app/Contents/MacOS"
cp .build/release/PDFtoJPG "PDF to JPG.app/Contents/MacOS/"
cp Info.plist "PDF to JPG.app/Contents/"

# Launch
open "PDF to JPG.app"
```

## Usage

1. **Choose Output Location** - Select where to create the job folder
2. **Enter Job Name** - Name for the main folder (e.g., "Client_A_2026_01")
3. **Add PDFs** - Drag & drop or browse for PDF files
4. **Start Conversion** - Click "Start Conversion"
5. **Done!** - Open in Finder or start a new job

## Output Structure

```
Your_Job_Name/
├── Document1/
│   ├── 001 - Document1.jpg
│   ├── 002 - Document1.jpg
│   └── ...
├── Document2/
│   ├── 001 - Document2.jpg
│   └── ...
```

## Settings

| Setting | Value |
|---------|-------|
| Output DPI | 300 (print quality) |
| JPG Quality | 92% |
| Page Numbering | Zero-padded (001, 002...) |

## License

MIT License - © 2026 Camilo Hernandez
