"""
PDF to JPG - Windows Version
by Camilo Hernandez

A simple, modern PDF to JPG converter with the same functionality
as the macOS version.

Tech Stack:
- PySide6 (Qt6) for UI
- PyMuPDF (fitz) for PDF rendering
- Pillow for image processing
"""

import sys
import os
import re
import json
from pathlib import Path
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional, List
from concurrent.futures import ThreadPoolExecutor
import threading

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QLineEdit, QScrollArea, QFrame, QFileDialog,
    QProgressBar, QSizePolicy, QSpacerItem
)
from PySide6.QtCore import Qt, Signal, QObject, QThread, QMimeData
from PySide6.QtGui import QFont, QColor, QPalette, QDragEnterEvent, QDropEvent, QIcon

import fitz  # PyMuPDF
from PIL import Image
import io

# ============================================================================
# SETTINGS
# ============================================================================

SETTINGS_FILE = Path.home() / ".pdf_to_jpg_settings.json"
DEFAULT_DPI = 200
DEFAULT_QUALITY = 80  # 80%


def load_settings() -> dict:
    """Load settings from JSON file."""
    if SETTINGS_FILE.exists():
        try:
            with open(SETTINGS_FILE, "r") as f:
                return json.load(f)
        except:
            pass
    return {}


def save_settings(settings: dict):
    """Save settings to JSON file."""
    try:
        with open(SETTINGS_FILE, "w") as f:
            json.dump(settings, f)
    except:
        pass


# ============================================================================
# THEME
# ============================================================================

class Theme:
    """Central theme for Light/Dark mode support."""
    
    @staticmethod
    def is_dark_mode() -> bool:
        """Detect if system is in dark mode."""
        palette = QApplication.palette()
        return palette.color(QPalette.ColorRole.Window).lightness() < 128
    
    @staticmethod
    def brand_blue() -> str:
        return "#539DDB"
    
    @staticmethod
    def background() -> str:
        return "#1A1A1E" if Theme.is_dark_mode() else "#F8FAFC"
    
    @staticmethod
    def card_background() -> str:
        return "#2A2A30" if Theme.is_dark_mode() else "#FFFFFF"
    
    @staticmethod
    def input_background() -> str:
        return "#1E1E22" if Theme.is_dark_mode() else "#F7F8F9"
    
    @staticmethod
    def text_primary() -> str:
        return "#FFFFFF" if Theme.is_dark_mode() else "#0F172A"
    
    @staticmethod
    def text_secondary() -> str:
        return "#B3B3BD" if Theme.is_dark_mode() else "#475569"
    
    @staticmethod
    def border() -> str:
        return "rgba(255,255,255,0.1)" if Theme.is_dark_mode() else "#E3E7EB"


# ============================================================================
# MODELS
# ============================================================================

class ConversionStatus(Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"
    SKIPPED = "skipped"


@dataclass
class PDFItem:
    """Represents a PDF file in the queue."""
    path: Path
    original_filename: str
    sanitized_name: str
    page_count: int
    status: ConversionStatus = ConversionStatus.PENDING
    completed_pages: int = 0
    failed_pages: List[int] = field(default_factory=list)
    is_password_protected: bool = False
    
    @classmethod
    def from_path(cls, path: Path) -> Optional["PDFItem"]:
        """Create a PDFItem from a file path."""
        try:
            doc = fitz.open(path)
            is_encrypted = doc.is_encrypted
            page_count = len(doc) if not is_encrypted else 0
            doc.close()
            
            original = path.stem
            sanitized = cls.sanitize_name(original)
            
            return cls(
                path=path,
                original_filename=original,
                sanitized_name=sanitized,
                page_count=page_count,
                is_password_protected=is_encrypted
            )
        except:
            return None
    
    @staticmethod
    def sanitize_name(name: str) -> str:
        """Sanitize filename for folder creation."""
        # Remove/replace invalid characters
        sanitized = re.sub(r'[<>:"/\\|?*]', '-', name)
        sanitized = sanitized.strip('. ')
        return sanitized if sanitized else "untitled"


@dataclass
class Job:
    """Represents the entire conversion job."""
    destination_path: Optional[Path] = None
    folder_name: str = ""
    pdf_items: List[PDFItem] = field(default_factory=list)
    is_running: bool = False
    is_cancelled: bool = False
    
    @property
    def sanitized_folder_name(self) -> str:
        return PDFItem.sanitize_name(self.folder_name)
    
    @property
    def job_folder_path(self) -> Optional[Path]:
        if self.destination_path is None:
            return None
        return self.destination_path / self.sanitized_folder_name
    
    @property
    def total_pages(self) -> int:
        return sum(item.page_count for item in self.pdf_items)
    
    @property
    def completed_pages(self) -> int:
        return sum(item.completed_pages for item in self.pdf_items)
    
    @property
    def progress(self) -> float:
        if self.total_pages == 0:
            return 0.0
        return self.completed_pages / self.total_pages


# ============================================================================
# CONVERSION SERVICE
# ============================================================================

class ConversionService:
    """Service for converting PDF pages to JPG images."""
    
    @staticmethod
    def convert_page(doc: fitz.Document, page_num: int, output_path: Path,
                     dpi: int = DEFAULT_DPI, quality: int = DEFAULT_QUALITY) -> bool:
        """Convert a single PDF page to JPG."""
        try:
            page = doc.load_page(page_num)
            
            # Render at specified DPI
            zoom = dpi / 72.0
            mat = fitz.Matrix(zoom, zoom)
            pix = page.get_pixmap(matrix=mat, alpha=False)
            
            # Convert to PIL Image and save as JPEG
            img_data = pix.tobytes("ppm")
            img = Image.open(io.BytesIO(img_data))
            img = img.convert("RGB")
            img.save(output_path, "JPEG", quality=quality, optimize=True)
            
            return True
        except Exception as e:
            print(f"Error converting page {page_num}: {e}")
            return False


# ============================================================================
# FILE SYSTEM SERVICE
# ============================================================================

class FileSystemService:
    """Service for file system operations."""
    
    @staticmethod
    def create_directory(path: Path) -> bool:
        """Create a directory if it doesn't exist."""
        try:
            path.mkdir(parents=True, exist_ok=True)
            return True
        except:
            return False
    
    @staticmethod
    def resolve_collision(base_name: str, existing_names: set) -> str:
        """Resolve naming collision by appending a number."""
        if base_name not in existing_names:
            return base_name
        
        counter = 1
        while f"{base_name}_{counter}" in existing_names:
            counter += 1
        return f"{base_name}_{counter}"
    
    @staticmethod
    def page_filename(page_num: int, total_pages: int, pdf_name: str) -> str:
        """Generate filename for a converted page."""
        padding = len(str(total_pages))
        return f"{pdf_name}_page_{str(page_num).zfill(padding)}.jpg"
    
    @staticmethod
    def reveal_in_explorer(path: Path):
        """Open folder in Windows Explorer."""
        if path.exists():
            os.startfile(path)


# ============================================================================
# WORKER THREAD
# ============================================================================

class ConversionWorker(QObject):
    """Worker for running conversion in background thread."""
    
    progress_updated = Signal(int, int, int)  # pdf_index, page_num, completed_pages
    pdf_status_changed = Signal(int, str)  # pdf_index, status
    finished = Signal()
    error = Signal(str)
    
    def __init__(self, job: Job):
        super().__init__()
        self.job = job
        self._cancelled = False
    
    def cancel(self):
        self._cancelled = True
    
    def run(self):
        """Run the conversion job."""
        job_folder = self.job.job_folder_path
        if not job_folder:
            self.error.emit("Invalid job folder path")
            self.finished.emit()
            return
        
        # Create job folder
        if not FileSystemService.create_directory(job_folder):
            self.error.emit("Failed to create job folder")
            self.finished.emit()
            return
        
        existing_names = set()
        
        for i, item in enumerate(self.job.pdf_items):
            if self._cancelled:
                self.pdf_status_changed.emit(i, "cancelled")
                continue
            
            self.pdf_status_changed.emit(i, "in_progress")
            
            # Skip password protected
            if item.is_password_protected:
                self.pdf_status_changed.emit(i, "skipped")
                continue
            
            # Resolve subfolder name
            subfolder_name = FileSystemService.resolve_collision(
                item.sanitized_name, existing_names
            )
            existing_names.add(subfolder_name)
            
            subfolder_path = job_folder / subfolder_name
            if not FileSystemService.create_directory(subfolder_path):
                self.pdf_status_changed.emit(i, "failed")
                continue
            
            # Open PDF
            try:
                doc = fitz.open(item.path)
            except:
                self.pdf_status_changed.emit(i, "failed")
                continue
            
            page_count = len(doc)
            completed = 0
            failed_pages = []
            
            for page_num in range(page_count):
                if self._cancelled:
                    self.pdf_status_changed.emit(i, "cancelled")
                    break
                
                filename = FileSystemService.page_filename(
                    page_num + 1, page_count, subfolder_name
                )
                output_path = subfolder_path / filename
                
                if ConversionService.convert_page(doc, page_num, output_path):
                    completed += 1
                else:
                    failed_pages.append(page_num + 1)
                
                self.progress_updated.emit(i, page_num + 1, completed)
            
            doc.close()
            
            # Set final status
            if not self._cancelled:
                if len(failed_pages) == 0:
                    self.pdf_status_changed.emit(i, "completed")
                elif completed == 0:
                    self.pdf_status_changed.emit(i, "failed")
                else:
                    self.pdf_status_changed.emit(i, "completed")
        
        self.finished.emit()


# ============================================================================
# UI COMPONENTS
# ============================================================================

class SettingsCard(QFrame):
    """Reusable card container for settings sections."""
    
    def __init__(self, title: str, parent=None):
        super().__init__(parent)
        self.setObjectName("settingsCard")
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(16)
        
        # Title
        title_label = QLabel(title)
        title_label.setFont(QFont("Segoe UI", 11, QFont.Weight.Bold))
        layout.addWidget(title_label)
        
        # Content area
        self.content_layout = QVBoxLayout()
        self.content_layout.setSpacing(12)
        layout.addLayout(self.content_layout)
    
    def add_widget(self, widget: QWidget):
        self.content_layout.addWidget(widget)
    
    def add_layout(self, layout):
        self.content_layout.addLayout(layout)


class PDFDropZone(QFrame):
    """Drag & drop zone for PDF files."""
    
    files_dropped = Signal(list)
    browse_clicked = Signal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)
        self.setObjectName("dropZone")
        self.setFixedHeight(150)  # Fixed height to prevent compression
        
        layout = QVBoxLayout(self)
        layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.setSpacing(8)
        
        icon_label = QLabel("📄")
        icon_label.setFont(QFont("Segoe UI Emoji", 32))
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(icon_label)
        
        text_label = QLabel("Drop PDF files here")
        text_label.setFont(QFont("Segoe UI", 11, QFont.Weight.Bold))
        text_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(text_label)
        
        or_label = QLabel("or")
        or_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(or_label)
        
        browse_btn = QPushButton("Browse Files")
        browse_btn.setObjectName("primaryButton")
        browse_btn.clicked.connect(self.browse_clicked.emit)
        browse_btn.setFixedWidth(120)
        layout.addWidget(browse_btn, alignment=Qt.AlignmentFlag.AlignCenter)
    
    def dragEnterEvent(self, event: QDragEnterEvent):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
            self.setProperty("dragOver", True)
            self.style().unpolish(self)
            self.style().polish(self)
    
    def dragLeaveEvent(self, event):
        self.setProperty("dragOver", False)
        self.style().unpolish(self)
        self.style().polish(self)
    
    def dropEvent(self, event: QDropEvent):
        self.setProperty("dragOver", False)
        self.style().unpolish(self)
        self.style().polish(self)
        
        files = []
        for url in event.mimeData().urls():
            path = Path(url.toLocalFile())
            if path.suffix.lower() == ".pdf":
                files.append(path)
        
        if files:
            self.files_dropped.emit(files)


