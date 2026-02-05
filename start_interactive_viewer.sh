#!/bin/bash
# Startup script for Interactive Gaussian Splatting Viewer

echo "🎨 Interactive Gaussian Splatting Viewer"
echo "========================================"
echo ""

# Check if Python is available
if ! command -v python &> /dev/null; then
    echo "❌ Error: Python is not installed or not in PATH"
    exit 1
fi

# Check if Flask and Pillow are installed
if ! python -c "import flask" 2>/dev/null || ! python -c "from PIL import Image" 2>/dev/null; then
    echo "📦 Installing Flask and Pillow..."
    pip install flask pillow --quiet
fi

# Check if PyTorch is available
if ! python -c "import torch" 2>/dev/null; then
    echo "⚠️  Warning: PyTorch not found. Please install PyTorch with CUDA support."
    echo "   Visit: https://pytorch.org/get-started/locally/"
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check CUDA availability
if python -c "import torch; exit(0 if torch.cuda.is_available() else 1)" 2>/dev/null; then
    echo "✅ CUDA is available"
else
    echo "⚠️  Warning: CUDA is not available. GPU acceleration will not work."
    echo ""
fi

echo ""
echo "🚀 Starting Interactive Viewer..."
echo "   Open your browser and navigate to: http://localhost:5000"
echo ""
echo "   Press Ctrl+C to stop the server"
echo ""

# Run the viewer
python interactive_viewer.py
