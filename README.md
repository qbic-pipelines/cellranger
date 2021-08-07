# qbic-pipelines/cellranger

**Nextflow wrapper around the Cell Ranger pipeline for single cell RNAseq analysis**.

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A521.04.1-brightgreen.svg)](https://www.nextflow.io/)
[![GitHub Actions CI Status](https://github.com/qbic-pipelines/cellranger/workflows/nf-core%20CI/badge.svg)](https://github.com/qbic-pipelines/cellranger/actions)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

**qbic-pipelines/cellranger** is a Nextflow pipeline that wraps the Cell Ranger pipeline for single cell RNAseq analysis. It additionally performs QC on the Fastq files
with `FastQC` and summarizes the QC with `MultiQC`.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

## Pipeline summary

1. Read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
2. Single-cell data analysis with Cell Ranger (`cellranger count`)
3. Present QC for raw reads ([`MultiQC`](http://multiqc.info/))

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=21.04.0`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```bash
    nextflow run qbic-pipelines/cellranger -profile test,<docker/singularity/podman/conda/institute>
    ```

    > * Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
    > * If you are using `singularity` then the pipeline will auto-detect this and attempt to download the Singularity images directly as opposed to performing a conversion from Docker images. If you are persistently observing issues downloading Singularity images directly due to timeout or network issues then please use the `--singularity_pull_docker_container` parameter to pull and convert the Docker image instead. Alternatively, it is highly recommended to use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to pre-download all of the required containers before running the pipeline and to set the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options to be able to store and re-use the images from a central location for future pipeline runs.
    > * If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

4. Start running your own analysis!

    <!-- TODO nf-core: Update the example "typical command" below used to run the pipeline -->

    ```bash
    nextflow run qbic-pipelines/cellranger -profile <docker/singularity/podman/conda/institute> --input 'samplesheet.tsv' --genome GRCh38
    ```

See [usage docs](./docs/usage.md) for all of the available options when running the pipeline.

## Updating the pipeline container and making a new release

Cell Ranger is a commercial tool and cannot be distributed. Updating the Cell Ranger version in the container and pushing the update to Dockerhub needs
needs to be done manually.

1. Clone this pipeline repository. E.g. with the `gh` GitHub cli:

    ```bash
    gh repo clone qbic-pipelines/cellranger
    cd cellranger
    ```

2. Navigate to the [Cell Ranger download page](https://support.10xgenomics.com/single-cell-gene-expression/software/downloads/latest) and download the tar ball of the desired Cell Ranger version with `curl` or `wget`. Place this file inside the recently cloned pipeline directory.

3. Edit the Dockerfile: update the Cell Ranger version in this line.

    ```bash
    ENV CELLRANGER_VER <VERSION>
    ```

4. Create the container:

    ```bash
    docker build . -t qbicpipelines/cellranger:dev
    docker push qbicpipelines/cellranger:dev
    ```

5. If preparing for new release: bump to the desired pipeline version (`<version>`) and container tag (same as pipeline version)
in the `main.nf` manifest, `nextflow.config` container definition, and `ci.yml` GitHub actions workflow.
Then push the latest and release container tags.

    ```bash
    docker pull qbicpipelines/cellranger:dev
    docker tag qbicpipelines/cellranger:dev qbicpipelines/cellranger:latest
    docker push qbicpipelines/cellranger:latest
    docker tag qbicpipelines/cellranger:latest qbicpipelines/cellranger:<version>
    docker push qbicpipelines/cellranger:<version>
    ```

## Documentation

The qbic-pipelines/cellranger pipeline comes with documentation about the pipeline: [usage](./docs/usage.md) and [output](./docs/output.md).

## Credits

qbic-pipelines/cellranger was originally written by [Gisela Gabernet](https://github.com/ggabernet).

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#qbic-pipelines-cellranger` channel](https://nfcore.slack.com/channels/qbic-pipelines-cellranger) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi. -->
<!-- If you use  qbic-pipelines/cellranger for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline was created with the nf-core template. You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