class PDFQueueRow(QFrame):
    """Single PDF row in queue."""
    
    remove_clicked = Signal(int)
    
    def __init__(self, item: PDFItem, index: int, parent=None):
        super().__init__(parent)
        self.index = index
        self.setObjectName("queueRow")
        
        layout = QHBoxLayout(self)
        layout.setContentsMargins(12, 12, 12, 12)
        
        # Icon
        icon = "🔒" if item.is_password_protected else "📄"
        icon_label = QLabel(icon)
        icon_label.setFont(QFont("Segoe UI Emoji", 14))
        layout.addWidget(icon_label)
        
        # Info
        info_layout = QVBoxLayout()
        info_layout.setSpacing(2)
        
        name_label = QLabel(item.original_filename)
        name_label.setFont(QFont("Segoe UI", 10))
        info_layout.addWidget(name_label)
        
        pages_label = QLabel(f"{item.page_count} pages")
        pages_label.setFont(QFont("Segoe UI", 9))
        pages_label.setObjectName("secondaryText")
        info_layout.addWidget(pages_label)
        
        layout.addLayout(info_layout)
        layout.addStretch()
        
        # Password protected warning
        if item.is_password_protected:
            warning = QLabel("Password protected")
            warning.setStyleSheet("color: #F59E0B;")
            warning.setFont(QFont("Segoe UI", 9))
            layout.addWidget(warning)
        
        # Remove button
        remove_btn = QPushButton("✕")
        remove_btn.setFixedSize(24, 24)
        remove_btn.setObjectName("removeButton")
        remove_btn.clicked.connect(lambda: self.remove_clicked.emit(self.index))
        layout.addWidget(remove_btn)


