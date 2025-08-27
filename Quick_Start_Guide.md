#Gaussian Splatting (Docker) — Quick Start Guide ✨


## Requirements

* **Git**
* **Docker** (with NVIDIA drivers + `nvidia-container-toolkit` if you want GPU support)

Check installations:

```bash
git --version
docker --version
```

---
## 1) Clone
```bash
git clone https://github.com/ZachariVaia/gaussian-splatting-docker.git --recursive
cd gaussian-splatting-docker
```
## 2) Build image (with sudo)
```bash
sudo docker build -t gaussian-splatting-docker:latest .
```

## 3) Run pipeline (example)
```bash
mkdir -p outputs   # optional — the script creates it if missing
chmod +x run_gs_pipeline.sh
./run_gs_pipeline.sh bonsai \
  --data_root /path/to/your/data_root \
  --out_root  "$PWD/outputs" \
  --image     gaussian-splatting-docker:latest \
  --eval
```


## Quick checks:

Expected data layout:

/path/to/your/data_root/
  <SCENE>/
    images/        # if you DON'T have COLMAP yet
    sparse/0/      # if you ALREADY have COLMAP


## Run the Pipeline

The script handles mounting data/outputs, optional COLMAP conversion, training, rendering, and (with --eval) metrics.

Example (MipNeRF360 bonsai)
```bash
./run_gs_pipeline.sh bonsai \
  --data_root /path/to/your/data_root \
  --out_root  "$PWD/outputs" \
  --image     gaussian-splatting-docker:latest \
  --eval
```

## Notes

If only images/ exists → runs convert.py (COLMAP) automatically.

If sparse/0/ exists → conversion is skipped.

For NeRF Synthetic, add -w (or --white-bg).

Script Flags (Quick Reference)
```bash

-n, --iters N — training iterations (default: 30000)

--data_root PATH — host data root (default: ./data)

--out_root PATH — single host outputs folder (default: ./outputs)

--image TAG — Docker image tag (default: gaussian-splatting-docker)

--dockerfile DIR — path with Dockerfile for auto-build if image is missing

--build — force a fresh build before running

--eval — also run render.py & metrics.py after training

-w, --white-bg — white background (NeRF Synthetic)

--no-colmap — never run convert.py even if sparse/0 is missing
```
### Output Location

Everything is written to:

<repo>/outputs/<SCENE>/


Persistent folders used by the pipeline:

outputs/.cache/    # PyTorch extensions, etc.
outputs/.config/   # app/config (e.g., conda)
outputs/.conda/    # conda home (if used)
outputs/.repo_gs/  # read-only copy of the repo pulled from the image

## Custom data with colmap
```
~/gaussian-splatting-docker$ sudo docker run --rm -it --gpus all -w /app/gaussian_splatting   -v "/home/ilias/thanos:/app/data"   -v "$PWD/outputs:/app/output"   -v "$PWD/outputs/.repo_gs:/app/gaussian_splatting:ro"   --user "$(id -u)":"$(id -g)" -e HOME=/app gaussian-splatting-docker:latest   bash -lc 'python convert.py -s /app/data/realistic-temple --skip_matching'


./run_gs_pipeline.sh realistic-temple   --data_root /home/ilias/thanos/   --out_root "$PWD/outputs"   --image gaussian-splatting-docker:latest   --eval

```


## Troubleshooting

## Docker “permission denied”
```bash
sudo usermod -aG docker $USER
newgrp docker
docker info
```


## Image not found
```bash
sudo docker build -t gaussian-splatting-docker:latest .
```

Or pass the correct tag with --image.

## “Scene not found”
Ensure --data_root/<SCENE> exists and is spelled correctly.

No results appear
Use an absolute --out_root or "$PWD/outputs" and re-run.
The script prints the mounts it uses.

## GPU not used
Install nvidia-container-toolkit, ensure recent NVIDIA drivers, and verify docker run --gpus all works.
The script automatically uses --gpus all when available.

Conda/libtinfo warnings
Harmless. Configs/caches are sandboxed under /app and the script continues.

## (Optional) Live Remote Viewer with SIBR

If you built SIBR_viewers into the image:

Expose the training port and pass flags to train.py:

Port mapping: -p 6009:6009

Flags: --ip 0.0.0.0 --port 6009

## Run the viewer in Docker with X11:
```bash
xhost +local:docker
sudo docker run --rm -it --gpus all --network host \
  -e DISPLAY=$DISPLAY -e QT_X11_NO_MITSHM=1 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v /path/to/data:/app/data \
  gaussian-splatting-docker:latest \
  SIBR_remoteGaussian_app --ip 127.0.0.1 --port 6009 -s /app/data/bonsai
```
## Quick Commands Recap
## Build image (with sudo)
sudo docker build -t gaussian-splatting-docker:latest .

## Run pipeline (example)
```
./run_gs_pipeline.sh bonsai \
  --data_root /path/to/data_root \
  --out_root  "$PWD/outputs" \
  --image     gaussian-splatting-docker:latest \
  --eval
```
## NeRF Synthetic (white background)
```
./run_gs_pipeline.sh lego \
  --data_root /path/to/nerf_synthetic \
  --out_root  "$PWD/outputs" \
  --image     gaussian-splatting-docker:latest \
  --eval -w
  ```
