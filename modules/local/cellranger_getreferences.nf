include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CELLRANGER_GETREFERENCES {
    tag 'get_references'
    label 'process_low'

    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:'cellranger_references', publish_id:'') }

    conda (params.enable_conda ? "conda-forge::sed=4.7" : null)              // Conda package
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://containers.biocontainers.pro/s3/SingImgsRepo/biocontainers/v1.2.0_cv1/biocontainers_v1.2.0_cv1.img"  // Singularity image
    } else {
        container "biocontainers/biocontainers:v1.2.0_cv1"                        // Docker image
    }

    output:
    path("refdata*"), emit: reference

    script:
    if (params.genome == 'GRCh38') {
        """
        wget https://cf.10xgenomics.com/supp/cell-exp/refdata-cellranger-GRCh38-3.0.0.tar.gz
        """
    } else if ( params.genome == 'mm10' ) {
        """
        wget https://cf.10xgenomics.com/supp/cell-exp/refdata-gex-mm10-2020-A.tar.gz
        """
    }
}