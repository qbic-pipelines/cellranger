// Import generic module functions
include { saveFiles } from './functions'

params.options = [:]

process SAMPLESHEET_MULTI_CHECK {
    tag "$samplesheet"
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:'pipeline_info', meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "conda-forge::python=3.8.3" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/python:3.8.3"
    } else {
        container "quay.io/biocontainers/python:3.8.3"
    }

    input:
    path samplesheet

    output:
    path '*.csv', emit: samplesheet
    path 'featuretype_list.txt', emit: featuretype

    script: // This script is bundled with the pipeline, in nf-core/cellranger/bin/
    """
    check_samplesheet_multi.py $samplesheet featuretype_list.txt
    cp $samplesheet samplesheet.valid.csv
    """
}
