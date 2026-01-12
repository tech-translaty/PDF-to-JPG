# PDF to JPG - Windows Version

A simple, modern PDF to JPG converter for Windows 11.

## Features

- **Modern UI**: Clean interface matching the macOS version
- **Dark Mode Support**: Automatically adapts to Windows theme
- **Drag & Drop**: Drop PDF files directly onto the app
- **Batch Processing**: Convert multiple PDFs at once
- **Persistence**: Remembers your last output folder
- **High Quality**: 200 DPI with 80% JPEG quality (optimal balance)

## Requirements

- Windows 10/11
- Python 3.10+ (for building from source)

## Building the Executable

1. **Install Python** from [python.org](https://python.org) (check "Add to PATH")

2. **Run the build script**:
   ```
   build.bat
   ```

3. **Find your executable** in the `dist` folder:
   ```
   dist\PDF to JPG.exe
   ```

## Running from Source (Development)

```bash
# Create virtual environment
python -m venv venv

# Activate it
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the app
python main.py
```

## Project Structure

```
PDF to JPG by Camilo Hernandez - Windows/
├── main.py              # Main application code
├── requirements.txt     # Python dependencies
├── build.bat           # Build script for Windows
├── icon.ico            # Application icon (add your own)
└── README.md           # This file
```

## Technical Details

- **UI Framework**: PySide6 (Qt6)
- **PDF Processing**: PyMuPDF (fitz)
- **Image Processing**: Pillow
- **Packaging**: PyInstaller

## Author

Camilo Hernandez
