// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process FASTQC_MULTI {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::fastqc=0.11.9" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/fastqc:0.11.9--0"
    } else {
        container "quay.io/biocontainers/fastqc:0.11.9--0"
    }

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.zip") , emit: zip
    path  "*.version.txt"          , emit: version

    script:
    def software = getSoftwareName(task.process)
    """
    fastqc $options.args --threads $task.cpus ${reads}/*.{fastq.gz,fq.gz}
    mv ${reads}/*.html .
    mv ${reads}/*.zip .
    fastqc --version | sed -e "s/FastQC v//g" > ${software}.version.txt
    """
}
