/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowCellranger.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist

def checkPathParamList = [ params.input ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Create a channel for input read files
if (params.input)  { ch_input = Channel.fromPath(params.input, checkIfExists: true) } else { exit 1, "Please provide input file with sample metadata with the '--input' option." }
if (params.enable_conda) { exit 1, "This pipeline does not support conda, as Cell Ranger cannot be installed via conda!" }
// Handle reference channels
if ( params.prebuilt_gex_reference ){
    if (params.genome) { exit 1, "Please provide either a prebuilt reference folder or a genome name (e.g. --genome GRCh38), not both." }
    if (params.prebuilt_gex_reference) { ch_reference = Channel.fromPath(params.prebuilt_gex_reference, checkIfExists: true) } else { exit 1, "Please provide also the prebuilt gex reference (--prebuilt_gex_reference)" }
    if (params.prebuilt_vdj_reference) { ch_vdj_reference = Channel.fromPath(params.prebuilt_vdj_reference, checkIfExists: true) } else { exit 1, "Please provide also the prebuilt vdj reference (--prebuilt_vdj_reference)" }
} else if (!params.genome) {
    if (!params.prebuilt_gex_reference || !params.prebuilt_vdj_reference) exit 1, "Please provide either a genome reference name with the `--genome` parameter, or a prebuilt gex and vdj reference folder."
    ch_reference_name = Channel.value("${params.gex_reference_name}")
}
multi_features = params.multi_features ? params.multi_features.split(',').collect{it.trim().toLowerCase().replaceAll('-', '').replaceAll('_', '')} : []
if ('fb' in multi_features) {
    if ( params.reference_feature_barcodes ) { ch_fb_reference = Channel.fromPath(params.reference_feature_barcodes, checkIfExists: true) } else { exit 1 "Please provide the feature barcode csv reference or remove 'fb' from the `--multi_features` parameter." }
}
/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

ch_multiqc_config        = Channel.fromPath("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()

//
// MODULE: Local to the pipeline
//
include { GET_SOFTWARE_VERSIONS } from '../modules/local/get_software_versions' addParams( options: [publish_files : ['tsv':'']] )
include { CELLRANGER_GETREFERENCES } from '../modules/local/cellranger_getreferences' addParams ( options: modules['cellranger_getreferences'] )
include { CELLRANGER_GETVDJREFERENCE } from '../modules/local/cellranger_getvdjreference' addParams( options: modules['cellranger_getvdjreference'] )
include { FASTQC_MULTI  } from '../modules/local/fastqc_multi'  addParams( options: modules['fastqc_multi'] )
include { CELLRANGER_MULTI } from '../modules/local/cellranger_multi'  addParams( options: [:] )

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_MULTI_CHECK } from '../subworkflows/local/input_multi_check' addParams( options: [:] )

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

def multiqc_options   = modules['multiqc']
multiqc_options.args += params.multiqc_title ? Utils.joinModuleArgs(["--title \"$params.multiqc_title\""]) : ''

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC } from '../modules/nf-core/modules/multiqc/main' addParams( options: multiqc_options   )

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow CELLRANGER_MULTI_WF {

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_MULTI_CHECK ( ch_input )

    INPUT_MULTI_CHECK.out.fastqs
        .dump(tag: 'input multi fastqs')
        .set{ ch_fastqs }

    //
    // MODULE: Run FastQC
    //
    FASTQC_MULTI (
        ch_fastqs
    )
    ch_software_versions = ch_software_versions.mix(FASTQC_MULTI.out.version.first().ifEmpty(null))


    //
    // MODULE: Get references
    //

    if (!params.prebuilt_gex_reference || !params.prebuilt_vdj_reference ) {

        CELLRANGER_GETREFERENCES()
        ch_reference = CELLRANGER_GETREFERENCES.out.reference
        ch_reference_version = Channel.empty()

        if ( 'vdjb' in multi_features || 'vdjt' in multi_features ) {
            CELLRANGER_GETVDJREFERENCE()
            ch_vdj_reference = CELLRANGER_GETVDJREFERENCE.out.reference
        }

    } else if (!params.prebuilt_gex_reference && !params.genome) {
        exit 1, "Mkref for VDJ is not yet supported, please provide pre-built references or select `--genome GRCh38/GRCm38`."
    } else {
        ch_reference_version = Channel.empty()
    }

    ch_software_versions = ch_software_versions.mix(ch_reference_version.ifEmpty(null))

    ch_cellranger_multi = ch_fastqs.dump(tag: 'before merge')
                                    .map{ it -> [ it[0].gem, it[0].fastq_id, it[0].fastqs, it[0].feature_types, it[1] ] }
                                    .groupTuple(by: [0])
                                    .dump(tag: 'gem merge')
                                    .map{ get_meta_tabs(it) }
                                    .dump(tag: 'rearr merge')


    //
    // MODULE: Cellranger multi
    //
    CELLRANGER_MULTI(
        ch_cellranger_multi,
        ch_reference,
        ch_vdj_reference,
        ch_fb_reference
    )
    ch_software_versions = ch_software_versions.mix(CELLRANGER_MULTI.out.version.ifEmpty(null))

    ch_vdj_reference.dump(tag:'vdj reference')
    ch_reference.dump(tag: 'gex reference')
    //
    // MODULE: Pipeline reporting
    //
    ch_software_versions
        .map { it -> if (it) [ it.baseName, it ] }
        .groupTuple()
        .map { it[1][0] }
        .flatten()
        .collect()
        .set { ch_software_versions }

    GET_SOFTWARE_VERSIONS (
        ch_software_versions.map { it }.collect()
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowCellranger.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_config)
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(GET_SOFTWARE_VERSIONS.out.yaml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_MULTI.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect()
    )
    multiqc_report       = MULTIQC.out.report.toList()
    ch_software_versions = ch_software_versions.mix(MULTIQC.out.version.ifEmpty(null))
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
========================================================================================
    THE END
========================================================================================
*/


// Functions needed by the workflow

def get_meta_tabs(arr) {
    def meta = [:]
    meta.gem          = arr[0]
    meta.samples      = arr[1]
    meta.sample_paths = arr[2]
    meta.feature_types = arr[3]

    def array = []
    array = [ meta, arr[4].flatten() ]
    return array
}
