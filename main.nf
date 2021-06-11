#!/usr/bin/env nextflow
/*
========================================================================================
                        qbic-pipelines/cellranger
========================================================================================
    qbic-pipelines/cellranger Analysis Pipeline.
    #### Homepage / Documentation
    https://github.com/qbic-pipelines/cellranger
----------------------------------------------------------------------------------------
*/

log.info Headers.nf_core(workflow, params.monochrome_logs)

////////////////////////////////////////////////////
/* --               PRINT HELP                 -- */
////////////////////////////////////////////////////+
def json_schema = "$projectDir/nextflow_schema.json"
if (params.help) {
    def command = "nextflow run nf-core/qbic-pipelines-cellranger --input '*_R{1,2}.fastq.gz' -profile docker"
    log.info NfcoreSchema.params_help(workflow, params, json_schema, command)
    exit 0
}

////////////////////////////////////////////////////
/* --         VALIDATE PARAMETERS              -- */
////////////////////////////////////////////////////+
if (params.validate_params) {
    NfcoreSchema.validateParameters(params, json_schema, log)
}

////////////////////////////////////////////////////
/* --     Collect configuration parameters     -- */
////////////////////////////////////////////////////

// Check AWS batch settings
if (workflow.profile.contains('awsbatch')) {
    // AWSBatch sanity checking
    if (!params.awsqueue || !params.awsregion) exit 1, 'Specify correct --awsqueue and --awsregion parameters on AWSBatch!'
    // Check outdir paths to be S3 buckets if running on AWSBatch
    // related: https://github.com/nextflow-io/nextflow/issues/813
    if (!params.outdir.startsWith('s3:')) exit 1, 'Outdir not on S3 - specify S3 Bucket to run on AWSBatch!'
    // Prevent trace files to be stored on S3 since S3 does not support rolling files.
    if (params.tracedir.startsWith('s3:')) exit 1, 'Specify a local tracedir or run without trace! S3 cannot be used for tracefiles.'
}

// Stage config files
ch_multiqc_config = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
ch_output_docs = file("$projectDir/docs/output.md", checkIfExists: true)
ch_output_docs_images = file("$projectDir/docs/images/", checkIfExists: true)

/*
 * Create a channel for input read files
 */
if (params.input)  { ch_metadata = file(params.input, checkIfExists: true) } else { exit 1, "Please provide input file with sample metadata with the '--input' option." }
if (params.index_file) {
    Channel.from( ch_metadata )
            .splitCsv(header: true, sep:'\t')
            .map { col -> tuple("${col.GEM}", "${col.Sample}", "${col.Lane}", file("${col.R1}", checkifExists: true),file("${col.R2}", checkifExists: true), file("${col.I1}", checkifExists: true)) }
            .dump()
            .into{ ch_read_files_fastqc; ch_read_files_count }
} else {
    Channel.from( ch_metadata )
            .splitCsv(header: true, sep:'\t')
            .map { col -> tuple("${col.GEM}", "${col.Sample}", "${col.Lane}", file("${col.R1}", checkifExists: true),file("${col.R2}", checkifExists: true)) }
            .dump()
            .into{ ch_read_files_fastqc; ch_read_files_count }
}

// Handle reference channels
if (params.prebuilt_reference){
    if (params.genome) exit 1, "Please provide either a reference folder or a genome name, not both."
    ch_reference_path = Channel.fromPath("${params.prebuilt_reference}")
    ch_fasta = Channel.empty()
    ch_gtf = Channel.empty()
} else if (!params.genome) {
    if (!params.fasta | !params.gtf) exit 1, "Please provide either a genome reference name with the `--genome` parameter, or a reference folder, or a fasta and gtf file."
    if (params.fasta)  { ch_fasta = file(params.fasta, checkIfExists: true) } else { exit 1, "Please provide fasta file with the '--fasta' option." }
    if (params.gtf)  { ch_gtf = file(params.gtf, checkIfExists: true) } else { exit 1, "Please provide gtf file with the '--gtf' option." }
    ch_reference_path = Channel.empty()
} else {
    ch_fasta = Channel.empty()
    ch_gtf = Channel.empty()
}

////////////////////////////////////////////////////
/* --         PRINT PARAMETER SUMMARY          -- */
////////////////////////////////////////////////////
log.info NfcoreSchema.params_summary_log(workflow, params, json_schema)

