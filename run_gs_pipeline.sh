#!/usr/bin/env bash
set -euo pipefail

########################################
# 0) Parse args (SuGaR-style header)
########################################
SCENE_NAME="${1:-}"
shift || true

# Defaults (portable)
ITERS=${ITERS:-30000}
EVAL=0
WHITE_BG=0
NO_COLMAP=0

# Host paths (one common outputs folder)
HOST_DATA_ROOT="${DATA_ROOT:-$(pwd)/data}"
HOST_OUT_ROOT="${OUT_ROOT:-$(pwd)/outputs}"
# Host cache for the repo (persistent, outside the image)
HOST_REPO_CACHE="${HOST_REPO_CACHE:-$HOST_OUT_ROOT/.repo_gs}"

# Docker image & build
IMAGE_TAG="${IMAGE_TAG:-gaussian-splatting-docker}"
DOCKERFILE_DIR="${DOCKERFILE_DIR:-$(pwd)}"
FORCE_BUILD=0

# In-container paths
IN_REPO="/app/gaussian_splatting"
IN_DATA="/app/data"
IN_OUT="/app/output"
IN_CACHE="/app/.cache"
IN_CONF="/app/.config"
IN_CONDA="/app/.conda"
IN_HOME="/app"

usage() {
  cat <<EOF
Usage: $0 SCENE_NAME [options]

Options:
  -n, --iters N           Training iters (default: ${ITERS})
      --data_root PATH    Host data root (default: ${HOST_DATA_ROOT})
      --out_root  PATH    Host output root (default: ${HOST_OUT_ROOT})
      --image     TAG     Docker image tag (default: ${IMAGE_TAG})
      --dockerfile DIR    Directory with Dockerfile (for auto-build) (default: ${DOCKERFILE_DIR})
      --build             Force docker build before run
      --eval              Enable eval split (train/test) + run metrics
  -w, --white-bg          White background (NeRF Synthetic)
      --no-colmap         Skip convert.py even if sparse/0 missing
  -h, --help              Show this help

All results inside container (/app/output) are saved into ONE host folder: --out_root
EOF
}

# Simple arg parser
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--iters)       ITERS="$2"; shift 2;;
    --data_root)      HOST_DATA_ROOT="$2"; shift 2;;
    --out_root)       HOST_OUT_ROOT="$2"; shift 2;;
    --image)          IMAGE_TAG="$2"; shift 2;;
    --dockerfile)     DOCKERFILE_DIR="$2"; shift 2;;
    --build)          FORCE_BUILD=1; shift;;
    --eval)           EVAL=1; shift;;
    -w|--white-bg)    WHITE_BG=1; shift;;
    --no-colmap)      NO_COLMAP=1; shift;;
    -h|--help)        usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

if [[ -z "$SCENE_NAME" ]]; then usage; exit 1; fi

# Pretty header
echo "======================================"
echo " Running 3D Gaussian Splatting"
echo " Scene        : $SCENE_NAME"
echo " Iterations   : $ITERS"
echo " Data root    : $HOST_DATA_ROOT"
echo " Output root  : $HOST_OUT_ROOT   (ONE host folder for all results)"
echo " Docker image : $IMAGE_TAG"
echo " Eval split   : $([ $EVAL -eq 1 ] && echo yes || echo no)"
echo " White BG     : $([ $WHITE_BG -eq 1 ] && echo yes || echo no)"
echo " Skip COLMAP  : $([ $NO_COLMAP -eq 1 ] && echo yes || echo no)"
echo "======================================"

########################################
# Docker client (auto sudo fallback)
########################################
DOCKER="${DOCKER:-docker}"
if ! $DOCKER info >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER="sudo docker"
  else
    echo "[!] No access to Docker daemon. Run: sudo usermod -aG docker \$USER && relogin"
    exit 1
  fi
fi

########################################
# STEP 1: Prepare directories
########################################
echo "[*] STEP 1: Preparing directories..."
if [[ ! -d "$HOST_DATA_ROOT/$SCENE_NAME" ]]; then
  echo "[!] Scene not found: $HOST_DATA_ROOT/$SCENE_NAME"; exit 1
fi

mkdir -p "$HOST_OUT_ROOT" \
         "$HOST_OUT_ROOT/.cache" \
         "$HOST_OUT_ROOT/.config" \
         "$HOST_OUT_ROOT/.conda" \
         "$HOST_REPO_CACHE"
if command -v sudo >/dev/null 2>&1; then
  sudo chown -R "$(id -u)":"$(id -g)" "$HOST_OUT_ROOT" "$HOST_REPO_CACHE" 2>/dev/null || true
