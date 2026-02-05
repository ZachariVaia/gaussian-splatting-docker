#!/usr/bin/env python3
"""
Interactive Gaussian Splatting Viewer
A simple web-based tool to visualize and manipulate 3D Gaussians with real-time rasterization.
"""

import torch
import numpy as np
from flask import Flask, render_template, jsonify, request, send_from_directory
import os
import sys
import math
from PIL import Image
import io
import base64

# Add the parent directory to the path to import gaussian_splatting modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from scene.gaussian_model import GaussianModel
from utils.graphics_utils import BasicPointCloud
from gaussian_renderer import render
from scene.cameras import Camera
from utils.general_utils import PILtoTorch
from arguments import PipelineParams

app = Flask(__name__)

# Global state
gaussians = None
pipeline = None

class SimpleCamera:
    """Simple camera class for rendering"""
    def __init__(self, width, height, fovy, fovx, znear, zfar, world_view_transform, full_proj_transform):
        self.image_width = width
        self.image_height = height
        self.FoVy = fovy
        self.FoVx = fovx
        self.znear = znear
        self.zfar = zfar
        self.world_view_transform = world_view_transform
        self.full_proj_transform = full_proj_transform
        self.camera_center = self.world_view_transform.inverse()[:3, 3]

def create_view_matrix(camera_position, look_at, up):
    """Create a view matrix from camera parameters"""
    camera_position = np.array(camera_position, dtype=np.float32)
    look_at = np.array(look_at, dtype=np.float32)
    up = np.array(up, dtype=np.float32)
    
    # Calculate camera coordinate system
    z = camera_position - look_at
    z = z / np.linalg.norm(z)
    
    x = np.cross(up, z)
    x = x / np.linalg.norm(x)
    
    y = np.cross(z, x)
    
    # Create view matrix
    view_matrix = np.eye(4, dtype=np.float32)
    view_matrix[0, :3] = x
    view_matrix[1, :3] = y
    view_matrix[2, :3] = z
    view_matrix[:3, 3] = -np.array([np.dot(x, camera_position), 
                                     np.dot(y, camera_position), 
                                     np.dot(z, camera_position)])
    
    return view_matrix

def create_projection_matrix(fovy, aspect, znear, zfar):
    """Create a perspective projection matrix"""
    tan_half_fovy = np.tan(fovy / 2)
    
    proj_matrix = np.zeros((4, 4), dtype=np.float32)
    proj_matrix[0, 0] = 1 / (aspect * tan_half_fovy)
    proj_matrix[1, 1] = 1 / tan_half_fovy
    proj_matrix[2, 2] = -(zfar + znear) / (zfar - znear)
    proj_matrix[2, 3] = -2 * zfar * znear / (zfar - znear)
    proj_matrix[3, 2] = -1
    
    return proj_matrix

def initialize_gaussians(gaussian_params):
    """Initialize Gaussian model with custom parameters"""
    global gaussians, pipeline
    
    # Create a new Gaussian model
    gaussians = GaussianModel(sh_degree=0)
    
    # Initialize pipeline parameters
    pipeline = PipelineParams()
    
    # Extract parameters
    num_gaussians = len(gaussian_params)
    
    # Create tensors for Gaussian parameters
    xyz = torch.zeros((num_gaussians, 3), dtype=torch.float32, device="cuda")
    colors = torch.zeros((num_gaussians, 3), dtype=torch.float32, device="cuda")
    opacities = torch.zeros((num_gaussians, 1), dtype=torch.float32, device="cuda")
    scales = torch.zeros((num_gaussians, 3), dtype=torch.float32, device="cuda")
    rotations = torch.zeros((num_gaussians, 4), dtype=torch.float32, device="cuda")
    
    # Set rotation to identity quaternion (w=1, x=0, y=0, z=0)
    rotations[:, 0] = 1.0
    
    for i, params in enumerate(gaussian_params):
        xyz[i] = torch.tensor(params['position'], dtype=torch.float32)
        
        # Convert RGB from [0, 255] to [0, 1] and then to SH
        rgb = np.array(params['color']) / 255.0
        from utils.sh_utils import RGB2SH
        colors[i] = torch.tensor(RGB2SH(rgb), dtype=torch.float32)
        
        # Opacity: apply inverse sigmoid
        opacity_val = params['opacity']
        from utils.general_utils import inverse_sigmoid
        opacities[i] = inverse_sigmoid(torch.tensor([opacity_val], dtype=torch.float32))
        
        # Scale: apply log (inverse of exp activation)
        scale_val = params['scale']
        scales[i] = torch.log(torch.tensor([scale_val, scale_val, scale_val], dtype=torch.float32))
    
    # Set the parameters
    gaussians._xyz = xyz
    gaussians._features_dc = colors.unsqueeze(1)
    gaussians._features_rest = torch.zeros((num_gaussians, 0, 3), dtype=torch.float32, device="cuda")
    gaussians._opacity = opacities
    gaussians._scaling = scales
    gaussians._rotation = rotations
    gaussians.active_sh_degree = 0
    gaussians.max_radii2D = torch.zeros((num_gaussians), dtype=torch.float32, device="cuda")

