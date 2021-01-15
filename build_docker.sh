#!/bin/bash
# Building the container requires the manual download of cellranger in the build directory
# From: https://support.10xgenomics.com/single-cell-gene-expression/software/downloads/latest
docker build --no-cache . -t qbicpipelines/cellranger:latest
# Need to login before being able to push
docker push qbicpipelines/cellranger:latest