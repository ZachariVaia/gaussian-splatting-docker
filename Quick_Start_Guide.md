Gaussian Splatting (Docker) — Quick Start Guide

This README gives you a clean, SuGaR-style path to build the Docker image and run the Vanilla 3D Gaussian Splatting pipeline with a single script. All results land in one outputs/ folder on your host.

Requirements

Git

Docker (NVIDIA drivers + nvidia-container-toolkit for GPU)

Check installations:

git --version
docker --version


GPU users: verify nvidia-smi works on host and Docker sees GPUs (docker run --rm --gpus all nvidia/cuda:12.1.1-base nvidia-smi).

1) Clone the Repository

Create a working folder (e.g., in your home), clone this repo, and make the script executable:

cd ~
mkdir -p gaussian-splatting-docker && cd gaussian-splatting-docker

# If this repo is remote:
git clone <this-repo-url> .
# otherwise copy your files here

chmod +x run_gs_pipeline.sh
mkdir -p outputs   # optional — the script also creates it


The outputs/ folder is where all pipeline results will be stored.

2) Build the Docker Image

From the repo root (where the Dockerfile lives):

docker build -t gaussian-splatting-docker:latest .


-t gaussian-splatting-docker:latest gives the image a tag you’ll reference in the script.

Use your own tag if you prefer (and pass it via --image to the script).

3) Run the Pipeline

You run one script; it takes care of mounting data/outputs, COLMAP conversion (if needed), training, rendering, and metrics.

A) Run inside Docker (recommended)
# Example: MipNeRF360 "bonsai"
./run_gs_pipeline.sh bonsai \
  --data_root /path/to/your/data_root \
  --out_root  "$PWD/outputs" \
  --image     gaussian-splatting-docker:latest \
  --eval


If your scene has only images/, the script auto-runs convert.py (COLMAP).

If sparse/0/ exists, it skips conversion.

For NeRF Synthetic, add -w (--white-bg).



4) Output Location

All results are stored under:

<repo>/outputs/<SCENE>/


Plus persistent caches/configs in:

outputs/.cache/   # torch extensions, etc.
outputs/.config/  # config files (e.g., conda)
outputs/.conda/   # conda home (if used)

Troubleshooting

Docker permission denied
Add your user to the docker group:

sudo usermod -aG docker $USER
newgrp docker
docker info


Image not found
Build it first:

docker build -t gaussian-splatting-docker:latest .


Or pass the correct tag via --image.

“Scene not found”
Check your --data_root and ensure --data_root/<SCENE> exists.

No results appear
Use an absolute --out_root or "$PWD/outputs" and re-run. The script prints all the mounts it uses.

GPU not used
Install nvidia-container-toolkit and run with a recent NVIDIA driver. The script will use --gpus all if available.

Conda/libtinfo warnings
Harmless. The script isolates configs/caches under /app and continues.

Quick Commands
# Build image
docker build -t gaussian-splatting-docker:latest .

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

Done!

You’re ready to train and evaluate Gaussian Splatting in Docker with a single command. 🚀
