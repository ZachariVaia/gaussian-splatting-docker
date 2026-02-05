@echo off
REM Startup script for Interactive Gaussian Splatting Viewer (Windows)

echo 🎨 Interactive Gaussian Splatting Viewer
echo ========================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Error: Python is not installed or not in PATH
    pause
    exit /b 1
)

REM Check if Flask and Pillow are installed
python -c "import flask" >nul 2>&1
set FLASK_INSTALLED=%errorlevel%
python -c "from PIL import Image" >nul 2>&1
set PILLOW_INSTALLED=%errorlevel%

if %FLASK_INSTALLED% neq 0 (
    echo 📦 Installing Flask and Pillow...
    pip install flask pillow --quiet
) else if %PILLOW_INSTALLED% neq 0 (
    echo 📦 Installing Pillow...
    pip install pillow --quiet
)

REM Check if PyTorch is available
python -c "import torch" >nul 2>&1
if errorlevel 1 (
    echo ⚠️  Warning: PyTorch not found. Please install PyTorch with CUDA support.
    echo    Visit: https://pytorch.org/get-started/locally/
    echo.
    pause
)

REM Check CUDA availability
python -c "import torch; exit(0 if torch.cuda.is_available() else 1)" >nul 2>&1
if not errorlevel 1 (
    echo ✅ CUDA is available
) else (
    echo ⚠️  Warning: CUDA is not available. GPU acceleration will not work.
    echo.
)

echo.
echo 🚀 Starting Interactive Viewer...
echo    Open your browser and navigate to: http://localhost:5000
echo.
echo    Press Ctrl+C to stop the server
echo.

REM Run the viewer
python interactive_viewer.py

pause