fi
chmod -R 775 "$HOST_OUT_ROOT" "$HOST_REPO_CACHE" 2>/dev/null || true

########################################
# STEP 2: Build image (if needed)
########################################
echo "[*] STEP 2: Ensuring Docker image exists..."
NEED_BUILD=$FORCE_BUILD
if ! $DOCKER image inspect "$IMAGE_TAG" >/dev/null 2>&1; then
  echo "[*] Image \"$IMAGE_TAG\" not found → will build."
  NEED_BUILD=1
fi
if [[ "$NEED_BUILD" -eq 1 ]]; then
  echo "[*] Building image: $IMAGE_TAG (Dockerfile dir: $DOCKERFILE_DIR)"
  (cd "$DOCKERFILE_DIR" && $DOCKER build -t "$IMAGE_TAG" .)
else
  echo "[*] Image present."
fi

########################################
# GPU flag
########################################
GPU_FLAG=""
if $DOCKER info 2>/dev/null | grep -qi 'Runtimes: .*nvidia'; then
  GPU_FLAG="--gpus all"
elif command -v nvidia-smi >/dev/null 2>&1; then
  GPU_FLAG="--gpus all"
fi

########################################
# STEP 2.5: Export repo from image → host cache (once)
########################################
echo "[*] STEP 2.5: Preparing host repo cache..."
# If the cache is empty, copy the repo from the image (run as root to access /root)
if [ -z "$(ls -A "$HOST_REPO_CACHE" 2>/dev/null || true)" ]; then
  $DOCKER run --rm -it \
    -v "$HOST_REPO_CACHE:/mnt/repo_host" \
    "$IMAGE_TAG" bash -lc "
      set -e
      if [ -d /app/gaussian_splatting ]; then SRC=/app/gaussian_splatting;
      elif [ -d /root/gaussian_splatting ]; then SRC=/root/gaussian_splatting;
      else echo '[!] Could not find repo in image'; exit 1; fi
      echo '[*] Copying repo from '\$SRC' to /mnt/repo_host ...'
      cp -a \"\$SRC/.\" /mnt/repo_host/
      echo '[+] Repo exported to host cache'
    "
  # Fix ownership on host
  if command -v sudo >/dev/null 2>&1; then
    sudo chown -R "$(id -u)":"$(id -g)" "$HOST_REPO_CACHE"
  fi
else
  echo "[*] Host repo cache already present."
fi

COMMON_MOUNTS=(
  -v "$HOST_DATA_ROOT:$IN_DATA"
  -v "$HOST_OUT_ROOT:$IN_OUT"
  -v "$HOST_OUT_ROOT/.cache:$IN_CACHE"
  -v "$HOST_OUT_ROOT/.config:$IN_CONF"
  -v "$HOST_OUT_ROOT/.conda:$IN_CONDA"
  -v "$HOST_REPO_CACHE:$IN_REPO:ro"
)

COMMON_ENVS=(
  -e HOME="$IN_HOME"
  -e XDG_CACHE_HOME="$IN_CACHE"
  -e XDG_CONFIG_HOME="$IN_CONF"
  -e TORCH_EXTENSIONS_DIR="$IN_CACHE/torch_extensions"
  -e CONDA_NO_PLUGINS=true
)

