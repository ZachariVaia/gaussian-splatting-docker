Gaussian Splatting (Docker) — Quick Start Guide ✨








A workflow to build the Docker image and run the Vanilla 3D Gaussian Splatting pipeline with a single script.
All results are written into one outputs/ folder on your host.

Note on fonts & colors: Markdown rendering (fonts, bold, colors) depends on your platform. On GitHub/GitLab/VS Code, headings, bold text, and these colored badges will display nicely. Code blocks are syntax-highlighted automatically.

TL;DR
# 1) Clone
git clone https://github.com/ZachariVaia/gaussian-splatting-docker.git
cd gaussian-splatting-docker

# 2) Build image (with sudo)
sudo docker build -t gaussian-splatting-docker:latest .

# 3) Run pipeline (example)
chmod +x run_gs_pipeline.sh
./run_gs_pipeline.sh bonsai \
  --data_root /path/to/your/data_root \
  --out_root  "$PWD/outputs" \
  --image     gaussian-splatting-docker:latest \
  --eval

Requirements

Git

Docker (with NVIDIA drivers + nvidia-container-toolkit for GPU)

Quick checks:

git --version
docker --version


GPU checks:

nvidia-smi
sudo docker run --rm --gpus all nvidia/cuda:12.1.1-base nvidia-smi

1) Clone the Repository
git clone https://github.com/ZachariVaia/gaussian-splatting-docker.git
cd gaussian-splatting-docker

chmod +x run_gs_pipeline.sh
mkdir -p outputs   # optional — the script creates it if missing


Expected data layout:

/path/to/your/data_root/
  <SCENE>/
    images/        # if you DON'T have COLMAP yet
    sparse/0/      # if you ALREADY have COLMAP

2) Build the Docker Image (with sudo)

From the repo root (where the Dockerfile lives):

sudo docker build -t gaussian-splatting-docker:latest .


The tag gaussian-splatting-docker:latest is what you pass to the script with --image.

3) Run the Pipeline

The script handles mounting data/outputs, optional COLMAP conversion, training, rendering, and (with --eval) metrics.

Example (MipNeRF360 bonsai)
./run_gs_pipeline.sh bonsai \
  --data_root /path/to/your/data_root \
  --out_root  "$PWD/outputs" \
  --image     gaussian-splatting-docker:latest \
  --eval


Notes

If only images/ exists → runs convert.py (COLMAP) automatically.

If sparse/0/ exists → conversion is skipped.

For NeRF Synthetic, add -w (or --white-bg).

Script Flags (Quick Reference)

-n, --iters N — training iterations (default: 30000)

--data_root PATH — host data root (default: ./data)

--out_root PATH — single host outputs folder (default: ./outputs)

--image TAG — Docker image tag (default: gaussian-splatting-docker)

--dockerfile DIR — path with Dockerfile for auto-build if image is missing

--build — force a fresh build before running

--eval — also run render.py & metrics.py after training

-w, --white-bg — white background (NeRF Synthetic)

--no-colmap — never run convert.py even if sparse/0 is missing

Output Location

Everything is written to:

<repo>/outputs/<SCENE>/


Persistent folders used by the pipeline:

outputs/.cache/    # PyTorch extensions, etc.
outputs/.config/   # app/config (e.g., conda)
outputs/.conda/    # conda home (if used)
outputs/.repo_gs/  # read-only copy of the repo pulled from the image

Troubleshooting

Docker “permission denied”

sudo usermod -aG docker $USER
newgrp docker
docker info


Image not found

sudo docker build -t gaussian-splatting-docker:latest .


Or pass the correct tag with --image.

“Scene not found”
Ensure --data_root/<SCENE> exists and is spelled correctly.

No results appear
Use an absolute --out_root or "$PWD/outputs" and re-run.
The script prints the mounts it uses.

GPU not used
Install nvidia-container-toolkit, ensure recent NVIDIA drivers, and verify docker run --gpus all works.
The script automatically uses --gpus all when available.

Conda/libtinfo warnings
Harmless. Configs/caches are sandboxed under /app and the script continues.

(Optional) Live Remote Viewer with SIBR

If you built SIBR_viewers into the image:

Expose the training port and pass flags to train.py:

Port mapping: -p 6009:6009

Flags: --ip 0.0.0.0 --port 6009

Run the viewer in Docker with X11:

xhost +local:docker
sudo docker run --rm -it --gpus all --network host \
  -e DISPLAY=$DISPLAY -e QT_X11_NO_MITSHM=1 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v /path/to/data:/app/data \
  gaussian-splatting-docker:latest \
  SIBR_remoteGaussian_app --ip 127.0.0.1 --port 6009 -s /app/data/bonsai

Quick Commands Recap
# Build image (with sudo)
sudo docker build -t gaussian-splatting-docker:latest .

# Run pipeline (example)
./run_gs_pipeline.sh bonsai \
  --data_root /path/to/data_root \
  --out_root  "$PWD/outputs" \
  --image     gaussian-splatting-docker:latest \
  --eval

# NeRF Synthetic (white background)
./run_gs_pipeline.sh lego \
  --data_root /path/to/nerf_synthetic \
  --out_root  "$PWD/outputs" \
  --image     gaussian-splatting-docker:latest \
  --eval -w
