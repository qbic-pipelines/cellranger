include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
def options    = initOptions(params.options)

process CELLRANGER_COUNT {
    tag '$meta.gem'
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

    script:
    def reference_folder = params.prebuilt_reference ?: (params.genome == 'GRCh38') ? 'refdata-cellranger-GRCh38-3.0.0' : ( params.genome == 'mm10') ? 'refdata-gex-mm10-2020-A' : ''
    def sample_arg = meta.samples.unique().join(",")
    if ( params.prebuilt_reference ) {
        """
        cellranger count --id='sample-${meta.gem}' \
            --fastqs=. \
            --transcriptome=${reference_folder} \
            --sample=${sample_arg} \
            --localcores=${task.cpus} \
            --localmem=${task.memory.toGiga()}
        """
    } else if ( params.genome ) {
        """
        tar -zxvf ${reference}
        cellranger count --id='sample-${meta.gem}' \
            --fastqs=. \
            --transcriptome=${reference_folder} \
            --sample=${sample_arg} \
            --localcores=${task.cpus} \
            --localmem=${task.memory.toGiga()}
        """
    } else {
        """
        cellranger count --id='sample-${meta.gem}' \
            --fastqs=. \
            --transcriptome=${params.reference_name} \
            --sample=${sample_arg} \
            --localcores=${task.cpus} \
            --localmem=${task.memory.toGiga()}
        """
    }

    stub:
    """
    mkdir -p "sample-${meta.gem}/outs/"
    touch sample-${meta.gem}/outs/fake_file.txt
    """
}
