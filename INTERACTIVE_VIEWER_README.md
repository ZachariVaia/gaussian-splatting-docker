# Interactive Gaussian Splatting Viewer

An easy-to-use, beautiful interactive web application for visualizing and manipulating 3D Gaussians with real-time rasterization.

![Interactive Viewer Screenshot](https://github.com/user-attachments/assets/90e7385e-5afc-4485-b669-6e07dfdfd367)

## Features

✨ **Interactive Controls**
- Place and move 3 Gaussians in 3D space (X, Y, Z positions)
- Adjust scale for each Gaussian (0.1 to 2.0)
- Control opacity from fully transparent to fully opaque
- Pick custom colors for each Gaussian

🎥 **Camera Controls**
- Adjustable camera distance
- Horizontal and vertical rotation
- Real-time preview of viewing angles

🎨 **Beautiful UI**
- Modern, gradient-based design
- Smooth animations and transitions
- Responsive layout
- Real-time rendering feedback

## Requirements

- Python 3.9+
- CUDA-capable GPU
- PyTorch with CUDA support
- Flask

## Installation

### Option 1: Using Conda Environment

1. Set up the main Gaussian Splatting environment first (if not already done):
```bash
conda env create --file environment.yml
conda activate gaussian_splatting
```

2. Install additional dependencies for the interactive viewer:
```bash
pip install -r requirements_interactive_viewer.txt
```

### Option 2: Using Docker

If you're using Docker (as this repository supports), you can:

1. Build the Docker image with the project
2. Run the container with port mapping:
```bash
docker run -p 5000:5000 --gpus all <your-image-name> python interactive_viewer.py
```

### Quick Setup

Simply run:
```bash
pip install flask pillow
```

Then start the viewer (see Usage section below).

## Usage

1. Start the interactive viewer server:
```bash
python interactive_viewer.py
```

2. Open your web browser and navigate to:
```
http://localhost:5000
```

3. Use the controls on the left panel to:
   - Adjust the position (X, Y, Z) of each Gaussian
   - Change the scale (size) of each Gaussian
   - Modify the opacity (transparency)
   - Pick different colors
   - Move the camera around the scene

4. The rendering updates automatically when you change parameters (if "Auto-render on change" is checked), or click the "Render Gaussians" button to update manually.

## How It Works

The viewer uses:
- **Backend**: Flask server that handles Gaussian rasterization using the existing Gaussian Splatting CUDA kernels
- **Frontend**: Modern HTML/CSS/JavaScript interface with real-time controls
- **Rendering**: GPU-accelerated rendering through the existing `gaussian_renderer` module

## Tips

- Start with the default 3 Gaussians to understand how they interact
- Try overlapping Gaussians with different colors and opacities to see blending effects
- Rotate the camera to view the scene from different angles
- Adjust the scale to see how Gaussian size affects the final render
- Enable/disable auto-render based on your preference for performance

## Troubleshooting

**Error: CUDA is not available**
- Make sure you have a CUDA-capable GPU
- Verify that PyTorch is installed with CUDA support: `python -c "import torch; print(torch.cuda.is_available())"`

**Error: Module not found**
- Ensure you're in the correct conda environment: `conda activate gaussian_splatting`
- Make sure all dependencies are installed

**Slow rendering**
- This is expected on first render as CUDA kernels initialize
- Subsequent renders should be faster
- Disable auto-render if changes are too frequent

## Technical Details

The interactive viewer creates a simplified Gaussian Splatting scene with:
- 3 Gaussians with customizable properties
- Simple camera model with perspective projection
- Real-time rasterization using the diff_gaussian_rasterization CUDA extension
- Web-based interface using Flask for the backend and vanilla JavaScript for the frontend

The rendering pipeline follows the same process as the main training loop but with a fixed, user-defined set of Gaussians instead of learned ones.
