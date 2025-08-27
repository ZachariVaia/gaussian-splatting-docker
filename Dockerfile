FROM nvidia/cuda:11.8.0-devel-ubuntu20.04

# Install base utilities
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y build-essential wget ninja-build unzip libgl-dev ffmpeg\
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install miniconda
ENV CONDA_DIR /opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda

# Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

WORKDIR /root/gaussian_splatting
COPY ./ ./

ENV TORCH_CUDA_ARCH_LIST="3.5;5.0;6.0;6.1;7.0;7.5;8.0;8.6+PTX"
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

RUN conda update -n base conda
RUN conda install -n base conda-libmamba-solver
RUN conda config --set solver libmamba


RUN conda env create -f environment.yml
RUN conda run -n gaussian_splatting pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
RUN conda run -n gaussian_splatting pip install ./submodules/diff-gaussian-rasterization
RUN conda run -n gaussian_splatting pip install ./submodules/simple-knn



# RUN echo "conda activate gaussian_splatting" >> ~/.bashrc
# SHELL ["conda", "run", "-n", "gaussian_splatting", "/bin/bash", "-c"]

# Χρησιμοποίησε το σωστό κανάλι για το colmap (conda-forge)
RUN conda install -c conda-forge jupyter colmap



WORKDIR /root/

# ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "gaussian_splatting", "jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--allow-root"]
CMD ["python", "gaussian_splatting/train.py"]
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "gaussian_splatting"]