def render_gaussians(camera_params):
    """Render the Gaussians from a specific camera viewpoint"""
    global gaussians, pipeline
    
    if gaussians is None:
        return None
    
    # Extract camera parameters
    width = camera_params.get('width', 800)
    height = camera_params.get('height', 600)
    camera_pos = camera_params.get('position', [0, 0, 5])
    look_at = camera_params.get('lookAt', [0, 0, 0])
    
    # Create camera matrices
    fovy = math.radians(45)
    aspect = width / height
    fovx = 2 * math.atan(math.tan(fovy / 2) * aspect)
    znear = 0.01
    zfar = 100.0
    
    view_matrix = create_view_matrix(camera_pos, look_at, [0, 1, 0])
    proj_matrix = create_projection_matrix(fovy, aspect, znear, zfar)
    
    # Convert to torch tensors
    view_matrix_torch = torch.from_numpy(view_matrix).cuda()
    proj_matrix_torch = torch.from_numpy(proj_matrix).cuda()
    full_proj_transform = proj_matrix_torch @ view_matrix_torch
    
    # Create camera object
    camera = SimpleCamera(
        width=width,
        height=height,
        fovy=fovy,
        fovx=fovx,
        znear=znear,
        zfar=zfar,
        world_view_transform=view_matrix_torch,
        full_proj_transform=full_proj_transform
    )
    
    # Background color (black)
    bg_color = torch.tensor([0, 0, 0], dtype=torch.float32, device="cuda")
    
    # Render
    with torch.no_grad():
        rendered_dict = render(camera, gaussians, pipeline, bg_color)
        rendered_image = rendered_dict["render"]
    
    # Convert to numpy and then to PIL Image
    image_np = rendered_image.cpu().numpy()
    image_np = np.transpose(image_np, (1, 2, 0))  # CHW to HWC
    image_np = np.clip(image_np * 255, 0, 255).astype(np.uint8)
    
    return image_np

@app.route('/')
def index():
    """Serve the main HTML page"""
    return render_template('interactive_viewer.html')

@app.route('/static/<path:path>')
def send_static(path):
    """Serve static files"""
    return send_from_directory('static', path)

@app.route('/api/render', methods=['POST'])
def api_render():
    """Render Gaussians with given parameters"""
    try:
        data = request.json
        gaussian_params = data.get('gaussians', [])
        camera_params = data.get('camera', {})
        
        # Initialize or update Gaussians
        initialize_gaussians(gaussian_params)
        
        # Render
        image_np = render_gaussians(camera_params)
        
        if image_np is None:
            return jsonify({'error': 'Failed to render'}), 500
        
        # Convert to base64 for sending to browser
        pil_image = Image.fromarray(image_np)
        buffer = io.BytesIO()
        pil_image.save(buffer, format='PNG')
        img_str = base64.b64encode(buffer.getvalue()).decode()
        
        return jsonify({'image': f'data:image/png;base64,{img_str}'})
    
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Check if CUDA is available
    if not torch.cuda.is_available():
        print("WARNING: CUDA is not available. This application requires GPU support.")
        sys.exit(1)
    
    print("Starting Interactive Gaussian Splatting Viewer...")
    print("Open your browser and navigate to: http://localhost:5000")
    
    # Note: debug=False for security. Set to True only for development.
    app.run(host='0.0.0.0', port=5000, debug=False)
