# PDF to JPG
### by Camilo Hernandez

A simple, modern PDF to JPG converter available for both **macOS** and **Windows**.

---

## 📥 Download

| Platform | Download |
|----------|----------|
| **Windows** | [Download from Releases](../../releases) |
| **macOS** | Build from source (see below) |

---

## ✨ Features

- **Modern UI** - Clean, professional interface
- **Dark Mode** - Follows system theme
- **Drag & Drop** - Drop PDF files directly
- **Batch Processing** - Convert multiple PDFs at once
- **Smart Naming** - Auto-names output folders
- **High Quality** - 200 DPI, 80% JPEG quality
- **Portable** - Single executable, no installation

---

## 📁 Project Structure

```
PDF-to-JPG-App/
├── macos/                  # macOS version (Swift/SwiftUI)
│   ├── Sources/
│   ├── Package.swift
│   └── PDF to JPG.app
├── windows/                # Windows version (Python/PySide6)
│   ├── main.py
│   └── requirements.txt
└── .github/workflows/      # Auto-build Windows .exe
```

---

## 🔨 Building

### Windows
The Windows executable is **automatically built** by GitHub Actions.
Just download from the [Releases page](../../releases).

To build manually:
```bash
cd windows
pip install -r requirements.txt
pyinstaller --onefile --windowed --name "PDF to JPG" main.py
```

### macOS
```bash
cd macos
swift build -c release
```

---

## 📄 License

MIT License - Free for personal and commercial use.

---

**Made with ❤️ by Camilo Hernandez**
