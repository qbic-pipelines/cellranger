FROM continuumio/miniconda3:4.8.2
LABEL authors="Gisela Gabernet" \
    description="Docker image containing all software requirements for the qbic-pipelines/cellranger pipeline"

# Install procps and clean apt cache
RUN apt-get update \
    && apt-get install -y procps \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Copy pre-downloaded cellranger file
ENV CELLRANGER_VER 6.0.2
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
