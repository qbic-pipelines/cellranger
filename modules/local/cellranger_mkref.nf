include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CELLRANGER_MKREF {
    tag 'build_references'
    label 'process_high'

    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:'cellranger_references', publish_id:'') }

    container "qbicpipelines/cellranger:1.0"                        // Docker image

    input:
    path(fasta)
    path(gtf)

    output:
    path("${params.reference_name}"), emit: reference
    val(reference_name), emit: reference_namee
    path "*.version.txt", emit: version

    script:
    def reference_name = params.reference_name
    """
    cellranger mkgtf \\
        $gtf \\
        '${gtf.baseName}.filtered.gtf' \\
        --attribute=gene_biotype:protein_coding

    cellranger mkref \\
        --genome=${params.reference_name} \\
        --fasta=${fasta} \\
        --genes=${gtf}

    cellranger --version | grep -o "[0-9\\. ]\\+" > cellranger.version.txt
    """
}