// Header log info
def summary = [:]
if (workflow.revision) summary['Pipeline Release'] = workflow.revision
summary['Run Name']         = workflow.runName
summary['Input']            = params.input
summary['Prebuilt Reference']  = params.prebuilt_reference
summary['Genome Reference']    = params.genome
summary['Genome fasta']        = params.fasta
summary['Genome gtf']          = params.gtf
summary['Custom reference name'] = params.reference_name
summary['Max Resources']    = "$params.max_memory memory, $params.max_cpus cpus, $params.max_time time per job"
if (workflow.containerEngine) summary['Container'] = "$workflow.containerEngine - $workflow.container"
summary['Output dir']       = params.outdir
summary['Launch dir']       = workflow.launchDir
summary['Working dir']      = workflow.workDir
summary['Script dir']       = workflow.projectDir
summary['User']             = workflow.userName
if (workflow.profile.contains('awsbatch')) {
    summary['AWS Region']   = params.awsregion
    summary['AWS Queue']    = params.awsqueue
    summary['AWS CLI']      = params.awscli
}
summary['Config Profile'] = workflow.profile
if (params.config_profile_description) summary['Config Profile Description'] = params.config_profile_description
if (params.config_profile_contact)     summary['Config Profile Contact']     = params.config_profile_contact
if (params.config_profile_url)         summary['Config Profile URL']         = params.config_profile_url
summary['Config Files'] = workflow.configFiles.join(', ')
if (params.email || params.email_on_fail) {
    summary['E-mail Address']    = params.email
    summary['E-mail on failure'] = params.email_on_fail
    summary['MultiQC maxsize']   = params.max_multiqc_email_size
}

// Check the hostnames against configured profiles
checkHostname()