class ProgressRow(QFrame):
    """Progress row for conversion view."""
    
    def __init__(self, item: PDFItem, parent=None):
        super().__init__(parent)
        self.item = item
        self.setObjectName("progressRow")
        
        layout = QHBoxLayout(self)
        layout.setContentsMargins(16, 12, 16, 12)
        
        # Status icon
        self.status_label = QLabel("⏳")
        self.status_label.setFont(QFont("Segoe UI Emoji", 14))
        layout.addWidget(self.status_label)
        
        # Info
        info_layout = QVBoxLayout()
        info_layout.setSpacing(2)
        
        self.name_label = QLabel(item.sanitized_name)
        self.name_label.setFont(QFont("Segoe UI", 10))
        info_layout.addWidget(self.name_label)
        
        self.progress_label = QLabel(f"0/{item.page_count}")
        self.progress_label.setFont(QFont("Segoe UI", 9))
        self.progress_label.setObjectName("secondaryText")
        info_layout.addWidget(self.progress_label)
        
        layout.addLayout(info_layout)
        layout.addStretch()
    
    def update_progress(self, completed: int):
        self.progress_label.setText(f"{completed}/{self.item.page_count}")
    
    def set_status(self, status: str):
        icons = {
            "pending": "⏳",
            "in_progress": "🔄",
            "completed": "✅",
            "failed": "❌",
            "cancelled": "⏹️",
            "skipped": "⚠️"
        }
        self.status_label.setText(icons.get(status, "⏳"))


# ============================================================================
# MAIN WINDOW
# ============================================================================

