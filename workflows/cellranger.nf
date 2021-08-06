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
if (params.input)  { ch_input = file(params.input, checkIfExists: true) } else { exit 1, "Please provide input file with sample metadata with the '--input' option." }
if (params.enable_conda) { exit 1, "This pipeline does not support conda, as Cell Ranger cannot be installed via conda!" }
// Handle reference channels
if (params.prebuilt_reference){
    if (params.genome) exit 1, "Please provide either a reference folder or a genome name, not both."
    ch_reference = Channel.fromPath("${params.prebuilt_reference}")
    ch_reference_name = Channel.value("${params.reference_name}")
} else if (!params.genome) {
    if (!params.fasta | !params.gtf) exit 1, "Please provide either a genome reference name with the `--genome` parameter, or a reference folder, or a fasta and gtf file."
    if (params.fasta)  { ch_fasta = file(params.fasta, checkIfExists: true) } else { exit 1, "Please provide fasta file with the '--fasta' option." }
    if (params.gtf)  { ch_gtf = file(params.gtf, checkIfExists: true) } else { exit 1, "Please provide gtf file with the '--gtf' option." }
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
include { CELLRANGER_GETREFERENCES } from '../modules/local/cellranger_getreferences' addParams( options: [:] )
include { CELLRANGER_MKREF } from '../modules/local/cellranger_mkref' addParams( options: [:] )
include { CELLRANGER_COUNT } from '../modules/local/cellranger_count' addParams( options: [:] )

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check' addParams( options: [:] )

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
include { FASTQC  } from '../modules/nf-core/modules/fastqc/main'  addParams( options: modules['fastqc'] )
include { MULTIQC } from '../modules/nf-core/modules/multiqc/main' addParams( options: multiqc_options   )

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow CELLRANGER_GEX {

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK ( ch_input )
        .groupTuple(by: [0])
        .map{ it -> [ it[0], it[1].flatten() ] }
        .dump()
        .set{ ch_reads }

    //
    // MODULE: Run FastQC
    //
    FASTQC (
        ch_reads
    )
    ch_software_versions = ch_software_versions.mix(FASTQC.out.version.first().ifEmpty(null))


    //
    // MODULE: Get references
    //

    if (!params.prebuilt_reference & !params.fasta & !params.gtf) {
        CELLRANGER_GETREFERENCES()
        ch_reference = CELLRANGER_GETREFERENCES.out.reference
        ch_reference_version = Channel.empty()
        ch_reference_name = CELLRANGER_GETREFERENCES.out.reference_name
    } else if (!params.prebuilt_reference & !params.genome) {
        CELLRANGER_MKREF(
            ch_fasta,
            ch_gtf
        )
        ch_reference = CELLRANGER_MKREF.out.reference
        ch_reference_version = CELLRANGER_MKREF.out.version.first().ifEmpty(null)
        ch_reference_name = CELLRANGER_MKREF.out.reference_name
    }

    ch_software_versions = ch_software_versions.mix(ch_reference_version.ifEmpty(null))

    ch_cellranger_count = ch_reads.dump(tag: 'before merge')
                                    .map{ it -> [ it[0].gem, it[0].sample, it[1] ] }
                                    .groupTuple()
                                    .dump(tag: 'gem merge')
                                    .map{ get_meta_tabs(it) }
                                    .dump(tag: 'rearr merge')

    //
    // MODULE: Cellranger count
    //
    CELLRANGER_COUNT(
        ch_cellranger_count,
        ch_reference,
        ch_reference_name
    )
    ch_software_versions = ch_software_versions.mix(CELLRANGER_COUNT.out.version.ifEmpty(null))

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
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

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

    def array = []
    array = [ meta, arr[2].flatten() ]
    return array
}
