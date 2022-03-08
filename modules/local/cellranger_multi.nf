include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CELLRANGER_MULTI {
    tag "$meta.gem"
    label 'process_high'

    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), publish_id:'meta.gem') }

    container "qbicpipelines/cellranger:6.0.2"   // Docker image

    input:
    tuple val(meta), path(reads)
    path(reference)
    path(vdj_reference)
    path(fb_reference)

    output:
    path("${meta.gem}/outs/*"), emit: outs
    path "*.version.txt", emit: version

    script:
    def sample_arg = meta.samples.unique().join(",")
    def reference_name = reference.name
    def vdj_reference_name = vdj_reference.name
    def fb_reference_name = fb_reference.name
    """
    generate_multi_config.py \
    -s='$meta.samples' \
    -ft='$meta.feature_types' \
    -sd='$meta.sample_paths' \
    -gexr='$reference_name' \
    -vdjr='$vdj_reference_name' \
    -fbr='$fb_reference_name' \
    -o='cellranger_multi_config.csv'

    cellranger multi \
    --id='$meta.gem' \
    --csv='cellranger_multi_config.csv' \
    --localcores=${task.cpus} \
    --localmem=${task.memory.toGiga()}

    cellranger --version | grep -o "[0-9\\. ]\\+" > cellranger.version.txt
    """

    stub:
    """
    generate_multi_config.py \
    -s='$meta.samples' \
    -ft='$meta.feature_types' \
    -sd='$meta.sample_paths' \
    -gexr='$reference_name' \
    -vdjr='$vdj_reference_name' \
    -fbr='$fb_reference_name' \
    -o='cellranger_multi_config.csv'

    mkdir -p "${meta.gem}/outs/"
    touch "${meta.gem}/outs/fake_file.txt"
    cellranger --version | grep -o "[0-9\\. ]\\+" > cellranger.version.txt
    """
}