Channel.from(summary.collect{ [it.key, it.value] })
    .map { k,v -> "<dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }
    .reduce { a, b -> return [a, b].join("\n            ") }
    .map { x -> """
    id: 'qbic-pipelines-cellranger-summary'
    description: " - this information is collected when the pipeline is started."
    section_name: 'qbic-pipelines/cellranger Workflow Summary'
    section_href: 'https://github.com/qbic-pipelines/cellranger'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
            $x
        </dl>
    """.stripIndent() }
    .set { ch_workflow_summary }

/*
 * Parse software version numbers
 */
process get_software_versions {
    publishDir "${params.outdir}/pipeline_info", mode: params.publish_dir_mode,
        saveAs: { filename ->
                        if (filename.indexOf('.csv') > 0) filename
                        else null
        }

    output:
    file 'software_versions_mqc.yaml' into ch_software_versions_yaml
    file 'software_versions.csv'

    script:
    """
    echo $workflow.manifest.version > v_pipeline.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    fastqc --version > v_fastqc.txt
    multiqc --version > v_multiqc.txt
    cellranger --version > v_cellranger.txt
    scrape_software_versions.py &> software_versions_mqc.yaml
    """
}

/* 
 * STEP 0 A - GetReferences
 */
process get_references {
    tag 'references'
    label 'process_low'
    publishDir path: { params.save_reference ? "${params.outdir}/references" : params.outdir },
                saveAs: { params.save_reference ? it : null }, mode: params.publish_dir_mode


    output:
    file "refdata*" into ch_reference_sources

    when:
    (!params.prebuilt_reference & !params.fasta & !params.gtf)

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

/* 
 * STEP 0 B - BuildReferences
 */
process build_references {
    tag 'build_references'
    label 'process_high'
    publishDir path: { params.save_reference ? "${params.outdir}/references" : params.outdir },
                saveAs: { params.save_reference ? it : null }, mode: params.publish_dir_mode

    input:
    file(fasta) from ch_fasta
    file(gtf) from ch_gtf

    output:
    file "${params.reference_name}" into ch_reference_build

    when:
    (!params.prebuilt_reference & !params.genome)

    script:
    """
    cellranger mkgtf \
        $gtf \
        '${gtf.baseName}.filtered.gtf' \
        --attribute=gene_biotype:protein_coding
    
    cellranger mkref \
        --genome=${params.reference_name} \
        --fasta=${fasta} \
        --genes=${gtf}
    """ 
}

/*
 * STEP 1 - FastQC
 */
process fastqc {
    tag "$sample"
    label 'process_medium'
    publishDir "${params.outdir}/fastqc", mode: params.publish_dir_mode,
        saveAs: { filename ->
                    filename.indexOf('.zip') > 0 ? "zips/$filename" : "$filename"
        }

    input:
    tuple val(GEM), val(sample), val(lane), file(R1), file(R2) from ch_read_files_fastqc

    output:
    file '*_fastqc.{zip,html}' into ch_fastqc_results

    script:
    """
    fastqc --quiet --threads $task.cpus ${R1} ${R2} 
    """
}

/*
 * STEP 2 - CELLRANGER COUNT
 */
process count {
    tag "$GEM"
    label 'cellranger'
    publishDir "${params.outdir}/cellranger_count", mode: params.publish_dir_mode

    input:
    tuple val(GEM), val(sample), val(lane), file(R1), file(R2) from ch_read_files_count.groupTuple()
    file(reference) from ch_reference_sources.mix( ch_reference_path ).mix( ch_reference_build ).collect()

    output:
    file "sample-${GEM}/outs/*"

    script:
    def reference_folder = params.prebuilt_reference ?: (params.genome == 'GRCh38') ? 'refdata-cellranger-GRCh38-3.0.0' : ( params.genome == 'mm10') ? 'refdata-gex-mm10-2020-A' : ''
    def sample_arg = sample.unique().join(",")
    if ( params.prebuilt_reference ) {
        """
        cellranger count --id='sample-${GEM}' \
            --fastqs=. \
            --transcriptome=${reference_folder} \
            --sample=${sample_arg} \
            --localcores=${task.cpus} \
            --localmem=${task.memory.toGiga()}
        """
    } else if ( params.genome ) {
        """
        tar -zxvf ${reference}
        cellranger count --id='sample-${GEM}' \
            --fastqs=. \
            --transcriptome=${reference_folder} \
            --sample=${sample_arg} \
            --localcores=${task.cpus} \
            --localmem=${task.memory.toGiga()}
        """
    } else {
        """
        cellranger count --id='sample-${GEM}' \
            --fastqs=. \
            --transcriptome=${params.reference_name} \
            --sample=${sample_arg} \
            --localcores=${task.cpus} \
            --localmem=${task.memory.toGiga()}
        """
    }
}

/*
 * STEP 3 - MultiQC
 */
process multiqc {
    publishDir "${params.outdir}/MultiQC", mode: params.publish_dir_mode

    input:
    file (multiqc_config) from ch_multiqc_config
    file (mqc_custom_config) from ch_multiqc_custom_config.collect().ifEmpty([])
    file ('fastqc/*') from ch_fastqc_results.collect().ifEmpty([])
    file ('software_versions/*') from ch_software_versions_yaml.collect()
    file workflow_summary from ch_workflow_summary.collectFile(name: "workflow_summary_mqc.yaml")

    output:
    file "*multiqc_report.html" into ch_multiqc_report
    file "*_data"
    file "multiqc_plots"

    script:
    rtitle = ''
    rfilename = ''
    if (!(workflow.runName ==~ /[a-z]+_[a-z]+/)) {
        rtitle = "--title \"${workflow.runName}\""
        rfilename = "--filename " + workflow.runName.replaceAll('\\W','_').replaceAll('_+','_') + "_multiqc_report"
    }
    custom_config_file = params.multiqc_config ? "--config $mqc_custom_config" : ''
    """
    multiqc -f $rtitle $rfilename $custom_config_file .
    """
}

/*
 * STEP 3 - Output Description HTML
 */
process output_documentation {
    publishDir "${params.outdir}/pipeline_info", mode: params.publish_dir_mode

    input:
    file output_docs from ch_output_docs
    file images from ch_output_docs_images

    output:
    file 'results_description.html'

    script:
    """
    markdown_to_html.py $output_docs -o results_description.html
    """
}

/*
 * Completion e-mail notification
 */
workflow.onComplete {

    // Set up the e-mail variables
    def subject = "[qbic-pipelines/cellranger] Successful: $workflow.runName"
    if (!workflow.success) {
        subject = "[qbic-pipelines/cellranger] FAILED: $workflow.runName"
    }
    def email_fields = [:]
    email_fields['version'] = workflow.manifest.version
    email_fields['runName'] = workflow.runName
    email_fields['success'] = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration'] = workflow.duration
    email_fields['exitStatus'] = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport'] = (workflow.errorReport ?: 'None')
    email_fields['commandLine'] = workflow.commandLine
    email_fields['projectDir'] = workflow.projectDir
    email_fields['summary'] = summary
    email_fields['summary']['Date Started'] = workflow.start
    email_fields['summary']['Date Completed'] = workflow.complete
    email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if (workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if (workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if (workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
    email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
    email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
    email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

    // On success try attach the multiqc report
    def mqc_report = null
    try {
        if (workflow.success) {
            mqc_report = ch_multiqc_report.getVal()
            if (mqc_report.getClass() == ArrayList) {
                log.warn "[qbic-pipelines/cellranger] Found multiple reports from process 'multiqc', will use only one"
                mqc_report = mqc_report[0]
            }
        }
    } catch (all) {
        log.warn "[qbic-pipelines/cellranger] Could not attach MultiQC report to summary email"
    }

    // Check if we are only sending emails on failure
    email_address = params.email
    if (!params.email && params.email_on_fail && !workflow.success) {
        email_address = params.email_on_fail
    }

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$projectDir/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt = txt_template.toString()

    // Render the HTML template
    def hf = new File("$projectDir/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html = html_template.toString()

    // Render the sendmail template
    def smail_fields = [ email: email_address, subject: subject, email_txt: email_txt, email_html: email_html, projectDir: "$projectDir", mqcFile: mqc_report, mqcMaxSize: params.max_multiqc_email_size.toBytes() ]
    def sf = new File("$projectDir/assets/sendmail_template.txt")
    def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html = sendmail_template.toString()

    // Send the HTML e-mail
    if (email_address) {
        try {
            if (params.plaintext_email) { throw GroovyException('Send plaintext e-mail, not HTML') }
            // Try to send HTML e-mail using sendmail
            [ 'sendmail', '-t' ].execute() << sendmail_html
            log.info "[qbic-pipelines/cellranger] Sent summary e-mail to $email_address (sendmail)"
        } catch (all) {
            // Catch failures and try with plaintext
            def mail_cmd = [ 'mail', '-s', subject, '--content-type=text/html', email_address ]
            if ( mqc_report.size() <= params.max_multiqc_email_size.toBytes() ) {
                mail_cmd += [ '-A', mqc_report ]
            }
            mail_cmd.execute() << email_html
            log.info "[qbic-pipelines/cellranger] Sent summary e-mail to $email_address (mail)"
        }
    }

    // Write summary e-mail HTML to a file
    def output_d = new File("${params.outdir}/pipeline_info/")
    if (!output_d.exists()) {
        output_d.mkdirs()
    }
    def output_hf = new File(output_d, "pipeline_report.html")
    output_hf.withWriter { w -> w << email_html }
    def output_tf = new File(output_d, "pipeline_report.txt")
    output_tf.withWriter { w -> w << email_txt }

    c_green = params.monochrome_logs ? '' : "\033[0;32m";
    c_purple = params.monochrome_logs ? '' : "\033[0;35m";
    c_red = params.monochrome_logs ? '' : "\033[0;31m";
    c_reset = params.monochrome_logs ? '' : "\033[0m";

    if (workflow.stats.ignoredCount > 0 && workflow.success) {
        log.info "-${c_purple}Warning, pipeline completed, but with errored process(es) ${c_reset}-"
        log.info "-${c_red}Number of ignored errored process(es) : ${workflow.stats.ignoredCount} ${c_reset}-"
        log.info "-${c_green}Number of successfully ran process(es) : ${workflow.stats.succeedCount} ${c_reset}-"
    }

    if (workflow.success) {
        log.info "-${c_purple}[qbic-pipelines/cellranger]${c_green} Pipeline completed successfully${c_reset}-"
    } else {
        checkHostname()
        log.info "-${c_purple}[qbic-pipelines/cellranger]${c_red} Pipeline completed with errors${c_reset}-"
    }

}

workflow.onError {
    // Print unexpected parameters - easiest is to just rerun validation
    NfcoreSchema.validateParameters(params, json_schema, log)
}

def checkHostname() {
    def c_reset = params.monochrome_logs ? '' : "\033[0m"
    def c_white = params.monochrome_logs ? '' : "\033[0;37m"
    def c_red = params.monochrome_logs ? '' : "\033[1;91m"
    def c_yellow_bold = params.monochrome_logs ? '' : "\033[1;93m"
    if (params.hostnames) {
        def hostname = 'hostname'.execute().text.trim()
        params.hostnames.each { prof, hnames ->
            hnames.each { hname ->
                if (hostname.contains(hname) && !workflow.profile.contains(prof)) {
                    log.error "${c_red}====================================================${c_reset}\n" +
                            "  ${c_red}WARNING!${c_reset} You are running with `-profile $workflow.profile`\n" +
                            "  but your machine hostname is ${c_white}'$hostname'${c_reset}\n" +
                            "  ${c_yellow_bold}It's highly recommended that you use `-profile $prof${c_reset}`\n" +
                            "${c_red}====================================================${c_reset}\n"
                }
            }
        }
    }
}
