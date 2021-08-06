include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CELLRANGER_COUNT {
    tag "$meta.gem"
    label 'process_high'

    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:'meta.gem') }

    container "qbicpipelines/cellranger:1.0"   // Docker image

    input:
    tuple val(meta), path(reads)
    path(reference)

    output:
    path("sample-${meta.gem}/outs/*"), emit: outs
    path "*.version.txt", emit: version

    script:
    def sample_arg = meta.samples.unique().join(",")
    def reference_name = reference.name
    """
    cellranger count --id='sample-${meta.gem}' \
        --fastqs=. \
        --transcriptome=${reference_name} \
        --sample=${sample_arg} \
        --localcores=${task.cpus} \
        --localmem=${task.memory.toGiga()}

    cellranger --version | grep -o "[0-9\\. ]\\+" > cellranger.version.txt
    """

    stub:
    """
    mkdir -p "sample-${meta.gem}/outs/"
    touch sample-${meta.gem}/outs/fake_file.txt
    cellranger --version | grep -o "[0-9\\. ]\\+" > cellranger.version.txt
    """
}