class MainWindow(QMainWindow):
    """Main application window."""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("PDF to JPG by Camilo Hernandez")
        self.setMinimumSize(700, 600)
        
        # State
        self.job = Job()
        self.worker = None
        self.worker_thread = None
        self.progress_rows = []
        self.show_all_files = False  # For expandable queue list
        
        # Load saved destination
        settings = load_settings()
        if "last_destination" in settings:
            path = Path(settings["last_destination"])
            if path.exists():
                self.job.destination_path = path
        
        # Setup UI
        self.setup_ui()
        self.apply_styles()
        self.show_setup_view()
    
    def setup_ui(self):
        """Setup the main UI structure."""
        central = QWidget()
        self.setCentralWidget(central)
        
        self.main_layout = QVBoxLayout(central)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.main_layout.setSpacing(0)
        
        # Title bar
        title_bar = QFrame()
        title_bar.setObjectName("titleBar")
        title_layout = QHBoxLayout(title_bar)
        title_layout.setContentsMargins(24, 20, 24, 20)
        
        icon_label = QLabel("📄")
        icon_label.setFont(QFont("Segoe UI Emoji", 16))
        title_layout.addWidget(icon_label)
        
        title_label = QLabel("PDF to JPG")
        title_label.setFont(QFont("Segoe UI", 14, QFont.Weight.Bold))
        title_layout.addWidget(title_label)
        
        author_label = QLabel("by Camilo Hernandez")
        author_label.setFont(QFont("Segoe UI", 11))
        author_label.setObjectName("secondaryText")
        title_layout.addWidget(author_label)
        
        title_layout.addStretch()
        self.main_layout.addWidget(title_bar)
        
        # Content area
        self.content_area = QWidget()
        self.content_layout = QVBoxLayout(self.content_area)
        self.content_layout.setContentsMargins(24, 24, 24, 24)
        self.content_layout.setSpacing(24)
        self.main_layout.addWidget(self.content_area, stretch=1)
    
    def clear_content(self):
        """Clear the content area including nested layouts."""
        def clear_layout(layout):
            while layout.count():
                item = layout.takeAt(0)
                if item.widget():
                    item.widget().deleteLater()
                elif item.layout():
                    clear_layout(item.layout())
        
        clear_layout(self.content_layout)
    
    def show_setup_view(self):
        """Show the setup/configuration view."""
        self.clear_content()
        
        # Scroll area
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        
        scroll_content = QWidget()
        scroll_layout = QVBoxLayout(scroll_content)
        scroll_layout.setSpacing(24)
        
        # Output Location Card
        dest_card = SettingsCard("Output Location")
        dest_layout = QHBoxLayout()
        
        self.dest_label = QLabel(
            str(self.job.destination_path) if self.job.destination_path else "No destination selected"
        )
        self.dest_label.setObjectName("secondaryText" if not self.job.destination_path else "")
        dest_layout.addWidget(self.dest_label, stretch=1)
        
        choose_btn = QPushButton("Choose...")
        choose_btn.setObjectName("primaryButton")
        choose_btn.clicked.connect(self.choose_destination)
        dest_layout.addWidget(choose_btn)
        
        dest_card.add_layout(dest_layout)
        scroll_layout.addWidget(dest_card)
        
        # Job Name Card
        name_card = SettingsCard("Job Folder Name")
        
        self.name_input = QLineEdit()
        self.name_input.setPlaceholderText("Enter job folder name...")
        self.name_input.setObjectName("textInput")
        self.name_input.textChanged.connect(self.on_name_changed)
        name_card.add_widget(self.name_input)
        
        self.sanitized_label = QLabel("")
        self.sanitized_label.setStyleSheet("color: #F59E0B;")
        self.sanitized_label.hide()
        name_card.add_widget(self.sanitized_label)
        
        scroll_layout.addWidget(name_card)
        
        # PDF Selection Card
        pdf_card = SettingsCard("Select PDFs")
        
        drop_zone = PDFDropZone()
        drop_zone.files_dropped.connect(self.add_pdfs)
        drop_zone.browse_clicked.connect(self.browse_pdfs)
        pdf_card.add_widget(drop_zone)
        
        scroll_layout.addWidget(pdf_card)
        
        # Queue Card (if items exist)
        if self.job.pdf_items:
            queue_card = SettingsCard(f"Queued PDFs ({len(self.job.pdf_items)})")
            
            self.queue_layout = QVBoxLayout()
            self.queue_layout.setSpacing(8)
            
            # Show limited items or all based on state
            max_visible = 5
            items_to_show = self.job.pdf_items if self.show_all_files else self.job.pdf_items[:max_visible]
            hidden_count = len(self.job.pdf_items) - max_visible
            
            for i, item in enumerate(items_to_show):
                actual_index = i  # Index in the full list
                row = PDFQueueRow(item, actual_index)
                row.remove_clicked.connect(self.remove_pdf)
                self.queue_layout.addWidget(row)
            
            # Show More button (when collapsed and there are hidden items)
            if hidden_count > 0 and not self.show_all_files:
                show_more_btn = QPushButton(f"▼ Show {hidden_count} more file{'s' if hidden_count != 1 else ''}")
                show_more_btn.setObjectName("expandButton")
                show_more_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                show_more_btn.clicked.connect(self.expand_queue)
                self.queue_layout.addWidget(show_more_btn)
            
            # Show Less button (when expanded)
            if self.show_all_files and hidden_count > 0:
                show_less_btn = QPushButton("▲ Show less")
                show_less_btn.setObjectName("collapseButton")
                show_less_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                show_less_btn.clicked.connect(self.collapse_queue)
                self.queue_layout.addWidget(show_less_btn)
            
            queue_card.add_layout(self.queue_layout)
            
            # Total pages and clear button
            footer_layout = QHBoxLayout()
            total_label = QLabel(f"{self.job.total_pages} total pages")
            total_label.setObjectName("secondaryText")
            footer_layout.addWidget(total_label)
            footer_layout.addStretch()
            
            clear_btn = QPushButton("Clear All")
            clear_btn.setObjectName("dangerText")
            clear_btn.clicked.connect(self.clear_pdfs)
            footer_layout.addWidget(clear_btn)
            
            queue_card.add_layout(footer_layout)
            scroll_layout.addWidget(queue_card)
        
        scroll_layout.addStretch()
        scroll.setWidget(scroll_content)
        self.content_layout.addWidget(scroll, stretch=1)
        
        # Start Button
        self.start_btn = QPushButton("▶ Start Conversion")
        self.start_btn.setObjectName("startButton")
        self.start_btn.setFont(QFont("Segoe UI", 11, QFont.Weight.Bold))
        self.start_btn.setMinimumHeight(48)
        self.start_btn.clicked.connect(self.start_conversion)
        self.update_start_button()
        self.content_layout.addWidget(self.start_btn)
    
    def show_progress_view(self):
        """Show the progress view."""
        self.clear_content()
        
        # Title
        title = QLabel("Converting PDFs to JPG")
        title.setFont(QFont("Segoe UI", 16, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.content_layout.addWidget(title)
        
        # Overall progress bar
        self.overall_progress = QProgressBar()
        self.overall_progress.setMinimum(0)
        self.overall_progress.setMaximum(self.job.total_pages)
        self.overall_progress.setValue(0)
        self.overall_progress.setTextVisible(True)
        self.overall_progress.setFormat("%v of %m pages")
        self.content_layout.addWidget(self.overall_progress)
        
        # Progress list
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        
        scroll_content = QWidget()
        self.progress_list_layout = QVBoxLayout(scroll_content)
        self.progress_list_layout.setSpacing(8)
        
        self.progress_rows = []
        for item in self.job.pdf_items:
            row = ProgressRow(item)
            self.progress_rows.append(row)
            self.progress_list_layout.addWidget(row)
        
        self.progress_list_layout.addStretch()
        scroll.setWidget(scroll_content)
        self.content_layout.addWidget(scroll, stretch=1)
        
        # Cancel button
        cancel_btn = QPushButton("✕ Cancel")
        cancel_btn.setObjectName("cancelButton")
        cancel_btn.clicked.connect(self.cancel_conversion)
        self.content_layout.addWidget(cancel_btn)
    
    def show_summary_view(self):
        """Show the summary view."""
        self.clear_content()
        
        # Calculate stats
        completed = sum(1 for item in self.job.pdf_items if item.status == ConversionStatus.COMPLETED)
        failed = sum(1 for item in self.job.pdf_items if item.status == ConversionStatus.FAILED)
        cancelled = sum(1 for item in self.job.pdf_items if item.status == ConversionStatus.CANCELLED)
        
        # Success icon
        icon_label = QLabel("✅" if failed == 0 and cancelled == 0 else "⚠️")
        icon_label.setFont(QFont("Segoe UI Emoji", 48))
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.content_layout.addWidget(icon_label)
        
        # Title
        title = QLabel("Conversion Complete!" if failed == 0 else "Conversion Finished")
        title.setFont(QFont("Segoe UI", 18, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.content_layout.addWidget(title)
        
        # Stats
        stats_text = f"{self.job.completed_pages} pages converted"
        stats_label = QLabel(stats_text)
        stats_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        stats_label.setObjectName("secondaryText")
        self.content_layout.addWidget(stats_label)
        
        self.content_layout.addStretch()
        
        # Buttons
        btn_layout = QHBoxLayout()
        
        open_btn = QPushButton("📁 Open in Explorer")
        open_btn.setObjectName("primaryButton")
        open_btn.setMinimumHeight(44)
        open_btn.clicked.connect(self.open_job_folder)
        btn_layout.addWidget(open_btn)
        
        new_btn = QPushButton("➕ New Job")
        new_btn.setMinimumHeight(44)
        new_btn.clicked.connect(self.reset_job)
        btn_layout.addWidget(new_btn)
        
        self.content_layout.addLayout(btn_layout)
    
    def apply_styles(self):
        """Apply stylesheet to the window."""
        self.setStyleSheet(f"""
            QMainWindow {{
                background-color: {Theme.background()};
            }}
            
            #titleBar {{
                background-color: {Theme.card_background()};
                border-bottom: 1px solid {Theme.border()};
            }}
            
            #settingsCard {{
                background-color: {Theme.card_background()};
                border: 1px solid {Theme.border()};
                border-radius: 16px;
            }}
            
            #dropZone {{
                background-color: {Theme.input_background()};
                border: 2px dashed {Theme.border()};
                border-radius: 12px;
            }}
            
            #dropZone[dragOver="true"] {{
                border-color: {Theme.brand_blue()};
                background-color: rgba(83, 157, 219, 0.1);
            }}
            
            #queueRow, #progressRow {{
                background-color: {Theme.input_background()};
                border: 1px solid {Theme.border()};
                border-radius: 8px;
            }}
            
            #textInput {{
                background-color: {Theme.input_background()};
                border: 1px solid {Theme.border()};
                border-radius: 8px;
                padding: 12px;
                color: {Theme.text_primary()};
            }}
            
            #primaryButton {{
                background-color: {Theme.brand_blue()};
                color: white;
                border: none;
                border-radius: 8px;
                padding: 8px 16px;
                font-weight: bold;
            }}
            
            #primaryButton:hover {{
                background-color: #4A90C9;
            }}
            
            #startButton {{
                background-color: {Theme.brand_blue()};
                color: white;
                border: none;
                border-radius: 12px;
            }}
            
            #startButton:disabled {{
                background-color: #CCCCCC;
                color: #888888;
            }}
            
            #cancelButton {{
                background-color: transparent;
                color: #EF4444;
                border: 1px solid #EF4444;
                border-radius: 8px;
                padding: 12px;
            }}
            
            #removeButton {{
                background-color: transparent;
                border: none;
                color: {Theme.text_secondary()};
            }}
            
            #secondaryText {{
                color: {Theme.text_secondary()};
            }}
            
            #dangerText {{
                color: #EF4444;
                background: transparent;
                border: none;
            }}
            
            #expandButton {{
                background-color: rgba(83, 157, 219, 0.1);
                color: {Theme.brand_blue()};
                border: 1px solid rgba(83, 157, 219, 0.3);
                border-radius: 8px;
                padding: 12px;
                font-weight: 500;
            }}
            
            #expandButton:hover {{
                background-color: rgba(83, 157, 219, 0.2);
            }}
            
            #collapseButton {{
                background-color: transparent;
                color: {Theme.text_secondary()};
                border: none;
                padding: 8px;
            }}
            
            #collapseButton:hover {{
                color: {Theme.text_primary()};
            }}
            
            QLabel {{
                color: {Theme.text_primary()};
            }}
            
            QPushButton {{
                color: {Theme.text_primary()};
            }}
            
            QProgressBar {{
                background-color: {Theme.border()};
                border: none;
                border-radius: 4px;
                text-align: center;
            }}
            
            QProgressBar::chunk {{
                background-color: {Theme.brand_blue()};
                border-radius: 4px;
            }}
            
            QScrollArea {{
                background: transparent;
            }}
            
            QScrollArea > QWidget > QWidget {{
                background: transparent;
            }}
        """)
    
    # ========================================================================
    # ACTIONS
    # ========================================================================
    
    def choose_destination(self):
        """Open folder picker for destination."""
        path = QFileDialog.getExistingDirectory(
            self,
            "Choose Output Location",
            str(self.job.destination_path) if self.job.destination_path else ""
        )
        if path:
            self.job.destination_path = Path(path)
            self.dest_label.setText(path)
            self.dest_label.setObjectName("")
            
            # Save to settings
            save_settings({"last_destination": path})
            
            self.update_start_button()
    
    def on_name_changed(self, text: str):
        """Handle job name input change."""
        self.job.folder_name = text
        
        if text:
            sanitized = self.job.sanitized_folder_name
            if sanitized != text:
                self.sanitized_label.setText(f"Will be saved as: {sanitized}")
                self.sanitized_label.show()
            else:
                self.sanitized_label.hide()
        else:
            self.sanitized_label.hide()
        
        self.update_start_button()
    
    def browse_pdfs(self):
        """Open file picker for PDFs."""
        files, _ = QFileDialog.getOpenFileNames(
            self,
            "Select PDF Files",
            "",
            "PDF Files (*.pdf)"
        )
        if files:
            self.add_pdfs([Path(f) for f in files])
    
    def add_pdfs(self, paths: List[Path]):
        """Add PDFs to the queue."""
        for path in paths:
            # Check for duplicates
            if any(item.path == path for item in self.job.pdf_items):
                continue
            
            item = PDFItem.from_path(path)
            if item and item.page_count > 0:
                self.job.pdf_items.append(item)
        
        self.show_setup_view()
    
    def remove_pdf(self, index: int):
        """Remove a PDF from the queue."""
        if 0 <= index < len(self.job.pdf_items):
            del self.job.pdf_items[index]
        self.show_setup_view()
    
    def clear_pdfs(self):
        """Clear all PDFs from the queue."""
        self.job.pdf_items.clear()
        self.show_all_files = False
        self.show_setup_view()
    
    def expand_queue(self):
        """Expand the queue to show all files."""
        self.show_all_files = True
        self.show_setup_view()
    
    def collapse_queue(self):
        """Collapse the queue to show only 5 files."""
        self.show_all_files = False
        self.show_setup_view()
    
    def update_start_button(self):
        """Update the start button enabled state."""
        can_start = (
            self.job.destination_path is not None and
            self.job.folder_name.strip() != "" and
            len(self.job.pdf_items) > 0
        )
        self.start_btn.setEnabled(can_start)
    
    def start_conversion(self):
        """Start the conversion process."""
        self.job.is_running = True
        self.job.is_cancelled = False
        
        # Reset items
        for item in self.job.pdf_items:
            item.status = ConversionStatus.PENDING
            item.completed_pages = 0
            item.failed_pages = []
        
        self.show_progress_view()
        
        # Start worker thread
        self.worker = ConversionWorker(self.job)
        self.worker_thread = QThread()
        self.worker.moveToThread(self.worker_thread)
        
        self.worker_thread.started.connect(self.worker.run)
        self.worker.progress_updated.connect(self.on_progress_updated)
        self.worker.pdf_status_changed.connect(self.on_status_changed)
        self.worker.finished.connect(self.on_conversion_finished)
        
        self.worker_thread.start()
    
    def cancel_conversion(self):
        """Cancel the conversion process."""
        if self.worker:
            self.worker.cancel()
    
    def on_progress_updated(self, pdf_index: int, page_num: int, completed: int):
        """Handle progress update from worker."""
        if pdf_index < len(self.progress_rows):
            self.progress_rows[pdf_index].update_progress(completed)
        
        # Update item
        if pdf_index < len(self.job.pdf_items):
            self.job.pdf_items[pdf_index].completed_pages = completed
        
        # Update overall progress
        total_completed = sum(item.completed_pages for item in self.job.pdf_items)
        self.overall_progress.setValue(total_completed)
    
    def on_status_changed(self, pdf_index: int, status: str):
        """Handle status change from worker."""
        if pdf_index < len(self.progress_rows):
            self.progress_rows[pdf_index].set_status(status)
        
        # Update item status
        if pdf_index < len(self.job.pdf_items):
            status_map = {
                "pending": ConversionStatus.PENDING,
                "in_progress": ConversionStatus.IN_PROGRESS,
                "completed": ConversionStatus.COMPLETED,
                "failed": ConversionStatus.FAILED,
                "cancelled": ConversionStatus.CANCELLED,
                "skipped": ConversionStatus.SKIPPED
            }
            self.job.pdf_items[pdf_index].status = status_map.get(status, ConversionStatus.PENDING)
    
    def on_conversion_finished(self):
        """Handle conversion completion."""
        self.job.is_running = False
        
        if self.worker_thread:
            self.worker_thread.quit()
            self.worker_thread.wait()
        
        self.show_summary_view()
    
    def open_job_folder(self):
        """Open the job folder in Explorer."""
        if self.job.job_folder_path and self.job.job_folder_path.exists():
            FileSystemService.reveal_in_explorer(self.job.job_folder_path)
    
    def reset_job(self):
        """Reset for a new job."""
        destination = self.job.destination_path
        self.job = Job()
        self.job.destination_path = destination
        self.show_setup_view()


# ============================================================================
# MAIN
# ============================================================================

def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")
    
    window = MainWindow()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
