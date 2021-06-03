FROM continuumio/miniconda3:4.8.2
LABEL authors="Gisela Gabernet" \
      description="Docker image containing all software requirements for the qbic-pipelines/cellranger pipeline"

# Install procps and clean apt cache
RUN apt-get update \
  && apt-get install -y procps \
  && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install the conda environment
COPY environment.yml /
RUN conda env create --quiet -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/qbic-pipelines-cellranger-1.0/bin:$PATH

# Dump the details of the installed packages to a file for posterity
RUN conda env export --name qbic-pipelines-cellranger-1.0 > qbic-pipelines-cellranger-1.0.yml

# Copy pre-downloaded cellranger file
ENV CELLRANGER_VER 5.0.1
COPY cellranger-$CELLRANGER_VER.tar.gz /opt/cellranger-$CELLRANGER_VER.tar.gz

# Install cellranger
RUN \
  cd /opt && \
  tar -xzvf cellranger-$CELLRANGER_VER.tar.gz && \
  export PATH=/opt/cellranger-$CELLRANGER_VER:$PATH && \
  ln -s /opt/cellranger-$CELLRANGER_VER/cellranger /usr/bin/cellranger && \
  rm -rf /opt/cellranger-$CELLRANGER_VER.tar.gz

# Instruct R processes to use these empty files instead of clashing with a local version
RUN touch .Rprofile
RUN touch .Renviron
