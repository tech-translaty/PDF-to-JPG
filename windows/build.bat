@echo off
REM PDF to JPG - Windows Build Script
REM This script creates a single executable file

echo ========================================
echo PDF to JPG - Windows Build Script
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.10+ from https://python.org
    pause
    exit /b 1
)

REM Create virtual environment if it doesn't exist
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt

REM Build executable
echo.
echo Building executable...
pyinstaller --onefile --windowed --name "PDF to JPG" --icon=icon.ico main.py

echo.
echo ========================================
echo Build complete!
echo Executable: dist\PDF to JPG.exe
echo ========================================
pause
