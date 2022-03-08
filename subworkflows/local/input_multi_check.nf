//
// Check input samplesheet and get read channels
//

params.options = [:]

include { SAMPLESHEET_MULTI_CHECK } from '../../modules/local/samplesheet_multi_check' addParams( options: params.options )

workflow INPUT_MULTI_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_MULTI_CHECK ( samplesheet )

    SAMPLESHEET_MULTI_CHECK.out.samplesheet.splitCsv( header:true, sep: '\t' )
        .map { get_samplesheet_paths(it) }
        .set { fastqs }

    SAMPLESHEET_MULTI_CHECK.out.featuretype.splitCsv( header:true )
                                            .map { get_featuretypes(it) }
                                            .set { feature }

    emit:
    fastqs // channel: [ val(meta), [ fastqs ] ]
    feature
}

// Function to get list of [ meta, [ fastqs ] ]
def get_samplesheet_paths(LinkedHashMap col) {
    def meta = [:]
    meta.id             = col.gem
    meta.gem            = col.gem
    meta.fastq_id       = col.fastq_id
    meta.fastqs         = col.fastqs
    meta.feature_types  = col.feature_types

    def array = []
    if (!file(col.fastqs).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Fastq file folder does not exist!\n${col.fastqs}"
    }
    array = [ meta, [ file(col.fastqs) ] ]

    return array
}

def get_featuretypes(LinkedHashMap col) {
    def feature = [:]
    feature.gex         = col.gex
    feature.fb          = col.fb
    feature.vdj_b       = col.vdj_b
    feature.vdj_t       = col.vdj_t

    return feature
}