########################################
# STEP 3: Training
########################################
echo "[*] STEP 3: Training on scene=$SCENE_NAME..."
$DOCKER run --rm -it $GPU_FLAG -w "$IN_HOME" \
  "${COMMON_MOUNTS[@]}" \
  --user "$(id -u)":"$(id -g)" \
  "${COMMON_ENVS[@]}" \
  "$IMAGE_TAG" bash -lc "
    set -e
    cd '$IN_REPO'
    SCENE='$SCENE_NAME'
    ITERS='$ITERS'
    EVAL=$EVAL
    WHITE=$WHITE_BG
    NOCL=$NO_COLMAP

    echo '[i] Data : $IN_DATA/'\"\$SCENE\"
    echo '[i] Out  : $IN_OUT/'\"\$SCENE\"
    echo '[i] Repo : ' \$(pwd)

    SPARSE=\"$IN_DATA/\$SCENE/sparse/0\"
    INPUT_DIR=\"$IN_DATA/\$SCENE/input\"

    # Βρες αν ήδη υπάρχει αρχικό point cloud (.ply) από convert.py
    PLY_CANDIDATES=\$(ls \"$IN_DATA/\$SCENE\"/*point*cloud*.ply \
                         \"$IN_DATA/\$SCENE\"/points3D.ply \
                         \"$IN_DATA/\$SCENE\"/point_cloud/*/*.ply 2>/dev/null || true)

    if [ \"\$NOCL\" != \"1\" ]; then
      if [ -z \"\$PLY_CANDIDATES\" ]; then
        # Εξασφάλισε ότι υπάρχει input/: αν έχεις μόνο images/, κάνε symlink
        if [ ! -d \"\$INPUT_DIR\" ]; then
          if [ -d \"$IN_DATA/\$SCENE/images\" ]; then
            ln -s \"$IN_DATA/\$SCENE/images\" \"\$INPUT_DIR\" 2>/dev/null || true
          fi
        fi

        if [ -d \"\$INPUT_DIR\" ]; then
          echo \"[*] No initial .ply → running convert.py (expects \$SCENE/input)…\"
          python convert.py -s \"$IN_DATA/\$SCENE\"
        else
          echo \"[!] Provide raw images in: $IN_DATA/\$SCENE/input\"; exit 1
        fi
      else
        echo \"[*] Found initial .ply → skipping convert.\"
      fi
    else
      echo \"[*] Skipping COLMAP/convert (NOCL=1).\"
    fi

    # Μετά το convert πρέπει να υπάρχει .ply
    PLY_CANDIDATES=\$(ls \"$IN_DATA/\$SCENE\"/*point*cloud*.ply \
                         \"$IN_DATA/\$SCENE\"/points3D.ply \
                         \"$IN_DATA/\$SCENE\"/point_cloud/*/*.ply 2>/dev/null || true)
    if [ -z \"\$PLY_CANDIDATES\" ]; then
      echo \"[!] Conversion failed: no initial .ply found. Check \$SCENE/input and COLMAP.\"; exit 1
    fi

    TRAIN_FLAGS=''
    [ \"\$EVAL\"  = \"1\" ] && TRAIN_FLAGS=\"\$TRAIN_FLAGS --eval\"
    [ \"\$WHITE\" = \"1\" ] && TRAIN_FLAGS=\"\$TRAIN_FLAGS -w\"

    echo '[*] Training...'
    python train.py -s \"$IN_DATA/\$SCENE\" -m \"$IN_OUT/\$SCENE\" --iterations \"\$ITERS\" \$TRAIN_FLAGS
  "


########################################
# STEP 4: Render (+ metrics if --eval)
########################################
echo "[*] STEP 4: Rendering (and metrics if --eval)..."
$DOCKER run --rm -it $GPU_FLAG -w "$IN_HOME" \
  "${COMMON_MOUNTS[@]}" \
  --user "$(id -u)":"$(id -g)" \
  "${COMMON_ENVS[@]}" \
  "$IMAGE_TAG" bash -lc "
    set -e
    cd '$IN_REPO'
    SCENE='$SCENE_NAME'
    EVAL=$EVAL
    WHITE=$WHITE_BG

    RENDER_FLAGS=''
    [ \"\$WHITE\" = \"1\" ] && RENDER_FLAGS='-w'

    if [ \"\$EVAL\" = \"1\" ]; then
      python render.py  -m \"$IN_OUT/\$SCENE\" \$RENDER_FLAGS
      python metrics.py -m \"$IN_OUT/\$SCENE\"
    else
      python render.py  -m \"$IN_OUT/\$SCENE\" -s \"$IN_DATA/\$SCENE\" --skip_train \$RENDER_FLAGS
    fi
  "

########################################
# STEP 5: Export latest PLY
########################################
echo "[*] STEP 5: Exporting latest PLY..."
$DOCKER run --rm -it -w "$IN_HOME" \
  -v "$HOST_OUT_ROOT:$IN_OUT" \
  --user "$(id -u)":"$(id -g)" \
  -e HOME="$IN_HOME" \
  "$IMAGE_TAG" bash -lc "
    set -e
    SCENE='$SCENE_NAME'
    LATEST_DIR=\$(ls -d \"$IN_OUT/\$SCENE/point_cloud/iteration_\"* 2>/dev/null | sort -V | tail -n1 || true)
    if [ -n \"\$LATEST_DIR\" ] && [ -f \"\$LATEST_DIR/point_cloud.ply\" ]; then
      cp \"\$LATEST_DIR/point_cloud.ply\" \"$IN_OUT/\$SCENE/point_cloud_latest.ply\"
      echo \"[+] Saved: $IN_OUT/\$SCENE/point_cloud_latest.ply\"
    else
      echo '[!] Could not locate point_cloud.ply'
    fi
  "

echo "======================================"
echo " DONE! All results are in → $HOST_OUT_ROOT/$SCENE_NAME"

