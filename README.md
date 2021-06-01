# qbic-pipelines/cellranger

**Nextflow wrapper around the Cell Ranger pipeline for single cell RNAseq analysis**.

[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A520.04.0-brightgreen.svg)](https://www.nextflow.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/qbic-pipelines-cellranger.svg)](https://hub.docker.com/r/qbicpipelines/cellranger)

## Introduction

<!-- TODO nf-core: Write a 1-2 sentence summary of what data the pipeline is for and what it does -->
**qbic-pipelines/cellranger** is a Nextflow pipeline that wraps the Cell Ranger pipeline for single cell RNAseq analysis. It additionally performs QC on the Fastq files
with `FastQC` and summarizes the QC with `MultiQC`.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker containers making installation trivial and results highly reproducible.

## Quick Start

1. Install [`nextflow`](https://nf-co.re/usage/installation) (`>=20.10.0`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```bash
    nextflow run qbic-pipelines/cellranger -profile test,<docker/singularity/podman/conda/institute>
    ```

    > Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.

4. Start running your own analysis!

    <!-- TODO nf-core: Update the example "typical command" below used to run the pipeline -->

    ```bash
    nextflow run qbic-pipelines/cellranger -profile <docker/singularity/podman/conda/institute> --input 'samplesheet.tsv' --genome GRCh38
    ```

See [usage docs](https://nf-co.re/qbic-pipelines-cellranger/usage) for all of the available options when running the pipeline.

## Updating the pipeline container

Cell Ranger is a commercial tool and cannot be distributed. Updating the Cell Ranger version in the container and pushing the update to Dockerhub needs
needs to be done manually.

1. Clone this pipeline repository.
```

```
2. Navigate to the [Cell Ranger download page](https://support.10xgenomics.com/single-cell-gene-expression/software/downloads/latest) and download the tar ball of the desired Cell Ranger version.
3. Move the tar file to the pipeline repository 

## Pipeline Summary

By default, the pipeline currently performs the following:

* Sequencing quality control (`FastQC`)
* single-cell data analysis (`cellranger count`)
* Overall pipeline run summaries (`MultiQC`)

## Documentation

The qbic-pipelines/cellranger pipeline comes with documentation about the pipeline: [usage](./docs/usage.md) and [output](./docs/output.md).

## Credits

qbic-pipelines/cellranger was originally written by Gisela Gabernet.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#qbic-pipelines-cellranger` channel](https://nfcore.slack.com/channels/qbic-pipelines-cellranger) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi. -->
<!-- If you use  nf-core/qbic-pipelines-cellranger for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

This pipeline was created with the nf-core template. You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).

In addition, references of tools and data used in this pipeline are as follows:
